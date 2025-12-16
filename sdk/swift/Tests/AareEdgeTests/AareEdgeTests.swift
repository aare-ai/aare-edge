// AareEdge SDK Tests

import XCTest
@testable import AareEdge

final class AareEdgeTests: XCTestCase {

    // MARK: - PHI Entity Tests

    func testPHICategoryDescription() {
        XCTAssertEqual(PHICategory.names.description, "Names")
        XCTAssertEqual(PHICategory.ssn.description, "Social Security Numbers")
        XCTAssertEqual(PHICategory.emailAddresses.description, "Email Addresses")
    }

    func testPHICategoryIsProhibited() {
        for category in PHICategory.allCases {
            XCTAssertTrue(category.isProhibited, "\(category) should be prohibited")
        }
    }

    func testPHIEntityCreation() {
        let entity = PHIEntity(
            category: .ssn,
            value: "123-45-6789",
            startIndex: 10,
            endIndex: 21,
            confidence: 0.95
        )

        XCTAssertEqual(entity.category, .ssn)
        XCTAssertEqual(entity.value, "123-45-6789")
        XCTAssertEqual(entity.startIndex, 10)
        XCTAssertEqual(entity.endIndex, 21)
        XCTAssertEqual(entity.confidence, 0.95)
        XCTAssertEqual(entity.confidencePercent, "95%")
    }

    // MARK: - Extractor Tests

    func testRegexExtractorSSN() {
        let extractor = PHIExtractor()
        let text = "Patient SSN: 123-45-6789"
        let entities = extractor.extractWithRegex(text: text)

        XCTAssertFalse(entities.isEmpty)
        XCTAssertTrue(entities.contains { $0.category == .ssn && $0.value == "123-45-6789" })
    }

    func testRegexExtractorEmail() {
        let extractor = PHIExtractor()
        let text = "Contact: john.doe@hospital.com"
        let entities = extractor.extractWithRegex(text: text)

        XCTAssertFalse(entities.isEmpty)
        XCTAssertTrue(entities.contains { $0.category == .emailAddresses && $0.value == "john.doe@hospital.com" })
    }

    func testRegexExtractorPhoneNumber() {
        let extractor = PHIExtractor()
        let text = "Call 555-123-4567 for appointments"
        let entities = extractor.extractWithRegex(text: text)

        XCTAssertFalse(entities.isEmpty)
        XCTAssertTrue(entities.contains { $0.category == .phoneNumbers })
    }

    func testRegexExtractorIP() {
        let extractor = PHIExtractor()
        let text = "Login from IP: 192.168.1.100"
        let entities = extractor.extractWithRegex(text: text)

        XCTAssertFalse(entities.isEmpty)
        XCTAssertTrue(entities.contains { $0.category == .ipAddresses && $0.value == "192.168.1.100" })
    }

    func testRegexExtractorDate() {
        let extractor = PHIExtractor()
        let text = "DOB: 01/15/1985"
        let entities = extractor.extractWithRegex(text: text)

        XCTAssertFalse(entities.isEmpty)
        XCTAssertTrue(entities.contains { $0.category == .dates })
    }

    func testRegexExtractorMRN() {
        let extractor = PHIExtractor()
        let text = "MRN: 12345678"
        let entities = extractor.extractWithRegex(text: text)

        XCTAssertFalse(entities.isEmpty)
        XCTAssertTrue(entities.contains { $0.category == .medicalRecordNumbers })
    }

    func testRegexExtractorNoFalsePositives() {
        let extractor = PHIExtractor()
        let text = "The patient has a normal blood pressure reading."
        let entities = extractor.extractWithRegex(text: text)

        XCTAssertTrue(entities.isEmpty, "Should not detect PHI in clean text")
    }

    // MARK: - Z3 Engine Tests

    func testZ3EngineCompliant() {
        let engine = Z3Engine()
        let result = engine.verify(entities: [])

        XCTAssertFalse(result.hasViolations)
        XCTAssertEqual(result.solverResult, "sat")
        XCTAssertTrue(result.proof.contains("COMPLIANT"))
    }

    func testZ3EngineViolation() {
        let engine = Z3Engine()
        let entities = [
            PHIEntity(category: .ssn, value: "123-45-6789", startIndex: 0, endIndex: 11, confidence: 0.9)
        ]
        let result = engine.verify(entities: entities)

        XCTAssertTrue(result.hasViolations)
        XCTAssertEqual(result.solverResult, "unsat")
        XCTAssertTrue(result.proof.contains("VIOLATION"))
        XCTAssertTrue(result.violatedCategories.contains(.ssn))
    }

    func testZ3EngineMultipleViolations() {
        let engine = Z3Engine()
        let entities = [
            PHIEntity(category: .ssn, value: "123-45-6789", startIndex: 0, endIndex: 11, confidence: 0.9),
            PHIEntity(category: .emailAddresses, value: "test@test.com", startIndex: 20, endIndex: 33, confidence: 0.85)
        ]
        let result = engine.verify(entities: entities)

        XCTAssertTrue(result.hasViolations)
        XCTAssertEqual(result.violatedCategories.count, 2)
        XCTAssertTrue(result.violatedCategories.contains(.ssn))
        XCTAssertTrue(result.violatedCategories.contains(.emailAddresses))
    }

    // MARK: - Verification Result Tests

    func testVerificationResultCompliant() {
        let result = VerificationResult(
            status: .compliant,
            entities: [],
            proof: "Test proof"
        )

        XCTAssertEqual(result.status, .compliant)
        XCTAssertTrue(result.status.passed)
        XCTAssertEqual(result.entityCount, 0)
        XCTAssertEqual(result.violationCount, 0)
    }

    func testVerificationResultViolation() {
        let entity = PHIEntity(category: .ssn, value: "123-45-6789", startIndex: 0, endIndex: 11, confidence: 0.9)
        let violation = Violation(ruleId: "R7", ruleName: "SSN", description: "SSN detected", entity: entity)

        let result = VerificationResult(
            status: .violation,
            entities: [entity],
            proof: "Test proof",
            violations: [violation]
        )

        XCTAssertEqual(result.status, .violation)
        XCTAssertFalse(result.status.passed)
        XCTAssertEqual(result.entityCount, 1)
        XCTAssertEqual(result.violationCount, 1)
        XCTAssertTrue(result.detectedCategories.contains(.ssn))
    }

    func testVerificationResultJSON() throws {
        let result = VerificationResult(
            status: .compliant,
            entities: [],
            proof: "HIPAA Compliant"
        )

        let json = try result.toJSON()
        XCTAssertTrue(json.contains("compliant"))
        XCTAssertTrue(json.contains("HIPAA Compliant"))
    }

    // MARK: - Integration Tests

    func testFullVerificationPipeline() async throws {
        let verifier = Verifier()

        // Test compliant text
        let compliantText = "The patient has normal vital signs."
        let compliantResult = try await verifier.verify(text: compliantText)
        XCTAssertEqual(compliantResult.status, .compliant)

        // Test text with PHI
        let phiText = "Patient SSN: 123-45-6789, Email: john@example.com"
        let phiResult = try await verifier.verify(text: phiText)
        XCTAssertEqual(phiResult.status, .violation)
        XCTAssertGreaterThan(phiResult.entityCount, 0)
    }
}
