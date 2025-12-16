# Aare Edge SDK - Code Examples

Complete examples demonstrating the Swift SDK usage.

## Table of Contents

1. [Basic Verification](#basic-verification)
2. [iOS App Integration](#ios-app-integration)
3. [macOS Command Line Tool](#macos-command-line-tool)
4. [Advanced Usage](#advanced-usage)
5. [Error Handling](#error-handling)
6. [Testing](#testing)

## Basic Verification

### Simple Compliance Check

```swift
import AareEdge

func checkCompliance(text: String) async {
    let aare = AareEdge.shared

    do {
        let result = try await aare.verify(text: text)

        print("Status: \(result.status.description)")
        print("Entities found: \(result.entityCount)")
        print("Violations: \(result.violationCount)")
        print("\nProof:\n\(result.proof)")

    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

// Usage
await checkCompliance(text: "Patient John Smith, SSN: 123-45-6789")
```

### Extract PHI Without Full Verification

```swift
import AareEdge

func findPHI(in text: String) async throws -> [PHIEntity] {
    let aare = AareEdge.shared
    let entities = try await aare.detectPHI(text: text)

    print("Found \(entities.count) PHI entities:")
    for entity in entities {
        print("- \(entity.category.description): \(entity.value)")
        print("  Position: \(entity.startIndex)-\(entity.endIndex)")
        print("  Confidence: \(entity.confidencePercent)")
    }

    return entities
}
```

## iOS App Integration

### SwiftUI View with Real-Time Verification

```swift
import SwiftUI
import AareEdge

struct DocumentVerifierView: View {
    @State private var documentText = ""
    @State private var verificationResult: VerificationResult?
    @State private var isVerifying = false
    @State private var errorMessage: String?

    let aare = AareEdge.shared

    var body: some View {
        VStack(spacing: 20) {
            // Input
            TextEditor(text: $documentText)
                .frame(height: 200)
                .border(Color.gray, width: 1)
                .padding()

            // Verify Button
            Button("Verify HIPAA Compliance") {
                Task {
                    await verifyDocument()
                }
            }
            .disabled(isVerifying || documentText.isEmpty)

            if isVerifying {
                ProgressView("Verifying...")
            }

            // Results
            if let result = verificationResult {
                resultView(result: result)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }

            Spacer()
        }
        .padding()
        .task {
            // Load model on view appear
            try? await aare.loadModel()
        }
    }

    func verifyDocument() async {
        isVerifying = true
        errorMessage = nil

        do {
            let result = try await aare.verify(text: documentText)
            verificationResult = result
        } catch {
            errorMessage = error.localizedDescription
        }

        isVerifying = false
    }

    @ViewBuilder
    func resultView(result: VerificationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status Badge
            HStack {
                Image(systemName: result.status == .compliant ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.status == .compliant ? .green : .red)
                Text(result.status.description)
                    .font(.headline)
            }

            // Statistics
            HStack {
                StatItem(label: "Entities", value: "\(result.entityCount)")
                StatItem(label: "Violations", value: "\(result.violationCount)")
                StatItem(label: "Latency", value: String(format: "%.0fms", result.metadata.latencyMs ?? 0))
            }

            // Entities List
            if !result.entities.isEmpty {
                Text("Detected PHI:")
                    .font(.headline)

                ScrollView {
                    ForEach(result.entities) { entity in
                        EntityRow(entity: entity)
                    }
                }
                .frame(maxHeight: 200)
            }

            // Proof
            DisclosureGroup("View Formal Proof") {
                ScrollView {
                    Text(result.proof)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .bold()
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EntityRow: View {
    let entity: PHIEntity

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading) {
                Text(entity.category.description)
                    .font(.headline)
                Text(entity.value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(entity.confidencePercent)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

### View Model Pattern

```swift
import Foundation
import AareEdge
import Combine

@MainActor
class VerificationViewModel: ObservableObject {
    @Published var documentText = ""
    @Published var result: VerificationResult?
    @Published var isLoading = false
    @Published var error: Error?

    private let aare = AareEdge.shared
    private var verificationTask: Task<Void, Never>?

    init() {
        // Load model asynchronously
        Task {
            try? await aare.loadModel()
        }
    }

    func verify() {
        // Cancel any existing verification
        verificationTask?.cancel()

        verificationTask = Task {
            isLoading = true
            error = nil

            do {
                let result = try await aare.verify(text: documentText)
                self.result = result
            } catch {
                self.error = error
            }

            isLoading = false
        }
    }

    func verifyBatch(documents: [String]) async throws -> [VerificationResult] {
        isLoading = true
        defer { isLoading = false }

        return try await aare.verifyBatch(texts: documents)
    }

    func exportResult(to url: URL) async throws {
        guard let result = result else { return }

        let json = try result.toJSON()
        try json.write(to: url, atomically: true, encoding: .utf8)
    }
}
```

## macOS Command Line Tool

### Complete CLI Application

```swift
import Foundation
import AareEdge
import ArgumentParser

@main
struct AareCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "aare",
        abstract: "HIPAA PHI Verification Tool",
        version: "1.0.0"
    )

    @Argument(help: "Text file to verify")
    var input: String?

    @Option(name: .shortAndLong, help: "Output file for results")
    var output: String?

    @Option(name: .shortAndLong, help: "Output format (text or json)")
    var format: String = "text"

    @Flag(name: .long, help: "Run in batch mode (one document per line)")
    var batch = false

    @Flag(name: .long, help: "Run demo verification")
    var demo = false

    mutating func run() async throws {
        let aare = AareEdge.shared

        // Load model
        print("Loading model...")
        try? await aare.loadModel()

        if demo {
            try await runDemo(aare: aare)
            return
        }

        guard let inputPath = input else {
            print("Error: No input file specified")
            throw ExitCode.failure
        }

        let text = try String(contentsOfFile: inputPath, encoding: .utf8)

        if batch {
            try await runBatch(aare: aare, text: text)
        } else {
            try await runSingle(aare: aare, text: text)
        }
    }

    func runSingle(aare: AareEdge, text: String) async throws {
        print("Verifying document...")
        let result = try await aare.verify(text: text)

        let outputText: String
        if format == "json" {
            outputText = try result.toJSON()
        } else {
            outputText = formatTextOutput(result: result)
        }

        if let outputPath = output {
            try outputText.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Results written to \(outputPath)")
        } else {
            print(outputText)
        }
    }

    func runBatch(aare: AareEdge, text: String) async throws {
        let documents = text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        print("Verifying \(documents.count) documents...")

        let results = try await aare.verifyBatch(texts: documents)

        let compliantCount = results.filter { $0.status == .compliant }.count
        let violationCount = results.count - compliantCount

        print("\nBatch Results:")
        print("  Total: \(results.count)")
        print("  Compliant: \(compliantCount)")
        print("  Violations: \(violationCount)")

        if let outputPath = output {
            let outputText = results.map { try? $0.toJSON() }
                .compactMap { $0 }
                .joined(separator: "\n")

            try outputText.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("\nResults written to \(outputPath)")
        }
    }

    func runDemo(aare: AareEdge) async throws {
        print("Running HIPAA verification demo...\n")

        print("1. Testing document with PHI violations:")
        print("=" * 60)
        let violationResult = try await aare.runDemo()
        print(violationResult.proof)

        print("\n2. Testing compliant document:")
        print("=" * 60)
        let compliantResult = try await aare.verifyCompliantDemo()
        print(compliantResult.proof)
    }

    func formatTextOutput(result: VerificationResult) -> String {
        var lines: [String] = []

        lines.append("HIPAA VERIFICATION REPORT")
        lines.append(String(repeating: "=", count: 60))
        lines.append("")
        lines.append("Status: \(result.status.description)")
        lines.append("Timestamp: \(result.timestamp)")
        lines.append("Latency: \(String(format: "%.2fms", result.metadata.latencyMs ?? 0))")
        lines.append("")

        if !result.entities.isEmpty {
            lines.append("DETECTED ENTITIES (\(result.entityCount)):")
            lines.append(String(repeating: "-", count: 60))
            for entity in result.entities {
                lines.append("\(entity.category.rawValue): \(entity.value)")
                lines.append("  Position: \(entity.startIndex)-\(entity.endIndex)")
                lines.append("  Confidence: \(entity.confidencePercent)")
                lines.append("")
            }
        }

        if !result.violations.isEmpty {
            lines.append("VIOLATIONS (\(result.violationCount)):")
            lines.append(String(repeating: "-", count: 60))
            for violation in result.violations {
                lines.append("\(violation.ruleId): \(violation.ruleName)")
                lines.append("  \(violation.description)")
                lines.append("")
            }
        }

        lines.append("FORMAL PROOF:")
        lines.append(String(repeating: "-", count: 60))
        lines.append(result.proof)

        return lines.joined(separator: "\n")
    }
}
```

## Advanced Usage

### Custom Model Integration

```swift
import AareEdge

// Load custom CoreML model
let modelURL = Bundle.main.url(forResource: "custom_phi_model", withExtension: "mlmodelc")!
let config = ExtractionConfig(
    modelName: "custom_phi_model",
    maxLength: 512,
    confidenceThreshold: 0.75
)

let aare = AareEdge(config: config)
try await aare.loadModel(from: modelURL)

let result = try await aare.verify(text: "Patient data...")
```

### Verify Pre-Extracted Entities

```swift
// If you already have entities from another source
let entities = [
    PHIEntity(
        category: .names,
        value: "John Smith",
        startIndex: 10,
        endIndex: 20,
        confidence: 0.95
    ),
    PHIEntity(
        category: .ssn,
        value: "123-45-6789",
        startIndex: 30,
        endIndex: 41,
        confidence: 0.99
    )
]

let result = aare.verify(entities: entities)
print(result.status)  // .violation
```

### Generate Z3 Constraints

```swift
let text = "Patient John Smith, MRN: 12345"
let constraints = try await aare.generateConstraints(for: text)

print(constraints)
/*
; HIPAA Safe Harbor Verification Constraints
; Generated by Aare Edge SDK

(declare-const NAMES_detected Bool)
(declare-const SSN_detected Bool)
...
(assert (= NAMES_detected true))
(assert (= SSN_detected false))
...
(check-sat)
*/
```

## Error Handling

### Comprehensive Error Handling

```swift
import AareEdge

func robustVerification(text: String) async {
    let aare = AareEdge.shared

    do {
        // Try to load model (optional)
        do {
            try await aare.loadModel()
            print("✓ CoreML model loaded")
        } catch {
            print("⚠ Model not loaded, using regex fallback")
        }

        // Verify
        let result = try await aare.verify(text: text)

        // Process result
        switch result.status {
        case .compliant:
            print("✓ Document is HIPAA compliant")

        case .violation:
            print("✗ HIPAA violations detected:")
            for violation in result.violations {
                print("  - \(violation.description)")
            }

        case .error:
            print("⚠ Verification completed with errors")
        }

    } catch VerificationError.modelNotLoaded {
        print("Error: Could not load ML model")

    } catch VerificationError.inferenceError(let message) {
        print("Inference error: \(message)")

    } catch VerificationError.networkError(let error) {
        print("Network error: \(error.localizedDescription)")

    } catch {
        print("Unexpected error: \(error)")
    }
}
```

## Testing

### Unit Tests

```swift
import XCTest
@testable import AareEdge

final class AareEdgeTests: XCTestCase {

    func testCompliantDocument() async throws {
        let aare = AareEdge.shared

        let compliantText = """
        Patient presented with symptoms.
        Treatment plan initiated.
        """

        let result = try await aare.verify(text: compliantText)

        XCTAssertEqual(result.status, .compliant)
        XCTAssertEqual(result.entityCount, 0)
        XCTAssertEqual(result.violationCount, 0)
    }

    func testViolationDetection() async throws {
        let aare = AareEdge.shared

        let phiText = """
        Patient: John Smith
        SSN: 123-45-6789
        Phone: 555-1234
        """

        let result = try await aare.verify(text: phiText)

        XCTAssertEqual(result.status, .violation)
        XCTAssertGreaterThan(result.entityCount, 0)
        XCTAssertGreaterThan(result.violationCount, 0)

        // Check specific categories
        let categories = result.detectedCategories
        XCTAssertTrue(categories.contains(.names))
        XCTAssertTrue(categories.contains(.ssn))
    }

    func testEntityExtraction() async throws {
        let aare = AareEdge.shared

        let text = "Email: test@example.com"
        let entities = try await aare.detectPHI(text: text)

        XCTAssertFalse(entities.isEmpty)

        let emailEntity = entities.first { $0.category == .emailAddresses }
        XCTAssertNotNil(emailEntity)
        XCTAssertEqual(emailEntity?.value, "test@example.com")
    }

    func testBatchVerification() async throws {
        let aare = AareEdge.shared

        let documents = [
            "Clean document with no PHI",
            "Patient John Smith SSN: 123-45-6789",
            "Another clean document"
        ]

        let results = try await aare.verifyBatch(texts: documents)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].status, .compliant)
        XCTAssertEqual(results[1].status, .violation)
        XCTAssertEqual(results[2].status, .compliant)
    }

    func testJSONSerialization() async throws {
        let aare = AareEdge.shared

        let text = "Patient data with PHI"
        let result = try await aare.verify(text: text)

        // Serialize to JSON
        let json = try result.toJSON()
        XCTAssertFalse(json.isEmpty)

        // Deserialize
        let data = json.data(using: .utf8)!
        let decoded = try VerificationResult.fromJSON(data)

        XCTAssertEqual(decoded.status, result.status)
        XCTAssertEqual(decoded.entityCount, result.entityCount)
    }
}
```

### Integration Tests

```swift
func testEndToEndVerification() async throws {
    // Real medical record example (synthetic data)
    let medicalRecord = """
    PATIENT INFORMATION
    Name: Jane Doe
    Date of Birth: 05/15/1978
    SSN: 987-65-4321
    MRN: 1234567890

    ADDRESS
    123 Medical Plaza
    Boston, MA 02115
    Phone: (617) 555-9876
    Email: jane.doe@email.com

    VISIT SUMMARY
    Admission Date: 03/20/2024
    Discharge Date: 03/22/2024
    Attending Physician: Dr. Smith
    Diagnosis: Acute bronchitis
    """

    let aare = AareEdge.shared
    let result = try await aare.verify(text: medicalRecord)

    // Should detect violations
    XCTAssertEqual(result.status, .violation)

    // Should detect multiple PHI categories
    let categories = result.detectedCategories
    XCTAssertTrue(categories.contains(.names))
    XCTAssertTrue(categories.contains(.dates))
    XCTAssertTrue(categories.contains(.ssn))
    XCTAssertTrue(categories.contains(.phoneNumbers))
    XCTAssertTrue(categories.contains(.emailAddresses))
    XCTAssertTrue(categories.contains(.medicalRecordNumbers))
    XCTAssertTrue(categories.contains(.geographicSubdivisions))

    // Verify proof is generated
    XCTAssertFalse(result.proof.isEmpty)
    XCTAssertTrue(result.proof.contains("VIOLATION"))

    print(result.proof)
}
```

## Performance Monitoring

```swift
func benchmarkVerification(documents: [String]) async {
    let aare = AareEdge.shared

    var totalLatency: Double = 0
    var results: [VerificationResult] = []

    for document in documents {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try! await aare.verify(text: document)
        let end = CFAbsoluteTimeGetCurrent()

        totalLatency += (end - start) * 1000
        results.append(result)
    }

    let avgLatency = totalLatency / Double(documents.count)

    print("Performance Metrics:")
    print("  Documents: \(documents.count)")
    print("  Total time: \(String(format: "%.2fms", totalLatency))")
    print("  Average latency: \(String(format: "%.2fms", avgLatency))")
    print("  Throughput: \(String(format: "%.1f docs/sec", 1000.0 / avgLatency))")
}
```

---

For more examples and documentation, visit [https://docs.aare.ai](https://docs.aare.ai)
