// PHI Extractor
// Entity extraction using on-device ML model or regex fallback

import Foundation
import CoreML

#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Extraction configuration
public struct ExtractionConfig {
    public let modelName: String
    public let maxLength: Int
    public let confidenceThreshold: Double
    public let batchSize: Int

    public init(
        modelName: String = "hipaa_phi_detector",
        maxLength: Int = 512,
        confidenceThreshold: Double = 0.5,
        batchSize: Int = 8
    ) {
        self.modelName = modelName
        self.maxLength = maxLength
        self.confidenceThreshold = confidenceThreshold
        self.batchSize = batchSize
    }
}

/// PHI entity extractor using CoreML for on-device inference
public class PHIExtractor {

    // Regex patterns for fallback extraction
    private let patterns: [(PHICategory, NSRegularExpression)]
    private let config: ExtractionConfig
    private let tokenizer: Tokenizer
    private let configuration: HIPAAConfiguration

    // CoreML model (loaded lazily)
    private var coreMLModel: MLModel?
    private var isModelLoaded = false

    public init(config: ExtractionConfig = ExtractionConfig()) {
        self.config = config
        self.tokenizer = Tokenizer(maxLength: config.maxLength)
        self.configuration = HIPAAConfiguration.shared
        self.patterns = Self.buildPatterns()
    }

    /// Load the CoreML model for on-device inference
    /// - Parameter modelURL: Optional URL to the CoreML model
    public func loadModel(from modelURL: URL? = nil) async throws {
        guard !isModelLoaded else { return }

        // Try to load from provided URL or bundle
        let url = modelURL ?? try findModelInBundle()

        do {
            let compiledURL = try MLModel.compileModel(at: url)
            self.coreMLModel = try MLModel(contentsOf: compiledURL)
            self.isModelLoaded = true
            print("CoreML model loaded successfully from \(url)")
        } catch {
            print("Failed to load CoreML model: \(error)")
            throw VerificationError.modelNotLoaded
        }
    }

    /// Extract PHI entities using the on-device ML model
    /// - Parameter text: Text to analyze
    /// - Returns: Detected PHI entities
    public func extract(text: String) async throws -> [PHIEntity] {
        if isModelLoaded, let model = coreMLModel {
            return try await extractWithCoreML(text: text, model: model)
        } else {
            // Fallback to regex-based extraction
            return extractWithRegex(text: text)
        }
    }

    /// Extract PHI entities using CoreML model
    /// - Parameters:
    ///   - text: Text to analyze
    ///   - model: CoreML model
    /// - Returns: Detected PHI entities
    private func extractWithCoreML(text: String, model: MLModel) async throws -> [PHIEntity] {
        // Tokenize input text
        let tokenization = tokenizer.tokenize(text: text, padding: true, truncation: true)

        // Prepare CoreML input
        // Note: The exact input format depends on your CoreML model export
        // This assumes the model takes input_ids and attention_mask
        let inputIds = tokenization.inputIds.map { Int64($0) }
        let attentionMask = tokenization.attentionMask.map { Int64($0) }

        // Create MLMultiArray for input
        guard let inputIdsArray = try? MLMultiArray(shape: [1, NSNumber(value: inputIds.count)], dataType: .int32),
              let attentionMaskArray = try? MLMultiArray(shape: [1, NSNumber(value: attentionMask.count)], dataType: .int32) else {
            throw VerificationError.inferenceError("Failed to create input arrays")
        }

        // Fill arrays
        for (index, value) in inputIds.enumerated() {
            inputIdsArray[index] = NSNumber(value: value)
        }
        for (index, value) in attentionMask.enumerated() {
            attentionMaskArray[index] = NSNumber(value: value)
        }

        // Create input feature provider
        let inputFeatures: [String: Any] = [
            "input_ids": inputIdsArray,
            "attention_mask": attentionMaskArray
        ]

        guard let inputProvider = try? MLDictionaryFeatureProvider(dictionary: inputFeatures) else {
            throw VerificationError.inferenceError("Failed to create feature provider")
        }

        // Run inference
        let output = try model.prediction(from: inputProvider)

        // Parse output
        // Output should be logits with shape [batch_size, sequence_length, num_labels]
        guard let logitsArray = output.featureValue(for: "logits")?.multiArrayValue else {
            throw VerificationError.inferenceError("Failed to get model output")
        }

        // Convert logits to predictions
        let predictions = try parsePredictions(
            logits: logitsArray,
            tokenization: tokenization,
            originalText: text
        )

        return predictions
    }

