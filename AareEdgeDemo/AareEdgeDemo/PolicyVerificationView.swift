import SwiftUI
import AareEdgeSDK

struct PolicyVerificationView: View {
    @StateObject private var viewModel = PolicyVerificationViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Detection Result") {
                    if let result = viewModel.detectionResult {
                        HStack {
                            Text("PHI Count")
                            Spacer()
                            Text("\(result.entities.count)")
                                .fontWeight(.semibold)
                                .foregroundColor(result.containsPHI ? .red : .green)
                        }

                        ForEach(PHICategory.allCases, id: \.self) { category in
                            let count = result.entities.filter { $0.type == category.rawValue }.count
                            if count > 0 {
                                HStack {
                                    Text(category.rawValue)
                                        .font(.caption)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("No detection result")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Policy Rules") {
                    ForEach(viewModel.policies) { policy in
                        PolicyRuleRow(policy: policy, status: viewModel.policyStatus[policy.id])
                    }
                }

                Section {
                    Button("Run Policy Verification") {
                        viewModel.verifyPolicies()
                    }
                    .disabled(viewModel.detectionResult == nil)
                }

                if let summary = viewModel.verificationSummary {
                    Section("Verification Summary") {
                        HStack {
                            Image(systemName: summary.allPassed ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .foregroundColor(summary.allPassed ? .green : .red)
                            Text(summary.allPassed ? "All policies passed" : "\(summary.failedCount) policies violated")
                        }
                    }
                }
            }
            .navigationTitle("Policy Verification")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Sample Data") {
                        viewModel.loadSampleData()
                    }
                }
            }
        }
    }
}

struct PolicyRuleRow: View {
    let policy: PolicyRule
    let status: PolicyStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(policy.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let status = status {
                    Image(systemName: status.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(status.passed ? .green : .red)
                }
            }
            Text(policy.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
class PolicyVerificationViewModel: ObservableObject {
    @Published var detectionResult: PHIDetectionResult?
    @Published var policies: [PolicyRule] = PolicyRule.defaultPolicies
    @Published var policyStatus: [String: PolicyStatus] = [:]
    @Published var verificationSummary: VerificationSummary?

    private let solver = Z3Lite()

    func loadSampleData() {
        // Simulate a detection result
        detectionResult = PHIDetectionResult(
            text: "Sample text with PHI",
            entities: [
                PHIEntity(type: "NAME", text: "John Smith", startOffset: 0, endOffset: 10),
                PHIEntity(type: "SSN", text: "123-45-6789", startOffset: 20, endOffset: 31),
                PHIEntity(type: "DATE", text: "03/15/1985", startOffset: 40, endOffset: 50)
            ],
            tokenCount: 20
        )
    }

    func verifyPolicies() {
        guard let result = detectionResult else { return }

        policyStatus.removeAll()

        for policy in policies {
            let status = verifyPolicy(policy, with: result)
            policyStatus[policy.id] = status
        }

        let failedCount = policyStatus.values.filter { !$0.passed }.count
        verificationSummary = VerificationSummary(
            allPassed: failedCount == 0,
            failedCount: failedCount,
            totalCount: policies.count
        )
    }

    private func verifyPolicy(_ policy: PolicyRule, with result: PHIDetectionResult) -> PolicyStatus {
        solver.reset()

        let phiCount = solver.intVar("phi_count")
        let isPublic = solver.boolVar("is_public")

        // Bind actual values
        solver.bind("phi_count", to: .int(result.entities.count))
        solver.bind("is_public", to: .bool(policy.requiresNoData))

        // Build constraint based on policy type
        switch policy.type {
        case .noDataAllowed:
            // Policy: if public release, PHI count must be 0
            solver.assert(isPublic.implies(phiCount.eq(0)))

        case .maxEntitiesAllowed(let max):
            solver.assert(phiCount.lte(max))

        case .specificTypesProhibited(let types):
            let hasProhibitedType = result.entities.contains { types.contains($0.type) }
            let prohibited = solver.boolVar("has_prohibited")
            solver.bind("has_prohibited", to: .bool(hasProhibitedType))
            solver.assert(prohibited.not())
        }

        let checkResult = solver.check()

        return PolicyStatus(
            passed: checkResult.isSatisfiable,
            message: checkResult.isSatisfiable ? "Policy satisfied" : "Policy violated"
        )
    }
}

// MARK: - Models

struct PolicyRule: Identifiable {
    let id: String
    let name: String
    let description: String
    let type: PolicyType
    var requiresNoData: Bool = false

    static let defaultPolicies: [PolicyRule] = [
        PolicyRule(
            id: "public-release",
            name: "Public Release Policy",
            description: "No PHI allowed for public release",
            type: .noDataAllowed,
            requiresNoData: true
        ),
        PolicyRule(
            id: "max-entities",
            name: "Entity Limit Policy",
            description: "Maximum 5 PHI entities per document",
            type: .maxEntitiesAllowed(5)
        ),
        PolicyRule(
            id: "no-ssn",
            name: "SSN Prohibition",
            description: "Social Security Numbers are never allowed",
            type: .specificTypesProhibited(["SSN"])
        ),
        PolicyRule(
            id: "no-direct-ids",
            name: "Direct Identifiers Policy",
            description: "No names or SSNs allowed",
            type: .specificTypesProhibited(["NAME", "SSN", "MRN"])
        )
    ]
}

enum PolicyType {
    case noDataAllowed
    case maxEntitiesAllowed(Int)
    case specificTypesProhibited([String])
}

struct PolicyStatus {
    let passed: Bool
    let message: String
}

struct VerificationSummary {
    let allPassed: Bool
    let failedCount: Int
    let totalCount: Int
}

enum PHICategory: String, CaseIterable {
    case NAME, LOCATION, DATE, PHONE, FAX, EMAIL
    case SSN, MRN, HEALTH_PLAN, ACCOUNT, LICENSE
    case VEHICLE, DEVICE, URL, IP, BIOMETRIC, PHOTO, OTHER
}

#Preview {
    PolicyVerificationView()
}
