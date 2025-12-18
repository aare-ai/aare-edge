import Foundation
import AareEdgeSDK

@MainActor
class PHIDetectionViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var detectionResult: PHIDetectionResult?
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    private var detector: PHIDetector?
    private var mockDetector: MockPHIDetector?
    private var useMockDetector: Bool = false

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
        let currentErrorMessage = errorMessage
        errorMessage = nil
        detectionResult = nil

        if useMockDetector {
            // Use mock detector
            guard let mockDetector = mockDetector else {
                errorMessage = "No detector available"
                isProcessing = false
                return
            }

            let result = await Task.detached { [inputText] in
                mockDetector.detect(inputText)
            }.value

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
                return
            }

            do {
                let result = try await Task.detached { [inputText] in
                    try detector.detect(inputText)
                }.value

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
    }

    func clear() {
        inputText = ""
        detectionResult = nil
        errorMessage = nil
    }
}
