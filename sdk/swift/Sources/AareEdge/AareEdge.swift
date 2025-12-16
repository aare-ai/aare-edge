// AareEdge SDK
// On-Device HIPAA PHI Verification
//
// Copyright (c) 2024 Aare
// License: MIT (SDK), Proprietary (Model Weights)

import Foundation

/// Main entry point for Aare Edge SDK
///
/// AareEdge provides on-device HIPAA compliance verification using
/// a neuro-symbolic approach that combines:
/// - Neural entity extraction (CoreML-based NER model)
/// - Formal verification (Z3-style theorem proving)
///
/// Example Usage:
/// ```swift
/// let aare = AareEdge.shared
/// try await aare.loadModel()
///
/// let text = "Patient John Smith (SSN: 123-45-6789) admitted on 01/15/2024"
/// let result = try await aare.verify(text: text)
///
/// print(result.status)  // .violation
/// print(result.proof)   // Detailed proof with violations
/// ```
public struct AareEdge {

    /// SDK version
    public static let version = "1.0.0"

    /// Shared singleton instance
    public static let shared = AareEdge()

    private let verifier: Verifier
    private let configuration: HIPAAConfiguration

    /// Initialize with default configuration
    public init() {
        self.verifier = Verifier()
        self.configuration = HIPAAConfiguration.shared
    }

    /// Initialize with custom configuration
    /// - Parameter config: Extraction configuration
    public init(config: ExtractionConfig) {
        self.verifier = Verifier(config: config)
        self.configuration = HIPAAConfiguration.shared
    }

    // MARK: - Core Verification

    /// Verify text for HIPAA compliance using on-device inference
    ///
    /// This performs complete neuro-symbolic verification:
    /// 1. Tokenizes and runs CoreML inference to detect PHI entities
    /// 2. Applies Z3-style formal verification to prove compliance
    /// 3. Returns detailed results with proof and violations
    ///
    /// - Parameter text: The text to verify
    /// - Returns: Verification result with status, entities, and formal proof
    /// - Throws: VerificationError if inference fails
    public func verify(text: String) async throws -> VerificationResult {
        return try await verifier.verify(text: text)
    }

    /// Verify pre-extracted entities
    ///
    /// Use this when you already have PHI entities and only need
    /// formal verification.
    ///
    /// - Parameter entities: Pre-extracted PHI entities
    /// - Returns: Verification result
    public func verify(entities: [PHIEntity]) -> VerificationResult {
        return verifier.verify(entities: entities)
    }

    /// Batch verify multiple documents
    ///
    /// - Parameter texts: Array of texts to verify
    /// - Returns: Array of verification results
    public func verifyBatch(texts: [String]) async throws -> [VerificationResult] {
        return try await verifier.verifyBatch(texts: texts)
    }

    /// Verify text using cloud API (fallback option)
    ///
    /// - Parameters:
    ///   - text: The text to verify
    ///   - apiEndpoint: API endpoint URL
    /// - Returns: Verification result from cloud
    /// - Throws: VerificationError if network request fails
    public func verifyCloud(text: String, apiEndpoint: URL) async throws -> VerificationResult {
        return try await verifier.verifyCloud(text: text, apiEndpoint: apiEndpoint)
    }

    // MARK: - Model Management

    /// Check if the on-device CoreML model is loaded
    public var isModelLoaded: Bool {
        verifier.isModelLoaded
    }

    /// Load the on-device CoreML model for inference
    ///
    /// - Parameter modelURL: Optional URL to CoreML model. If nil, searches in bundle.
    /// - Throws: VerificationError.modelNotLoaded if model cannot be found
    public func loadModel(from modelURL: URL? = nil) async throws {
        try await verifier.loadModel(from: modelURL)
    }

    // MARK: - Configuration

    /// Get HIPAA configuration
    public var hipaaConfiguration: HIPAAConfiguration {
        configuration
    }

    /// Get list of all prohibited PHI categories
    public var prohibitedCategories: Set<String> {
        configuration.prohibitedCategories
    }

    /// Get all HIPAA rules
    public var rules: [HIPAARule] {
        configuration.rules
    }
}

// MARK: - Convenience Extensions

public extension AareEdge {

    /// Quick compliance check
    ///
    /// - Parameter text: Text to check
    /// - Returns: True if compliant (no PHI detected), false if violations found
    /// - Throws: VerificationError if inference fails
    func isCompliant(text: String) async throws -> Bool {
        return try await verifier.isCompliant(text: text)
    }

    /// Extract PHI entities without full verification
    ///
    /// This runs only the neural extraction step, without Z3 verification.
    /// Useful for getting entity detections without the full proof.
    ///
    /// - Parameter text: Text to analyze
    /// - Returns: Array of detected PHI entities
    /// - Throws: VerificationError if extraction fails
    func detectPHI(text: String) async throws -> [PHIEntity] {
        return try await verifier.extractPHI(text: text)
    }

    /// Generate Z3 SMT-LIB2 constraints for a document
    ///
    /// Useful for debugging or integration with external Z3 solvers.
    ///
    /// - Parameter text: Text to analyze
    /// - Returns: Z3 constraint string in SMT-LIB2 format
    /// - Throws: VerificationError if extraction fails
    func generateConstraints(for text: String) async throws -> String {
        return try await verifier.generateConstraints(for: text)
    }

    /// Export verification result to JSON file
    ///
    /// - Parameters:
    ///   - text: Text to verify
    ///   - outputURL: URL to write JSON result
    /// - Throws: VerificationError or file system errors
    func exportVerification(text: String, to outputURL: URL) async throws {
        try await verifier.exportVerification(text: text, to: outputURL)
    }

    /// Get information about a specific PHI category
    ///
    /// - Parameter category: Category name (e.g., "NAMES", "SSN")
    /// - Returns: Category information or nil if not found
    func getCategoryInfo(_ category: String) -> HIPAACategoryInfo? {
        return configuration.getCategoryInfo(category)
    }

    /// Check if a category is prohibited under HIPAA
    ///
    /// - Parameter category: Category name
    /// - Returns: True if prohibited
    func isProhibited(_ category: String) -> Bool {
        return configuration.isProhibited(category)
    }
}

// MARK: - Demo and Testing

public extension AareEdge {

    /// Run demo verification with sample PHI text
    ///
    /// Useful for testing and demonstrations.
    ///
    /// - Returns: Verification result for demo text
    func runDemo() async throws -> VerificationResult {
        let demoText = """
        Patient: John Smith
        DOB: 01/15/1985
        SSN: 123-45-6789
        Address: 123 Main Street, Boston, MA 02115
        Phone: (617) 555-1234
        Email: john.smith@email.com
        MRN: 98765432

        Chief Complaint: Patient presents with chest pain.
        Admitted: 03/20/2024
        Discharged: 03/22/2024
        """

        return try await verify(text: demoText)
    }

    /// Verify a compliant (de-identified) document
    ///
    /// - Returns: Verification result (should be .compliant)
    func verifyCompliantDemo() async throws -> VerificationResult {
        let compliantText = """
        Patient presented with chest pain.
        Medical history includes hypertension and diabetes.
        Treatment plan: Continue current medications.
        Follow-up in 2 weeks.
        """

        return try await verify(text: compliantText)
    }
}
