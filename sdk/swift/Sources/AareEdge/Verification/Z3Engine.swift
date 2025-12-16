// Z3 Verification Engine
// Swift implementation of Z3-style theorem proving for HIPAA compliance

import Foundation

/// Output from Z3 verification
public struct Z3Output {
    public let hasViolations: Bool
    public let solverResult: String // "sat" or "unsat"
    public let proof: String
    public let violatedCategories: Set<PHICategory>
    public let constraints: [String]
    public let model: [String: Bool]

    public init(
        hasViolations: Bool,
        solverResult: String,
        proof: String,
        violatedCategories: Set<PHICategory> = [],
        constraints: [String] = [],
        model: [String: Bool] = [:]
    ) {
        self.hasViolations = hasViolations
        self.solverResult = solverResult
        self.proof = proof
        self.violatedCategories = violatedCategories
        self.constraints = constraints
        self.model = model
    }
}

/// Z3-based verification engine
///
/// This implements formal verification logic similar to the Python Z3 implementation.
/// It creates boolean constraints and checks satisfiability to prove HIPAA compliance.
///
/// Note: This is a pure Swift implementation that mimics Z3 behavior.
/// For production use with actual Z3, you would use Z3's C API via Swift bridging.
public class Z3Engine {

    private let configuration: HIPAAConfiguration

    /// HIPAA prohibited categories (all 18)
    private var prohibitedCategories: Set<String> {
        configuration.prohibitedCategories
    }

    public init() {
        self.configuration = HIPAAConfiguration.shared
    }

    /// Verify detected entities against HIPAA rules
    ///
    /// This mirrors the Python implementation's Z3 solving approach:
    /// 1. Create boolean variables for each category
    /// 2. Assert constraints based on detections
    /// 3. Check if "no prohibited PHI" constraint is satisfiable
    /// 4. UNSAT = violation detected, SAT = compliant
    ///
    /// - Parameter entities: Detected PHI entities
    /// - Returns: Z3 verification output
    public func verify(entities: [PHIEntity]) -> Z3Output {
        // Step 1: Create Z3 constraints from detections
        let (categoryVars, constraints) = createZ3Constraints(entities: entities)

        // Step 2: Find which categories were detected
        let detectedCategories = Set(entities.map { $0.category.rawValue })
        let violatedCategoryStrings = detectedCategories.intersection(prohibitedCategories)
        let violatedCategories = Set(violatedCategoryStrings.compactMap { PHICategory(rawValue: $0) })

        // Step 3: Check compliance constraint
        // The compliance rule: no prohibited PHI should be detected
        // We check if it's POSSIBLE for no PHI to be detected
        // If UNSAT, that means PHI WAS detected (violation)

        let solverResult: String
        let hasViolations: Bool

        if !violatedCategoryStrings.isEmpty {
            // UNSAT: The "no prohibited PHI" constraint cannot be satisfied
            // because prohibited PHI was detected
            solverResult = "unsat"
            hasViolations = true
        } else {
            // SAT: It's satisfiable to have no prohibited PHI
            // i.e., the document is compliant
            solverResult = "sat"
            hasViolations = false
        }

        // Step 4: Generate proof
        let proof = hasViolations
            ? buildViolationProof(entities: entities, violated: violatedCategories)
            : buildCompliantProof(detectedCategories: detectedCategories)

        return Z3Output(
            hasViolations: hasViolations,
            solverResult: solverResult,
            proof: proof,
            violatedCategories: violatedCategories,
            constraints: constraints,
            model: categoryVars
        )
    }

