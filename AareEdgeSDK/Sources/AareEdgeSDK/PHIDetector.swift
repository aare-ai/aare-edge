import Foundation
import CoreML

/// Main interface for detecting Protected Health Information (PHI) in text.
///
/// PHIDetector uses a CoreML model to identify HIPAA Safe Harbor categories
/// in input text, returning detected entities with their positions and types.
///
/// ## Usage
/// ```swift
/// let detector = try PHIDetector(
///     modelURL: modelURL,
///     vocabURL: vocabURL
/// )
/// let result = try detector.detect("Patient John Smith, SSN 123-45-6789")
/// for entity in result.entities {
///     print("\(entity.type): \(entity.text)")
/// }
/// ```
public final class PHIDetector {

    // MARK: - Properties

    /// The CoreML model for NER inference
    private let model: MLModel

    /// Tokenizer for text preprocessing
    private let tokenizer: WordPieceTokenizer

    /// Entity extractor for post-processing
    private let entityExtractor: EntityExtractor

    /// Label mapping from model output indices to entity types
    private let labelMap: [Int: String]

    /// Maximum sequence length supported by the model
    public let maxSequenceLength: Int

    // MARK: - Initialization

    /// Initialize PHI detector with model and vocabulary URLs.
    /// - Parameters:
    ///   - modelURL: URL to the CoreML model (.mlpackage or .mlmodelc)
    ///   - vocabURL: URL to the vocabulary file (vocab.txt)
    ///   - configURL: Optional URL to label configuration JSON
    ///   - maxSequenceLength: Maximum input sequence length (default: 512)
    public init(
        modelURL: URL,
        vocabURL: URL,
        configURL: URL? = nil,
        maxSequenceLength: Int = 512
    ) throws {
        // Load CoreML model
        let config = MLModelConfiguration()
        config.computeUnits = .all // Use ANE when available
        self.model = try MLModel(contentsOf: modelURL, configuration: config)

        // Initialize tokenizer
        self.tokenizer = try WordPieceTokenizer(
            vocabURL: vocabURL,
            maxLength: maxSequenceLength,
            doLowercase: true
        )

        self.maxSequenceLength = maxSequenceLength

        // Load label configuration
        if let configURL = configURL {
            self.labelMap = try Self.loadLabelMap(from: configURL)
        } else {
            self.labelMap = Self.defaultLabelMap()
        }

        // Initialize entity extractor
        self.entityExtractor = EntityExtractor(labelMap: labelMap)
    }

    /// Initialize PHI detector with pre-loaded components.
    /// - Parameters:
    ///   - model: Pre-loaded CoreML model
    ///   - tokenizer: Pre-initialized tokenizer
    ///   - labelMap: Label index to entity type mapping
    public init(
        model: MLModel,
        tokenizer: WordPieceTokenizer,
        labelMap: [Int: String]
    ) {
        self.model = model
        self.tokenizer = tokenizer
        self.labelMap = labelMap
        self.maxSequenceLength = tokenizer.maxLength
        self.entityExtractor = EntityExtractor(labelMap: labelMap)
    }

    // MARK: - Detection

    /// Detect PHI entities in the input text.
    /// - Parameter text: Text to analyze for PHI
    /// - Returns: Detection result containing identified entities
    public func detect(_ text: String) throws -> PHIDetectionResult {
        // Tokenize input
        let tokenized = tokenizer.encode(text)

        // Run model inference
        let logits = try runInference(tokenized)

        // Get predictions (argmax over label dimension)
        let predictions = argmax(logits)

        // Extract entities from predictions
        let entities = entityExtractor.extractEntities(
            predictions: predictions,
            tokenizedInput: tokenized,
            tokenizer: tokenizer
        )

        return PHIDetectionResult(
            text: text,
            entities: entities,
            tokenCount: tokenized.realTokenCount
        )
    }

    /// Detect PHI with confidence scores for each token.
    /// - Parameter text: Text to analyze
    /// - Returns: Detailed detection result with per-token scores
    public func detectWithScores(_ text: String) throws -> PHIDetectionResultWithScores {
        let tokenized = tokenizer.encode(text)
        let logits = try runInference(tokenized)

        // Apply softmax to get probabilities
        let probabilities = softmax(logits)
        let predictions = argmax(logits)

        // Get confidence scores for predicted labels
        var tokenScores: [TokenScore] = []
        for i in 0..<tokenized.realTokenCount {
            let predLabel = predictions[i]
            let confidence = probabilities[i][predLabel]
            let token = tokenizer.convertIdsToTokens([tokenized.inputIds[i]]).first ?? ""

            tokenScores.append(TokenScore(
                token: token,
                labelId: predLabel,
                label: labelMap[predLabel] ?? "O",
                confidence: confidence,
                offset: tokenized.offsetMapping[i]
            ))
        }

        let entities = entityExtractor.extractEntities(
            predictions: predictions,
            tokenizedInput: tokenized,
            tokenizer: tokenizer
        )

        return PHIDetectionResultWithScores(
            text: text,
            entities: entities,
            tokenScores: tokenScores
        )
    }

    // MARK: - Private Methods

