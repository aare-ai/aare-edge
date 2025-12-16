// ContentView - Main app screen

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: VerificationViewModel
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Toggle
                ModeToggleView()

                // Main Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Input Section
                        InputSection()

                        // Action Buttons
                        ActionButtons()

                        // Results Section
                        if viewModel.hasResult {
                            ResultsView()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Aare Core")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

// MARK: - Mode Toggle

struct ModeToggleView: View {
    @EnvironmentObject var viewModel: VerificationViewModel

    var body: some View {
        HStack {
            ForEach(VerificationMode.allCases, id: \.self) { mode in
                Button {
                    viewModel.mode = mode
                } label: {
                    HStack {
                        Image(systemName: mode.icon)
                        Text(mode.title)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(viewModel.mode == mode ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(viewModel.mode == mode ? .white : .primary)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Input Section

struct InputSection: View {
    @EnvironmentObject var viewModel: VerificationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clinical Note")
                .font(.headline)

            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text("\(viewModel.inputText.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Action Buttons

struct ActionButtons: View {
    @EnvironmentObject var viewModel: VerificationViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.generateMockNote()
            } label: {
                Label("Generate Mock", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                Task {
                    await viewModel.verify()
                }
            } label: {
                Label(viewModel.isVerifying ? "Verifying..." : "Verify", systemImage: "checkmark.shield")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.inputText.isEmpty || viewModel.isVerifying)
        }
    }
}

// MARK: - Results View

struct ResultsView: View {
    @EnvironmentObject var viewModel: VerificationViewModel
    @State private var showProof = false

    var body: some View {
        if let result = viewModel.result {
            VStack(alignment: .leading, spacing: 16) {
                // Status Banner
                StatusBanner(status: result.status)

                // Detected Entities
                if !result.entities.isEmpty {
                    EntitiesSection(entities: result.entities)
                }

                // Proof Section
                DisclosureGroup("Verification Proof", isExpanded: $showProof) {
                    Text(result.proof)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }

                // Metadata
                MetadataSection(metadata: result.metadata)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
}

// MARK: - Status Banner

struct StatusBanner: View {
    let status: ComplianceStatus

    var body: some View {
        HStack {
            Image(systemName: status == .compliant ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title)

            VStack(alignment: .leading) {
                Text(status.description)
                    .font(.headline)
                Text(status == .compliant ? "No PHI detected" : "PHI entities found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .foregroundColor(statusColor)
        .cornerRadius(8)
    }

    var statusColor: Color {
        switch status {
        case .compliant: return .green
        case .violation: return .red
        case .error: return .orange
        }
    }
}

// MARK: - Entities Section

struct EntitiesSection: View {
    let entities: [PHIEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected PHI (\(entities.count))")
                .font(.headline)

            ForEach(entities) { entity in
                HStack {
                    Image(systemName: categoryIcon(for: entity.category))
                        .foregroundColor(.red)

                    VStack(alignment: .leading) {
                        Text(entity.category.description)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(entity.value)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(entity.confidencePercent)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.vertical, 4)
            }
        }
    }

    func categoryIcon(for category: PHICategory) -> String {
        switch category {
        case .names: return "person.fill"
        case .dates: return "calendar"
        case .phoneNumbers, .faxNumbers: return "phone.fill"
        case .emailAddresses: return "envelope.fill"
        case .ssn: return "number"
        case .medicalRecordNumbers: return "doc.text.fill"
        case .ipAddresses: return "network"
        case .webUrls: return "globe"
        default: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Metadata Section

struct MetadataSection: View {
    let metadata: VerificationMetadata

    var body: some View {
        HStack {
            Label(metadata.isEdge ? "Edge" : "Cloud", systemImage: metadata.isEdge ? "iphone" : "cloud")

            Spacer()

            if let latency = metadata.latencyMs {
                Text(String(format: "%.0f ms", latency))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let version = metadata.modelVersion {
                Text("v\(version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
        .padding(.top, 8)
    }
}

#Preview {
    ContentView()
        .environmentObject(VerificationViewModel())
}
