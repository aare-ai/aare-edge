import XCTest
@testable import AareEdgeSDK

final class Z3LiteTests: XCTestCase {

    func testBooleanSatisfiability() {
        let solver = Z3Lite()

        let x = solver.boolVar("x")
        solver.assert(x)
        solver.bind("x", to: .bool(true))

        let result = solver.check()
        XCTAssertTrue(result.isSatisfiable)
    }

    func testBooleanUnsatisfiability() {
        let solver = Z3Lite()

        let x = solver.boolVar("x")
        solver.assert(x)
        solver.bind("x", to: .bool(false))

        let result = solver.check()
        XCTAssertTrue(result.isUnsatisfiable)
    }

    func testIntegerComparison() {
        let solver = Z3Lite()

        let x = solver.intVar("x")
        solver.assert(x.gt(5))
        solver.bind("x", to: .int(10))

        let result = solver.check()
        XCTAssertTrue(result.isSatisfiable)
    }

    func testIntegerComparisonFails() {
        let solver = Z3Lite()

        let x = solver.intVar("x")
        solver.assert(x.gt(5))
        solver.bind("x", to: .int(3))

        let result = solver.check()
        XCTAssertTrue(result.isUnsatisfiable)
    }

    func testAndExpression() {
        let solver = Z3Lite()

        let x = solver.boolVar("x")
        let y = solver.boolVar("y")

        solver.assert(x.and(y))
        solver.bind("x", to: .bool(true))
        solver.bind("y", to: .bool(true))

        let result = solver.check()
        XCTAssertTrue(result.isSatisfiable)
    }

    func testAndExpressionPartialFalse() {
        let solver = Z3Lite()

        let x = solver.boolVar("x")
        let y = solver.boolVar("y")

        solver.assert(x.and(y))
        solver.bind("x", to: .bool(true))
        solver.bind("y", to: .bool(false))

        let result = solver.check()
        XCTAssertTrue(result.isUnsatisfiable)
    }

    func testOrExpression() {
        let solver = Z3Lite()

        let x = solver.boolVar("x")
        let y = solver.boolVar("y")

        solver.assert(x.or(y))
        solver.bind("x", to: .bool(false))
        solver.bind("y", to: .bool(true))

        let result = solver.check()
        XCTAssertTrue(result.isSatisfiable)
    }

    func testImplication() {
        let solver = Z3Lite()

        let x = solver.boolVar("x")
        let y = solver.boolVar("y")

        // x implies y: if x is true, y must be true
        solver.assert(x.implies(y))
        solver.bind("x", to: .bool(true))
        solver.bind("y", to: .bool(true))

        let result = solver.check()
        XCTAssertTrue(result.isSatisfiable)
    }

    func testImplicationViolated() {
        let solver = Z3Lite()

        let x = solver.boolVar("x")
        let y = solver.boolVar("y")

        // x implies y: if x is true, y must be true
        solver.assert(x.implies(y))
        solver.bind("x", to: .bool(true))
        solver.bind("y", to: .bool(false))

        let result = solver.check()
        XCTAssertTrue(result.isUnsatisfiable)
    }

    func testNotExpression() {
        let solver = Z3Lite()

        let x = solver.boolVar("x")
        solver.assert(x.not())
        solver.bind("x", to: .bool(false))

        let result = solver.check()
        XCTAssertTrue(result.isSatisfiable)
    }

    func testFloatComparison() {
        let solver = Z3Lite()

        let dti = solver.floatVar("dti")
        solver.assert(dti.lte(0.43))
        solver.bind("dti", to: .float(0.35))

        let result = solver.check()
        XCTAssertTrue(result.isSatisfiable)
    }

    func testFloatComparisonFails() {
        let solver = Z3Lite()

        let dti = solver.floatVar("dti")
        solver.assert(dti.lte(0.43))
        solver.bind("dti", to: .float(0.50))

        let result = solver.check()
        XCTAssertTrue(result.isUnsatisfiable)
    }

    func testStringEquality() {
        let solver = Z3Lite()

        let status = solver.stringVar("status")
        solver.assert(status.eq("approved"))
        solver.bind("status", to: .string("approved"))

        let result = solver.check()
        XCTAssertTrue(result.isSatisfiable)
    }

    func testVerifyConstraintHolds() {
        let solver = Z3Lite()

        let phiCount = solver.intVar("phi_count")
        solver.bind("phi_count", to: .int(0))

        // Verify that phi_count == 0
        let constraint = phiCount.eq(0)
        let result = solver.verify(constraint)

        XCTAssertTrue(result.holds)
        XCTAssertNil(result.counterexample)
    }

    func testVerifyConstraintFails() {
        let solver = Z3Lite()

        let phiCount = solver.intVar("phi_count")
        solver.bind("phi_count", to: .int(3))

        // Verify that phi_count == 0 (should fail)
        let constraint = phiCount.eq(0)
        let result = solver.verify(constraint)

        XCTAssertFalse(result.holds)
    }

    func testPushPop() {
        let solver = Z3Lite()

        let x = solver.intVar("x")
        solver.assert(x.gt(0))

        solver.push()
        solver.assert(x.lt(5))
        solver.bind("x", to: .int(3))

        let result1 = solver.check()
        XCTAssertTrue(result1.isSatisfiable)

        solver.pop()

        // After pop, only x > 0 should be asserted
        solver.bind("x", to: .int(10))
        let result2 = solver.check()
        XCTAssertTrue(result2.isSatisfiable)
    }

    func testReset() {
        let solver = Z3Lite()

        let x = solver.intVar("x")
        solver.assert(x.gt(100))
        solver.bind("x", to: .int(50))

        let result1 = solver.check()
        XCTAssertTrue(result1.isUnsatisfiable)

        solver.reset()

        let y = solver.intVar("y")
        solver.assert(y.lt(10))
        solver.bind("y", to: .int(5))

        let result2 = solver.check()
        XCTAssertTrue(result2.isSatisfiable)
    }

    func testComplexPolicy() {
        // Simulate a HIPAA compliance policy check
        let solver = Z3Lite()

        let hasPHI = solver.boolVar("has_phi")
        let isEncrypted = solver.boolVar("is_encrypted")
        let hasConsent = solver.boolVar("has_consent")

        // Policy: if PHI is present, must be encrypted OR have consent
        solver.assert(
            hasPHI.implies(isEncrypted.or(hasConsent))
        )

        // Test case: PHI present, encrypted, no consent
        solver.bind("has_phi", to: .bool(true))
        solver.bind("is_encrypted", to: .bool(true))
        solver.bind("has_consent", to: .bool(false))

        let result = solver.check()
        XCTAssertTrue(result.isSatisfiable)
    }

    func testPHIDetectionPolicy() {
        // Realistic test: verify no PHI for public release
        let solver = Z3Lite()

        let phiCount = solver.intVar("phi_count")
        let isPublic = solver.boolVar("is_public")

        // Policy: if public release, PHI count must be 0
        solver.assert(
            isPublic.implies(phiCount.eq(0))
        )

        // Scenario: trying to release publicly with 2 PHI entities
        solver.bind("is_public", to: .bool(true))
        solver.bind("phi_count", to: .int(2))

        let result = solver.check()
        XCTAssertTrue(result.isUnsatisfiable) // Policy violated!
    }
}