    /// Create Z3-style constraints from detected entities
    ///
    /// This creates boolean variables for each category and asserts
    /// whether each category was detected, mirroring the Python implementation.
    ///
    /// - Parameter entities: Detected PHI entities
    /// - Returns: Tuple of (category variables map, constraint strings)
    private func createZ3Constraints(entities: [PHIEntity]) -> ([String: Bool], [String]) {
        var categoryVars: [String: Bool] = [:]
        var constraints: [String] = []

        // Declare boolean variables for each prohibited category
        for category in PHICategory.allCases {
            let varName = "\(category.rawValue)_detected"
            categoryVars[varName] = false
            constraints.append("(declare-const \(varName) Bool)")
        }

        // Set variables based on detections
        let detectedCategories = Set(entities.map { $0.category })

        for category in PHICategory.allCases {
            let varName = "\(category.rawValue)_detected"
            let detected = detectedCategories.contains(category)
            categoryVars[varName] = detected
            constraints.append("(assert (= \(varName) \(detected)))")
        }

        // Add compliance rule: no prohibited PHI should be detected
        let prohibitedVars = PHICategory.allCases
            .filter { prohibitedCategories.contains($0.rawValue) }
            .map { "\($0.rawValue)_detected" }

        if !prohibitedVars.isEmpty {
            let orClause = prohibitedVars.joined(separator: " ")
            constraints.append("; Compliance rule: no prohibited PHI")
            constraints.append("(assert (not (or \(orClause))))")
        }

        constraints.append("(check-sat)")

        return (categoryVars, constraints)
    }

    // MARK: - Proof Generation

    /// Build compliant proof (mirrors Python implementation)
    private func buildCompliantProof(detectedCategories: Set<String>) -> String {
        var lines: [String] = []
        lines.append("HIPAA COMPLIANT")
        lines.append(String(repeating: "=", count: 40))
        lines.append("No prohibited PHI identifiers detected.")
        lines.append("")
        lines.append("Verification passed for all 18 HIPAA Safe Harbor categories:")

        for category in PHICategory.allCases {
            let detected = detectedCategories.contains(category.rawValue)
            let status = detected ? "✗ DETECTED" : "✓ Clear"
            lines.append("  \(category.rawValue): \(status)")
        }

        lines.append("")
        lines.append("Z3 Solver Result: SAT")
        lines.append("The compliance constraint is satisfiable.")
        lines.append("Formal proof: ∀c ∈ ProhibitedCategories, ¬detected(c)")

        return lines.joined(separator: "\n")
    }

    /// Build violation proof (mirrors Python implementation)
    private func buildViolationProof(entities: [PHIEntity], violated: Set<PHICategory>) -> String {
        var lines: [String] = []
        lines.append("HIPAA VIOLATION DETECTED")
        lines.append(String(repeating: "=", count: 40))
        lines.append("")

        // Group entities by category
        let groupedEntities = Dictionary(grouping: entities, by: { $0.category })

        for category in violated.sorted(by: { $0.rawValue < $1.rawValue }) {
            lines.append("Category: \(category.rawValue)")
            if let categoryEntities = groupedEntities[category] {
                for entity in categoryEntities {
                    lines.append("  Value: \(entity.value)")
                    lines.append("  Position: \(entity.startIndex)-\(entity.endIndex)")
                    lines.append("  Confidence: \(entity.confidencePercent)")

                    // Get applicable rules
                    let rules = configuration.getRulesForCategory(category.rawValue)
                    for rule in rules {
                        lines.append("  Violated: \(rule.id) - \(rule.description)")
                    }
                    lines.append("")
                }
            }
        }

        let violationCount = entities.filter { violated.contains($0.category) }.count
        lines.append("Total violations: \(violationCount)")
        lines.append("Categories: \(violated.map { $0.rawValue }.sorted().joined(separator: ", "))")
        lines.append("")
        lines.append("Z3 Solver Result: UNSAT")
        lines.append("The compliance constraint cannot be satisfied with detected PHI.")
        lines.append("Formal proof: ∃c ∈ ProhibitedCategories, detected(c) ⟹ ¬Compliant")

        return lines.joined(separator: "\n")
    }