    /// Run CoreML model inference.
    private func runInference(_ tokenized: TokenizedInput) throws -> [[Float]] {
        // Prepare input tensors
        let inputIdsArray = try MLMultiArray(shape: [1, NSNumber(value: maxSequenceLength)], dataType: .int32)
        let attentionMaskArray = try MLMultiArray(shape: [1, NSNumber(value: maxSequenceLength)], dataType: .int32)

        for i in 0..<maxSequenceLength {
            inputIdsArray[i] = NSNumber(value: Int32(tokenized.inputIds[i]))
            attentionMaskArray[i] = NSNumber(value: Int32(tokenized.attentionMask[i]))
        }

        // Create feature provider
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputIdsArray),
            "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
        ])

        // Run prediction
        let output = try model.prediction(from: inputFeatures)

        // Extract logits from output
        guard let logitsFeature = output.featureValue(for: "var_407"),
              let logitsArray = logitsFeature.multiArrayValue else {
            // Try alternative output name
            if let firstFeature = output.featureNames.first,
               let altLogits = output.featureValue(for: firstFeature)?.multiArrayValue {
                return extractLogits(from: altLogits)
            }
            throw PHIDetectorError.invalidModelOutput
        }

        return extractLogits(from: logitsArray)
    }

    /// Extract logits from MLMultiArray to 2D Float array.
    private func extractLogits(from array: MLMultiArray) -> [[Float]] {
        let seqLength = array.shape[1].intValue
        let numLabels = array.shape[2].intValue

        var logits: [[Float]] = []

        for i in 0..<seqLength {
            var tokenLogits: [Float] = []
            for j in 0..<numLabels {
                let index = i * numLabels + j
                tokenLogits.append(array[index].floatValue)
            }
            logits.append(tokenLogits)
        }

        return logits
    }

    /// Compute argmax for each token.
    private func argmax(_ logits: [[Float]]) -> [Int] {
        return logits.map { tokenLogits in
            var maxIdx = 0
            var maxVal = tokenLogits[0]
            for (idx, val) in tokenLogits.enumerated() {
                if val > maxVal {
                    maxVal = val
                    maxIdx = idx
                }
            }
            return maxIdx
        }
    }

    /// Apply softmax to logits.
    private func softmax(_ logits: [[Float]]) -> [[Float]] {
        return logits.map { tokenLogits in
            let maxVal = tokenLogits.max() ?? 0
            let exps = tokenLogits.map { exp($0 - maxVal) }
            let sumExps = exps.reduce(0, +)
            return exps.map { $0 / sumExps }
        }
    }

    // MARK: - Label Configuration

    /// Load label map from JSON configuration file.
    private static func loadLabelMap(from url: URL) throws -> [Int: String] {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let labelList = json?["label_list"] as? [String] else {
            throw PHIDetectorError.invalidConfiguration
        }

        var labelMap: [Int: String] = [:]
        for (index, label) in labelList.enumerated() {
            labelMap[index] = label
        }

        return labelMap
    }

    /// Default HIPAA Safe Harbor label map.
    private static func defaultLabelMap() -> [Int: String] {
        let labels = [
            "O",
            "B-NAME", "I-NAME",
            "B-LOCATION", "I-LOCATION",
            "B-DATE", "I-DATE",
            "B-PHONE", "I-PHONE",
            "B-FAX", "I-FAX",
            "B-EMAIL", "I-EMAIL",
            "B-SSN", "I-SSN",
            "B-MRN", "I-MRN",
            "B-HEALTH_PLAN", "I-HEALTH_PLAN",
            "B-ACCOUNT", "I-ACCOUNT",
            "B-LICENSE", "I-LICENSE",
            "B-VEHICLE", "I-VEHICLE",
            "B-DEVICE", "I-DEVICE",
            "B-URL", "I-URL",
            "B-IP", "I-IP",
            "B-BIOMETRIC", "I-BIOMETRIC",
            "B-PHOTO", "I-PHOTO",
            "B-OTHER", "I-OTHER"
        ]

        var labelMap: [Int: String] = [:]
        for (index, label) in labels.enumerated() {
            labelMap[index] = label
        }
        return labelMap
    }
}

// MARK: - Result Types

/// Result of PHI detection.
public struct PHIDetectionResult {
    /// Original input text
    public let text: String

    /// Detected PHI entities
    public let entities: [PHIEntity]

    /// Number of tokens processed
    public let tokenCount: Int

    /// Whether any PHI was detected
    public var containsPHI: Bool {
        !entities.isEmpty
    }

    /// Get entities by type
    public func entities(ofType type: String) -> [PHIEntity] {
        entities.filter { $0.type == type }
    }
}

/// Result with per-token confidence scores.
public struct PHIDetectionResultWithScores {
    /// Original input text
    public let text: String

    /// Detected PHI entities
    public let entities: [PHIEntity]

    /// Per-token prediction scores
    public let tokenScores: [TokenScore]
}

/// A detected PHI entity.
public struct PHIEntity: Equatable, Hashable {
    /// Entity type (e.g., "NAME", "SSN", "DATE")
    public let type: String

    /// Extracted text
    public let text: String

    /// Start character offset in original text
    public let startOffset: Int

    /// End character offset in original text
    public let endOffset: Int

    /// Average confidence score
    public let confidence: Float

    public init(type: String, text: String, startOffset: Int, endOffset: Int, confidence: Float = 1.0) {
        self.type = type
        self.text = text
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.confidence = confidence
    }
}

/// Per-token prediction score.
public struct TokenScore {
    /// Token string
    public let token: String

    /// Predicted label ID
    public let labelId: Int

    /// Predicted label string
    public let label: String

    /// Confidence score (0-1)
    public let confidence: Float

    /// Character offset in original text
    public let offset: (Int, Int)
}

// MARK: - Errors

/// Errors that can occur during PHI detection.
public enum PHIDetectorError: Error, LocalizedError {
    case modelLoadFailed(String)
    case invalidModelOutput
    case invalidConfiguration
    case tokenizationFailed

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .invalidModelOutput:
            return "Model produced invalid output"
        case .invalidConfiguration:
            return "Invalid label configuration"
        case .tokenizationFailed:
            return "Failed to tokenize input text"
        }
    }
}
