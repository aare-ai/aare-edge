import Foundation

/// Extracts structured entities from token-level NER predictions.
///
/// This class handles the conversion from BIO-tagged token predictions
/// to cohesive entity spans with text and character offsets.
public final class EntityExtractor {

    // MARK: - Properties

    /// Label mapping from index to label string
    private let labelMap: [Int: String]

    /// Reverse mapping from label string to index
    private let labelToId: [String: Int]

    // MARK: - Initialization

    /// Initialize with label mapping.
    /// - Parameter labelMap: Dictionary mapping label indices to label strings
    public init(labelMap: [Int: String]) {
        self.labelMap = labelMap
        self.labelToId = Dictionary(uniqueKeysWithValues: labelMap.map { ($1, $0) })
    }

    // MARK: - Entity Extraction

    /// Extract entities from token predictions.
    /// - Parameters:
    ///   - predictions: Array of predicted label indices for each token
    ///   - tokenizedInput: Tokenized input with offset mapping
    ///   - tokenizer: Tokenizer for converting IDs to tokens
    /// - Returns: Array of extracted PHI entities
    public func extractEntities(
        predictions: [Int],
        tokenizedInput: TokenizedInput,
        tokenizer: WordPieceTokenizer
    ) -> [PHIEntity] {
        var entities: [PHIEntity] = []
        var currentEntity: EntityBuilder? = nil

        let tokens = tokenizer.convertIdsToTokens(tokenizedInput.inputIds)

        for i in 0..<tokenizedInput.realTokenCount {
            let labelId = predictions[i]
            let label = labelMap[labelId] ?? "O"
            let token = tokens[i]
            let offset = tokenizedInput.offsetMapping[i]

            // Skip special tokens
            if token == tokenizer.clsToken || token == tokenizer.sepToken || token == tokenizer.padToken {
                // Finish current entity if any
                if let entity = currentEntity?.build(from: tokenizedInput.originalText) {
                    entities.append(entity)
                }
                currentEntity = nil
                continue
            }

            if label == "O" {
                // Outside any entity - finish current if any
                if let entity = currentEntity?.build(from: tokenizedInput.originalText) {
                    entities.append(entity)
                }
                currentEntity = nil
            } else if label.hasPrefix("B-") {
                // Beginning of new entity
                if let entity = currentEntity?.build(from: tokenizedInput.originalText) {
                    entities.append(entity)
                }

                let entityType = String(label.dropFirst(2))
                currentEntity = EntityBuilder(
                    type: entityType,
                    startOffset: offset.0,
                    endOffset: offset.1
                )
            } else if label.hasPrefix("I-") {
                // Inside entity
                let entityType = String(label.dropFirst(2))

                if let builder = currentEntity, builder.type == entityType {
                    // Continue current entity
                    builder.extendTo(offset: offset.1)
                } else {
                    // I- without matching B- or different type
                    // Treat as start of new entity (handles B/I boundary issues)
                    if let entity = currentEntity?.build(from: tokenizedInput.originalText) {
                        entities.append(entity)
                    }
                    currentEntity = EntityBuilder(
                        type: entityType,
                        startOffset: offset.0,
                        endOffset: offset.1
                    )
                }
            }
        }

        // Don't forget the last entity
        if let entity = currentEntity?.build(from: tokenizedInput.originalText) {
            entities.append(entity)
        }

        // Merge adjacent entities of the same type (handles tokenization artifacts)
        return mergeAdjacentEntities(entities, originalText: tokenizedInput.originalText)
    }

    /// Extract entities with confidence scores.
    /// - Parameters:
    ///   - predictions: Array of predicted label indices
    ///   - confidences: Confidence score for each prediction
    ///   - tokenizedInput: Tokenized input
    ///   - tokenizer: Tokenizer instance
    /// - Returns: Array of PHI entities with confidence scores
    public func extractEntitiesWithConfidence(
        predictions: [Int],
        confidences: [Float],
        tokenizedInput: TokenizedInput,
        tokenizer: WordPieceTokenizer
    ) -> [PHIEntity] {
        var entities: [PHIEntity] = []
        var currentEntity: EntityBuilder? = nil
        var currentConfidences: [Float] = []

        let tokens = tokenizer.convertIdsToTokens(tokenizedInput.inputIds)

        for i in 0..<tokenizedInput.realTokenCount {
            let labelId = predictions[i]
            let label = labelMap[labelId] ?? "O"
            let token = tokens[i]
            let offset = tokenizedInput.offsetMapping[i]
            let confidence = confidences[i]

            // Skip special tokens
            if token == tokenizer.clsToken || token == tokenizer.sepToken || token == tokenizer.padToken {
                if let entity = currentEntity?.build(from: tokenizedInput.originalText, confidence: averageConfidence(currentConfidences)) {
                    entities.append(entity)
                }
                currentEntity = nil
                currentConfidences = []
                continue
            }

            if label == "O" {
                if let entity = currentEntity?.build(from: tokenizedInput.originalText, confidence: averageConfidence(currentConfidences)) {
                    entities.append(entity)
                }
                currentEntity = nil
                currentConfidences = []
            } else if label.hasPrefix("B-") {
                if let entity = currentEntity?.build(from: tokenizedInput.originalText, confidence: averageConfidence(currentConfidences)) {
                    entities.append(entity)
                }

                let entityType = String(label.dropFirst(2))
                currentEntity = EntityBuilder(
                    type: entityType,
                    startOffset: offset.0,
                    endOffset: offset.1
                )
                currentConfidences = [confidence]
            } else if label.hasPrefix("I-") {
                let entityType = String(label.dropFirst(2))

                if let builder = currentEntity, builder.type == entityType {
                    builder.extendTo(offset: offset.1)
                    currentConfidences.append(confidence)
                } else {
                    if let entity = currentEntity?.build(from: tokenizedInput.originalText, confidence: averageConfidence(currentConfidences)) {
                        entities.append(entity)
                    }
                    currentEntity = EntityBuilder(
                        type: entityType,
                        startOffset: offset.0,
                        endOffset: offset.1
                    )
                    currentConfidences = [confidence]
                }
            }
        }

        if let entity = currentEntity?.build(from: tokenizedInput.originalText, confidence: averageConfidence(currentConfidences)) {
            entities.append(entity)
        }

        return mergeAdjacentEntities(entities, originalText: tokenizedInput.originalText)
    }