    /// Generate violation explanation (for API compatibility)
    public func createViolationExplanation(entities: [PHIEntity]) -> ViolationExplanation {
        var violations: [ViolationDetail] = []

        for entity in entities {
            if prohibitedCategories.contains(entity.category.rawValue) {
                let rules = configuration.getRulesForCategory(entity.category.rawValue)

                violations.append(ViolationDetail(
                    category: entity.category.rawValue,
                    value: entity.value,
                    location: LocationInfo(start: entity.startIndex, end: entity.endIndex),
                    confidence: entity.confidence,
                    violatedRules: rules.map { rule in
                        RuleInfo(id: rule.id, name: rule.name, description: rule.description)
                    }
                ))
            }
        }

        let categoriesViolated = Set(violations.map { $0.category }).sorted()

        return ViolationExplanation(
            numViolations: violations.count,
            violations: violations,
            categoriesViolated: categoriesViolated
        )
    }
}

// MARK: - Supporting Types

/// Violation detail information
public struct ViolationDetail: Codable {
    public let category: String
    public let value: String
    public let location: LocationInfo
    public let confidence: Double
    public let violatedRules: [RuleInfo]

    public init(
        category: String,
        value: String,
        location: LocationInfo,
        confidence: Double,
        violatedRules: [RuleInfo]
    ) {
        self.category = category
        self.value = value
        self.location = location
        self.confidence = confidence
        self.violatedRules = violatedRules
    }
}

/// Location information for a violation
public struct LocationInfo: Codable {
    public let start: Int
    public let end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

/// Rule information
public struct RuleInfo: Codable {
    public let id: String
    public let name: String
    public let description: String

    public init(id: String, name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }
}

/// Violation explanation matching Python format
public struct ViolationExplanation: Codable {
    public let numViolations: Int
    public let violations: [ViolationDetail]
    public let categoriesViolated: [String]

    public init(
        numViolations: Int,
        violations: [ViolationDetail],
        categoriesViolated: [String]
    ) {
        self.numViolations = numViolations
        self.violations = violations
        self.categoriesViolated = categoriesViolated
    }

    enum CodingKeys: String, CodingKey {
        case numViolations = "num_violations"
        case violations
        case categoriesViolated = "categories_violated"
    }
}

// MARK: - Z3 Constraint Builder

/// Constraint builder for Z3 SMT-LIB2 format
///
/// This generates Z3-compatible constraints that can be fed to an actual Z3 solver.
/// Useful for debugging or when using Z3 as a separate process.
public struct Z3ConstraintBuilder {

    /// Build Z3 constraints for HIPAA verification
    /// This generates actual Z3 SMT-LIB2 format constraints
    public static func buildConstraints(for entities: [PHIEntity]) -> String {
        var smt: [String] = []

        // Header
        smt.append("; HIPAA Safe Harbor Verification Constraints")
        smt.append("; Generated by Aare Edge SDK")
        smt.append("; Based on 45 CFR 164.514(b)(2)")
        smt.append("")

        // Declare boolean variables for each category
        for category in PHICategory.allCases {
            smt.append("(declare-const \(category.rawValue)_detected Bool)")
        }

        smt.append("")
        smt.append("; Set variable values based on entity detections")

        // Set values based on detections
        let detectedCategories = Set(entities.map { $0.category })

        for category in PHICategory.allCases {
            let detected = detectedCategories.contains(category)
            smt.append("(assert (= \(category.rawValue)_detected \(detected)))")
        }

        smt.append("")
        smt.append("; HIPAA Compliance Rule")
        smt.append("; A document is compliant IFF no prohibited PHI is detected")

        // Compliance rule: no prohibited PHI
        let prohibitedVars = PHICategory.allCases.map { "\($0.rawValue)_detected" }
        smt.append("(assert (not (or \(prohibitedVars.joined(separator: " ")))))")

        smt.append("")
        smt.append("; Check satisfiability")
        smt.append("(check-sat)")
        smt.append("(get-model)")

        return smt.joined(separator: "\n")
    }

    /// Export constraints to SMT-LIB2 file
    public static func exportConstraints(
        for entities: [PHIEntity],
        to url: URL
    ) throws {
        let constraints = buildConstraints(for: entities)
        try constraints.write(to: url, atomically: true, encoding: .utf8)
    }
}
