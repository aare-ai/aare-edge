// SettingsView - App configuration

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: VerificationViewModel
    @Environment(\.dismiss) var dismiss
    @State private var apiEndpoint: String = "https://api.aare.ai/v1/verify"
    @State private var confidenceThreshold: Double = 0.5

    var body: some View {
        NavigationStack {
            Form {
                // Mode Section
                Section {
                    Picker("Verification Mode", selection: $viewModel.mode) {
                        ForEach(VerificationMode.allCases, id: \.self) { mode in
                            Label(mode.title, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                } header: {
                    Text("Mode")
                } footer: {
                    Text(viewModel.mode == .edge ?
                         "All processing happens on-device. No data is sent to the cloud." :
                         "Text is sent to the Aare API for verification.")
                }

                // Edge Settings
                if viewModel.mode == .edge {
                    Section("Edge Settings") {
                        HStack {
                            Text("Confidence Threshold")
                            Spacer()
                            Text(String(format: "%.0f%%", confidenceThreshold * 100))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $confidenceThreshold, in: 0.1...0.9, step: 0.1)

                        HStack {
                            Text("Model Status")
                            Spacer()
                            Text(viewModel.isModelLoaded ? "Loaded" : "Not Loaded")
                                .foregroundColor(viewModel.isModelLoaded ? .green : .orange)
                        }

                        if !viewModel.isModelLoaded {
                            Button("Load Model") {
                                Task {
                                    await viewModel.loadModel()
                                }
                            }
                        }
                    }
                }

                // Cloud Settings
                if viewModel.mode == .cloud {
                    Section("Cloud Settings") {
                        TextField("API Endpoint", text: $apiEndpoint)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("SDK Version")
                        Spacer()
                        Text("0.1.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("HIPAA Categories")
                        Spacer()
                        Text("18")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/your-org/aare-edge")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }

                    Link(destination: URL(string: "https://aare.ai/docs")!) {
                        HStack {
                            Text("Documentation")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                }

                // Privacy Section
                Section {
                    NavigationLink {
                        PrivacyNoticeView()
                    } label: {
                        Text("Privacy Notice")
                    }

                    Toggle("Analytics (Anonymous)", isOn: .constant(false))
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Aare Edge processes all data on-device by default. No PHI is ever sent to our servers.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Privacy Notice

struct PrivacyNoticeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Notice")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Last updated: December 2024")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Group {
                    Text("On-Device Processing")
                        .font(.headline)

                    Text("""
                    Aare Edge performs all PHI detection and HIPAA verification directly on your device. \
                    Your clinical notes and sensitive data never leave your device when using Edge mode.
                    """)

                    Text("Data Collection")
                        .font(.headline)

                    Text("""
                    When using Edge mode, we do not collect any of your data. Optional anonymous analytics \
                    (disabled by default) only tracks aggregate usage metrics like verification count and \
                    average latency—never any PHI or document content.
                    """)

                    Text("Cloud Mode")
                        .font(.headline)

                    Text("""
                    When using Cloud mode, your text is sent to our secure API endpoint for verification. \
                    We do not store your data beyond the time needed to process the request. All \
                    transmissions are encrypted using TLS 1.3.
                    """)

                    Text("HIPAA Compliance")
                        .font(.headline)

                    Text("""
                    Aare Edge is designed to help you identify PHI in clinical notes. However, this tool \
                    is for assistance only and should not be used as the sole method of de-identification. \
                    Always follow your organization's HIPAA compliance procedures.
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environmentObject(VerificationViewModel())
}