    // MARK: - Private Methods

    /// Merge adjacent entities of the same type.
    private func mergeAdjacentEntities(_ entities: [PHIEntity], originalText: String) -> [PHIEntity] {
        guard entities.count > 1 else { return entities }

        var merged: [PHIEntity] = []
        var current = entities[0]

        for i in 1..<entities.count {
            let next = entities[i]

            // Check if entities are adjacent and same type
            let gap = next.startOffset - current.endOffset
            if current.type == next.type && gap <= 1 {
                // Merge entities
                let mergedText = extractText(from: originalText, start: current.startOffset, end: next.endOffset)
                let avgConfidence = (current.confidence + next.confidence) / 2
                current = PHIEntity(
                    type: current.type,
                    text: mergedText,
                    startOffset: current.startOffset,
                    endOffset: next.endOffset,
                    confidence: avgConfidence
                )
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)

        return merged
    }

    /// Extract text from original string given offsets.
    private func extractText(from text: String, start: Int, end: Int) -> String {
        let startIndex = text.index(text.startIndex, offsetBy: min(start, text.count))
        let endIndex = text.index(text.startIndex, offsetBy: min(end, text.count))
        return String(text[startIndex..<endIndex])
    }

    /// Calculate average confidence.
    private func averageConfidence(_ confidences: [Float]) -> Float {
        guard !confidences.isEmpty else { return 1.0 }
        return confidences.reduce(0, +) / Float(confidences.count)
    }
}

// MARK: - Entity Builder

/// Helper class for building entities incrementally.
private class EntityBuilder {
    let type: String
    let startOffset: Int
    var endOffset: Int

    init(type: String, startOffset: Int, endOffset: Int) {
        self.type = type
        self.startOffset = startOffset
        self.endOffset = endOffset
    }

    func extendTo(offset: Int) {
        endOffset = max(endOffset, offset)
    }

    func build(from originalText: String, confidence: Float = 1.0) -> PHIEntity? {
        guard startOffset < originalText.count else { return nil }

        let startIndex = originalText.index(originalText.startIndex, offsetBy: startOffset)
        let endIndex = originalText.index(originalText.startIndex, offsetBy: min(endOffset, originalText.count))

        var text = String(originalText[startIndex..<endIndex])
            .trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else { return nil }

        // Strip trailing punctuation that doesn't belong to the entity
        let trailingPunctuation: Set<Character> = [",", ".", ";", ":", "!", "?", ")", "]", "}", "'", "\""]
        var adjustedEndOffset = endOffset

        while let lastChar = text.last, trailingPunctuation.contains(lastChar) {
            text.removeLast()
            adjustedEndOffset -= 1
        }

        // Strip leading punctuation, but preserve ( if followed by digits (phone numbers)
        let leadingPunctuation: Set<Character> = ["[", "{", "'", "\""]
        var adjustedStartOffset = startOffset

        while let firstChar = text.first, leadingPunctuation.contains(firstChar) {
            text.removeFirst()
            adjustedStartOffset += 1
        }

        // Special handling for leading ( - only strip if NOT followed by a digit
        if text.first == "(" {
            let secondIndex = text.index(after: text.startIndex)
            if secondIndex < text.endIndex {
                let secondChar = text[secondIndex]
                if !secondChar.isNumber {
                    // Not a phone number format, strip the (
                    text.removeFirst()
                    adjustedStartOffset += 1
                }
            } else {
                // Just a lone (, strip it
                text.removeFirst()
                adjustedStartOffset += 1
            }
        }

        guard !text.isEmpty else { return nil }

        return PHIEntity(
            type: type,
            text: text,
            startOffset: adjustedStartOffset,
            endOffset: adjustedEndOffset,
            confidence: confidence
        )
    }
}