    /// Parse model predictions into PHI entities
    private func parsePredictions(
        logits: MLMultiArray,
        tokenization: TokenizationResult,
        originalText: String
    ) throws -> [PHIEntity] {
        var entities: [PHIEntity] = []
        var currentEntity: (category: PHICategory, tokens: [Token], confidence: Double)?

        let sequenceLength = min(tokenization.inputIds.count, Int(logits.shape[1].intValue))

        for i in 0..<sequenceLength {
            // Get predicted label and confidence
            var maxLogit: Double = -Double.infinity
            var predictedLabel = 0

            for labelId in 0..<configuration.numLabels {
                let index = [0, i, labelId] as [NSNumber]
                let logit = logits[index].doubleValue
                if logit > maxLogit {
                    maxLogit = logit
                    predictedLabel = labelId
                }
            }

            // Convert to probability (simplified softmax)
            let confidence = 1.0 / (1.0 + exp(-maxLogit))

            // Skip if confidence too low
            guard confidence >= config.confidenceThreshold else { continue }

            // Get label string
            guard let labelString = configuration.id2label[predictedLabel] else { continue }

            // Skip O labels and special tokens
            guard labelString != "O" else {
                // Save pending entity
                if let entity = currentEntity {
                    entities.append(createEntity(from: entity, text: originalText))
                    currentEntity = nil
                }
                continue
            }

            // Parse BIO label
            guard let (bioTag, categoryString) = parseBIOLabel(labelString),
                  let category = PHICategory(rawValue: categoryString) else {
                continue
            }

            // Get corresponding token
            guard i < tokenization.tokens.count else { continue }
            let token = tokenization.tokens[i]

            if bioTag == "B" {
                // Start of new entity - save previous if exists
                if let entity = currentEntity {
                    entities.append(createEntity(from: entity, text: originalText))
                }
                currentEntity = (category, [token], confidence)
            } else if bioTag == "I", let entity = currentEntity, entity.category == category {
                // Continuation of current entity
                currentEntity?.tokens.append(token)
                currentEntity?.confidence = (entity.confidence + confidence) / 2.0
            } else {
                // Mismatch - start new entity
                if let entity = currentEntity {
                    entities.append(createEntity(from: entity, text: originalText))
                }
                currentEntity = (category, [token], confidence)
            }
        }

        // Save final entity
        if let entity = currentEntity {
            entities.append(createEntity(from: entity, text: originalText))
        }

        return entities
    }

    /// Create PHIEntity from accumulated tokens
    private func createEntity(
        from entity: (category: PHICategory, tokens: [Token], confidence: Double),
        text: String
    ) -> PHIEntity {
        let startIndex = entity.tokens.first?.startIndex ?? 0
        let endIndex = entity.tokens.last?.endIndex ?? 0

        // Extract value from original text
        let nsText = text as NSString
        let range = NSRange(location: startIndex, length: endIndex - startIndex)
        let value = nsText.substring(with: range)

        return PHIEntity(
            category: entity.category,
            value: value,
            startIndex: startIndex,
            endIndex: endIndex,
            confidence: entity.confidence
        )
    }

    /// Parse BIO label into tag and category
    private func parseBIOLabel(_ label: String) -> (tag: String, category: String)? {
        let components = label.split(separator: "-", maxSplits: 1)
        guard components.count == 2 else { return nil }
        return (String(components[0]), String(components[1]))
    }

    /// Extract PHI entities using regex patterns (fallback)
    /// - Parameter text: Text to analyze
    /// - Returns: Detected PHI entities
    public func extractWithRegex(text: String) -> [PHIEntity] {
        var entities: [PHIEntity] = []
        let nsText = text as NSString

        for (category, regex) in patterns {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

            for match in matches {
                let value = nsText.substring(with: match.range)
                entities.append(PHIEntity(
                    category: category,
                    value: value,
                    startIndex: match.range.location,
                    endIndex: match.range.location + match.range.length,
                    confidence: 0.8 // Fixed confidence for regex
                ))
            }
        }

        return entities
    }

    /// Batch extraction
    public func extractBatch(texts: [String]) async throws -> [[PHIEntity]] {
        var results: [[PHIEntity]] = []

        for i in stride(from: 0, to: texts.count, by: config.batchSize) {
            let batchEnd = min(i + config.batchSize, texts.count)
            let batch = Array(texts[i..<batchEnd])

            for text in batch {
                let entities = try await extract(text: text)
                results.append(entities)
            }
        }

        return results
    }

    // MARK: - Model Loading Helpers

    private func findModelInBundle() throws -> URL {
        // Try to find model in main bundle
        if let url = Bundle.main.url(forResource: config.modelName, withExtension: "mlmodelc") {
            return url
        }

        // Try module bundle
        if let url = Bundle.module.url(forResource: config.modelName, withExtension: "mlmodelc", subdirectory: "Resources") {
            return url
        }

        // Try .mlmodel extension
        if let url = Bundle.main.url(forResource: config.modelName, withExtension: "mlmodel") {
            return url
        }

        throw VerificationError.modelNotLoaded
    }

    // MARK: - Pattern Building

    private static func buildPatterns() -> [(PHICategory, NSRegularExpression)] {
        var patterns: [(PHICategory, NSRegularExpression)] = []

        let patternDefs: [(PHICategory, String)] = [
            // SSN: 123-45-6789 or 123456789
            (.ssn, #"\b\d{3}-\d{2}-\d{4}\b"#),

            // Phone numbers: various formats
            (.phoneNumbers, #"\b(?:\+1[-.]?)?\(?[0-9]{3}\)?[-.]?[0-9]{3}[-.]?[0-9]{4}\b"#),

            // Email addresses
            (.emailAddresses, #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#),

            // Dates: MM/DD/YYYY, MM-DD-YYYY, YYYY-MM-DD
            (.dates, #"\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b"#),

            // IP Addresses: IPv4
            (.ipAddresses, #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#),

            // Medical Record Numbers: MRN followed by digits
            (.medicalRecordNumbers, #"\bMRN[:\s#-]*\d+\b"#),

            // URLs
            (.webUrls, #"\bhttps?://[^\s]+\b"#),

            // Fax numbers (with fax prefix)
            (.faxNumbers, #"\b[Ff]ax[:\s]*(?:\+1[-.]?)?\(?[0-9]{3}\)?[-.]?[0-9]{3}[-.]?[0-9]{4}\b"#),
        ]

        for (category, pattern) in patternDefs {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                patterns.append((category, regex))
            }
        }

        return patterns
    }
}

