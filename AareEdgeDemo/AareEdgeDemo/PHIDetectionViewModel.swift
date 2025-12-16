import Foundation
import AareEdgeSDK

@MainActor
class PHIDetectionViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var detectionResult: PHIDetectionResult?
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    private var detector: PHIDetector?

    init() {
        loadModel()
    }

    private func loadModel() {
        // Model and vocabulary should be bundled with the app
        guard let modelURL = Bundle.main.url(forResource: "hipaa_ner", withExtension: "mlpackage"),
              let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "txt") else {
            errorMessage = "Model files not found. Please add hipaa_ner.mlpackage and vocab.txt to the app bundle."
            return
        }

        do {
            detector = try PHIDetector(modelURL: modelURL, vocabURL: vocabURL)
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }

    func detectPHI() async {
        guard let detector = detector else {
            errorMessage = "Detector not initialized"
            return
        }

        guard !inputText.isEmpty else { return }

        isProcessing = true
        errorMessage = nil
        detectionResult = nil

        do {
            // Run detection on background thread
            let result = try await Task.detached { [inputText] in
                try detector.detect(inputText)
            }.value

            self.detectionResult = result
        } catch {
            self.errorMessage = "Detection failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    func clear() {
        inputText = ""
        detectionResult = nil
        errorMessage = nil
    }
}
