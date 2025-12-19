import Foundation
import AareEdgeSDK
import os.log

private let logger = Logger(subsystem: "com.aare.AareEdgeDemo", category: "PHIDetection")

@MainActor
class PHIDetectionViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var detectionResult: PHIDetectionResult?
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""
    @Published var debugLog: String = ""

    private var detector: PHIDetector?
    private var mockDetector: MockPHIDetector?
    private var useMockDetector: Bool = false

    private func log(_ message: String) {
        debugLog += message + "\n"
        logger.info("\(message)")
    }

    init() {
        loadModel()
    }

    private func loadModel() {
        // Try to load ML model first
        if let modelURL = Bundle.main.url(forResource: "hipaa_phi_detector", withExtension: "mlmodelc"),
           let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "txt") {
            do {
                detector = try PHIDetector(modelURL: modelURL, vocabURL: vocabURL)
                useMockDetector = false
                print("✓ ML model loaded successfully from \(modelURL.path)")
                print("✓ Vocabulary loaded from \(vocabURL.path)")
            } catch {
                print("Failed to load ML model: \(error.localizedDescription)")
                useMockDetector = true
                mockDetector = MockPHIDetector()
                errorMessage = "Using pattern-based detection (ML model unavailable: \(error.localizedDescription))"
            }
        } else {
            print("ML model files not found in bundle")
            useMockDetector = true
            mockDetector = MockPHIDetector()
            errorMessage = "Using pattern-based detection (ML model files not found)"
        }
    }

    func detectPHI() async {
        guard !inputText.isEmpty else { return }

        isProcessing = true
        statusMessage = "Initializing detection..."
        let currentErrorMessage = errorMessage
        errorMessage = nil
        detectionResult = nil

        // Small delay to show the status message
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        if useMockDetector {
            // Use mock detector
            guard let mockDetector = mockDetector else {
                errorMessage = "No detector available"
                isProcessing = false
                statusMessage = ""
                return
            }

            statusMessage = "Analyzing text with pattern matching..."

            let result = await Task.detached { [inputText] in
                mockDetector.detect(inputText)
            }.value

            statusMessage = "Processing complete"
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            self.detectionResult = result
            // Restore the info message about using pattern-based detection
            if result.entities.isEmpty {
                errorMessage = currentErrorMessage
            }
        } else {
            // Use ML model
            guard let detector = detector else {
                errorMessage = "Detector not initialized"
                isProcessing = false
                statusMessage = ""
                return
            }

            statusMessage = "Tokenizing input text..."
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

            statusMessage = "Running ML inference on-device..."

            do {
                let resultWithScores = try await Task.detached { [inputText] in
                    try detector.detectWithScores(inputText)
                }.value

                // Create regular result for UI
                let result = PHIDetectionResult(
                    text: resultWithScores.text,
                    entities: resultWithScores.entities,
                    tokenCount: resultWithScores.tokenScores.count
                )

                statusMessage = "Analyzing \(result.tokenCount) tokens..."
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

                if result.containsPHI {
                    statusMessage = "Found \(result.entities.count) PHI entities"
                } else {
                    statusMessage = "No PHI detected"
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

                // Detailed logging for UI debugging
                self.debugLog = "" // Clear previous log
                let textLen = self.inputText.count
                log("=== PHI DETECTION RESULTS ===")
                log("Input: '\(self.inputText.prefix(50))...'")
                log("Input length: \(textLen) chars")
                log("Contains PHI: \(result.containsPHI)")
                log("Tokens: \(result.tokenCount)")
                log("Entities: \(result.entities.count)")

                // Log token-level predictions
                log("---")
                log("TOKEN PREDICTIONS (non-O only):")
                for score in resultWithScores.tokenScores {
                    if score.label != "O" && score.token != "[CLS]" && score.token != "[SEP]" && score.token != "[PAD]" {
                        log("  \(score.token) (tid:\(score.tokenId)) -> \(score.label) (lid:\(score.labelId))")
                    }
                }
                log("---")

                if result.entities.isEmpty {
                    log("No PHI entities detected.")
                } else {
                    log("EXTRACTED ENTITIES:")
                    for (index, entity) in result.entities.enumerated() {
                        let idx = index + 1
                        let entityType = entity.type
                        let entityText = entity.text
                        let startOff = entity.startOffset
                        let endOff = entity.endOffset
                        let conf = entity.confidence
                        log("[\(idx)] \(entityType): '\(entityText)'")
                        log("    offsets: [\(startOff)-\(endOff)]")
                        log("    confidence: \(String(format: "%.3f", conf))")

                        // Verify the text matches the offsets
                        if startOff >= 0 && endOff <= textLen && startOff < endOff {
                            let startIdx = self.inputText.index(self.inputText.startIndex, offsetBy: startOff)
                            let endIdx = self.inputText.index(self.inputText.startIndex, offsetBy: endOff)
                            let extractedText = String(self.inputText[startIdx..<endIdx])
                            if extractedText != entityText {
                                log("    ⚠️ MISMATCH!")
                                log("    extracted: '\(extractedText)'")
                            }
                        } else {
                            log("    ⚠️ INVALID OFFSETS")
                        }
                    }
                }
                log("=== END ===")

                self.detectionResult = result

                if result.entities.isEmpty {
                    print("No PHI detected. Processed \(result.tokenCount) tokens.")
                }
            } catch {
                self.errorMessage = "Detection failed: \(error.localizedDescription)"
                print("Detection error: \(error)")
            }
        }

        isProcessing = false
        statusMessage = ""
    }

    func clear() {
        inputText = ""
        detectionResult = nil
        errorMessage = nil
    }
}
