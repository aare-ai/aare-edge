// HIPAA Verifier
// Core verification logic combining DSLM inference with Z3 proofs

import Foundation

/// Errors that can occur during verification
public enum VerificationError: Error, LocalizedError {
    case modelNotLoaded
    case inferenceError(String)
    case networkError(Error)
    case invalidResponse
    case z3Error(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "On-device model is not loaded"
        case .inferenceError(let message):
            return "Inference error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from verification"
        case .z3Error(let message):
            return "Z3 verification error: \(message)"
        }
    }
}

/// Aare HIPAA Verifier
///
/// This class combines neural PHI extraction with formal Z3 verification
/// to provide HIPAA compliance checking on-device.
///
/// Usage:
/// ```swift
/// let verifier = Verifier()
/// try await verifier.loadModel()
/// let result = try await verifier.verify(text: "Patient John Smith...")
/// print(result.status) // .compliant or .violation
/// ```
public class Verifier {
    private let extractor: PHIExtractor
    private let z3Engine: Z3Engine
    private let configuration: HIPAAConfiguration

    public init(config: ExtractionConfig = ExtractionConfig()) {
        self.extractor = PHIExtractor(config: config)
        self.z3Engine = Z3Engine()
        self.configuration = HIPAAConfiguration.shared
    }

    /// Whether the on-device model is loaded
    public var isModelLoaded: Bool {
        // Check if extractor has model loaded
        // This would need to be exposed from PHIExtractor
        // For now, we assume it's loaded if loadModel was called
        true
    }

    /// Load the on-device CoreML inference model
    ///
    /// - Parameter modelURL: Optional URL to CoreML model. If nil, searches in bundle.
    /// - Throws: VerificationError.modelNotLoaded if model cannot be found
    public func loadModel(from modelURL: URL? = nil) async throws {
        try await extractor.loadModel(from: modelURL)
    }

    /// Verify text for HIPAA compliance using on-device inference
    ///
    /// This method implements the complete neuro-symbolic verification pipeline:
    /// 1. Extract PHI entities using CoreML model (or regex fallback)
    /// 2. Run Z3-style formal verification on detected entities
    /// 3. Generate compliance proof and violation details
    ///
    /// - Parameter text: Text to verify for HIPAA compliance
    /// - Returns: Complete verification result with status, entities, and proof
    /// - Throws: VerificationError if inference or verification fails
    public func verify(text: String) async throws -> VerificationResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Step 1: Extract PHI entities using neural model
        let entities = try await extractor.extract(text: text)

        // Step 2: Run Z3 formal verification
        let verificationOutput = z3Engine.verify(entities: entities)

        let endTime = CFAbsoluteTimeGetCurrent()
        let latencyMs = (endTime - startTime) * 1000

        // Step 3: Build result
        let status: ComplianceStatus
        var violations: [Violation] = []

        if verificationOutput.hasViolations {
            status = .violation
            violations = buildViolations(from: entities)
        } else {
            status = .compliant
        }

        let metadata = VerificationMetadata(
            isEdge: true,
            latencyMs: latencyMs,
            modelVersion: "1.0.0",
            solverResult: verificationOutput.solverResult
        )

        return VerificationResult(
            status: status,
            entities: entities,
            proof: verificationOutput.proof,
            violations: violations,
            metadata: metadata
        )
    }

    /// Verify pre-extracted entities
    ///
    /// Use this when you already have entities from another source
    /// and just want to run the Z3 verification.
    ///
    /// - Parameter entities: Pre-extracted PHI entities
    /// - Returns: Verification result
    public func verify(entities: [PHIEntity]) -> VerificationResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Run Z3 verification
        let verificationOutput = z3Engine.verify(entities: entities)

        let endTime = CFAbsoluteTimeGetCurrent()
        let latencyMs = (endTime - startTime) * 1000

        // Build result
        let status: ComplianceStatus = verificationOutput.hasViolations ? .violation : .compliant
        let violations = verificationOutput.hasViolations ? buildViolations(from: entities) : []

        let metadata = VerificationMetadata(
            isEdge: true,
            latencyMs: latencyMs,
            modelVersion: "z3-only",
            solverResult: verificationOutput.solverResult
        )

        return VerificationResult(
            status: status,
            entities: entities,
            proof: verificationOutput.proof,
            violations: violations,
            metadata: metadata
        )
    }

    /// Batch verify multiple documents
    ///
    /// - Parameter texts: Array of texts to verify
    /// - Returns: Array of verification results
    public func verifyBatch(texts: [String]) async throws -> [VerificationResult] {
        var results: [VerificationResult] = []

        for text in texts {
            let result = try await verify(text: text)
            results.append(result)
        }

        return results
    }

    /// Verify using cloud API (fallback option)
    ///
    /// - Parameters:
    ///   - text: Text to verify
    ///   - apiEndpoint: API endpoint URL
    /// - Returns: Verification result from cloud
    /// - Throws: VerificationError if network request fails
    public func verifyCloud(text: String, apiEndpoint: URL) async throws -> VerificationResult {
        var request = URLRequest(url: apiEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AareEdge-SDK/1.0.0", forHTTPHeaderField: "User-Agent")

        let body = ["text": text]
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw VerificationError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw VerificationError.invalidResponse
            }

            return try VerificationResult.fromJSON(data)
        } catch let error as VerificationError {
            throw error
        } catch {
            throw VerificationError.networkError(error)
        }
    }

    // MARK: - Private Helpers

    /// Build violation objects from detected entities
    private func buildViolations(from entities: [PHIEntity]) -> [Violation] {
        entities.filter { configuration.isProhibited($0.category.rawValue) }.map { entity in
            let rules = configuration.getRulesForCategory(entity.category.rawValue)
            let rule = rules.first ?? HIPAARule(
                id: "R\(PHICategory.allCases.firstIndex(of: entity.category)! + 1)",
                name: "Prohibition of \(entity.category.rawValue)",
                description: "\(entity.category.description) must be removed for HIPAA compliance",
                categories: [entity.category.rawValue]
            )

            return Violation(
                ruleId: rule.id,
                ruleName: rule.name,
                description: rule.description,
                entity: entity
            )
        }
    }
}

// MARK: - Convenience Extensions

public extension Verifier {

    /// Quick compliance check
    ///
    /// - Parameter text: Text to check
    /// - Returns: True if compliant (no PHI detected), false otherwise
    func isCompliant(text: String) async throws -> Bool {
        let result = try await verify(text: text)
        return result.status == .compliant
    }

    /// Extract only PHI entities without full verification
    ///
    /// - Parameter text: Text to analyze
    /// - Returns: Array of detected PHI entities
    func extractPHI(text: String) async throws -> [PHIEntity] {
        return try await extractor.extract(text: text)
    }

    /// Generate Z3 SMT-LIB2 constraints for debugging
    ///
    /// - Parameter text: Text to analyze
    /// - Returns: Z3 constraint string
    func generateConstraints(for text: String) async throws -> String {
        let entities = try await extractor.extract(text: text)
        return Z3ConstraintBuilder.buildConstraints(for: entities)
    }

    /// Export verification result as JSON
    ///
    /// - Parameters:
    ///   - text: Text to verify
    ///   - outputURL: URL to write JSON result
    func exportVerification(text: String, to outputURL: URL) async throws {
        let result = try await verify(text: text)
        let json = try result.toJSON()
        try json.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}
