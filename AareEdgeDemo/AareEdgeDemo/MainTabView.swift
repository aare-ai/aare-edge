import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Detect", systemImage: "shield.lefthalf.filled")
                }

            PolicyVerificationView()
                .tabItem {
                    Label("Verify", systemImage: "checkmark.shield")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
    }
}

struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Aare Edge SDK") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Model")
                        Spacer()
                        Text("DistilBERT NER")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Categories")
                        Spacer()
                        Text("18 HIPAA Safe Harbor")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Capabilities") {
                    FeatureRow(icon: "cpu", title: "On-Device ML", description: "All processing happens locally on your device")
                    FeatureRow(icon: "lock.shield", title: "Privacy First", description: "No data leaves your device")
                    FeatureRow(icon: "bolt", title: "Fast Inference", description: "Neural Engine acceleration when available")
                    FeatureRow(icon: "checkmark.seal", title: "Policy Verification", description: "Z3Lite constraint solving for compliance")
                }

                Section("PHI Categories Detected") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Names, Locations, Dates, Phone/Fax Numbers, Email Addresses, SSN, Medical Record Numbers, Health Plan IDs, Account Numbers, License/Certificate Numbers, Vehicle Identifiers, Device Identifiers, URLs, IP Addresses, Biometric IDs, Photos, Other Unique IDs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Link(destination: URL(string: "https://github.com/aare-ai")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("About")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainTabView()
}
