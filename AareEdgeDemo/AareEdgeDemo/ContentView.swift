import SwiftUI
import AareEdgeSDK

// MARK: - Sample Examples

enum SampleExample: String, CaseIterable, Identifiable {
    case none = "Select an example..."
    case medicalNote = "Medical Note"
    case prescription = "Prescription"
    case labReport = "Lab Report"
    case insuranceClaim = "Insurance Claim"
    case cleanText = "Clean Text (No PHI)"

    var id: String { rawValue }

    var content: String? {
        switch self {
        case .none:
            return nil
        case .medicalNote:
            return """
            Patient John Smith (DOB: 03/15/1985) was seen today.
            Contact: (617) 555-0123, john.smith@email.com
            SSN: 123-45-6789, MRN: A-12345678
            Address: 123 Main St, Boston, MA 02115
            """
        case .prescription:
            return """
            Prescription for Mary Johnson
            Date: December 16, 2024
            Phone: 617-555-0100
            Insurance ID: XYZ123456789
            """
        case .labReport:
            return """
            Lab Results for: Robert Williams
            DOB: 07/22/1978
            MRN: MR-987654
            SSN: 456-78-9012
            Fax results to: 555-867-5309
            """
        case .insuranceClaim:
            return """
            Claim submitted by: Sarah Davis
            Member ID: INS-2024-55443
            Provider: Dr. Michael Chen
            Patient Phone: (312) 555-8899
            Email: sarah.davis@email.com
            """
        case .cleanText:
            return """
            The patient presented with symptoms of seasonal allergies.
            Recommended over-the-counter antihistamines.
            Follow up in two weeks if symptoms persist.
            """
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = PHIDetectionViewModel()
    @State private var showHelp = false
    @State private var showDebug = false
    @State private var selectedExample: SampleExample = .none

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("HIPAA Compliance Check")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showHelp.toggle()
                        } label: {
                            Image(systemName: showHelp ? "questionmark.circle.fill" : "questionmark.circle")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showDebug.toggle()
                        } label: {
                            Image(systemName: showDebug ? "ladybug.fill" : "ladybug")
                        }
                    }
                }
                .sheet(isPresented: $showDebug) {
                    DebugLogView(log: viewModel.debugLog)
                }
        }
    }

    private var examplePicker: some View {
        HStack {
            Text("Try an example:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("Example", selection: $selectedExample) {
                ForEach(SampleExample.allCases) { example in
                    Text(example.rawValue).tag(example)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedExample) { newValue in
                if let content = newValue.content {
                    viewModel.inputText = content
                    viewModel.detectionResult = nil
                    viewModel.errorMessage = nil
                }
            }

            Spacer()

            if !viewModel.inputText.isEmpty {
                Button("Clear") {
                    viewModel.clear()
                    selectedExample = .none
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if showHelp {
                HelpBannerView(isShowing: $showHelp)
            }

            examplePicker

            TextEditor(text: $viewModel.inputText)
                .font(.body)
                .padding(8)
                .frame(minHeight: 150, maxHeight: 200)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .padding()

            Button {
                Task {
                    await viewModel.detectPHI()
                }
            } label: {
                HStack {
                    if viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 4)
                    }
                    Image(systemName: "shield.lefthalf.filled")
                    Text(viewModel.isProcessing ? "Scanning..." : "Scan for PHI")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isProcessing ? Color.gray : Color.blue)
                .cornerRadius(10)
            }
            .disabled(viewModel.isProcessing || viewModel.inputText.isEmpty)
            .padding(.horizontal)

            if viewModel.isProcessing {
                ProcessingStatusView(statusMessage: viewModel.statusMessage)
            }

            if let result = viewModel.detectionResult {
                ResultsView(result: result)
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error)
            } else if !viewModel.isProcessing {
                PlaceholderView()
            }

            Spacer()
        }
    }
}

// MARK: - Help Banner View

struct HelpBannerView: View {
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("About HIPAA PHI Detection")
                    .font(.headline)
                Spacer()
                Button(action: { isShowing = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            Text("This app detects Protected Health Information (PHI) as defined by HIPAA Safe Harbor guidelines. All processing happens on-device - your data never leaves your phone.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text("18 PHI Categories Detected:")
                .font(.caption)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(phiCategories, id: \.self) { category in
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var phiCategories: [String] {
        ["Name", "Location", "Date", "Phone", "Fax", "Email",
         "SSN", "MRN", "Health Plan", "Account", "License", "Vehicle",
         "Device ID", "URL", "IP Address", "Biometric", "Photo", "Other ID"]
    }
}

// MARK: - Processing Status View

struct ProcessingStatusView: View {
    let statusMessage: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .opacity(0.8)

            Text(statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGray6).opacity(0.5))
    }
}

struct ResultsView: View {
    let result: PHIDetectionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.containsPHI ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(result.containsPHI ? .orange : .green)
                Text(result.containsPHI ? "PHI Detected" : "No PHI Found")
                    .font(.headline)
                Spacer()
                Text("\(result.entities.count) entities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            if result.containsPHI {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(result.entities.enumerated()), id: \.offset) { _, entity in
                            EntityCard(entity: entity)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Text is safe for sharing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

struct EntityCard: View {
    let entity: PHIEntity

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entity.type)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForType(entity.type))
                Text(entity.text)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            Spacer()
            Text("[\(entity.startOffset)-\(entity.endOffset)]")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(colorForType(entity.type).opacity(0.1))
        .cornerRadius(8)
    }

    func colorForType(_ type: String) -> Color {
        switch type {
        case "NAME": return .blue
        case "SSN": return .red
        case "DATE": return .purple
        case "PHONE", "FAX": return .orange
        case "EMAIL": return .cyan
        case "LOCATION": return .green
        case "MRN": return .pink
        case "IP": return .indigo
        default: return .gray
        }
    }
}

struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Enter text above to scan for PHI")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Powered by on-device ML")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.octagon")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Error")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Debug Log View

struct DebugLogView: View {
    let log: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(log.isEmpty ? "No detection run yet.\n\nSelect an example and tap 'Scan for PHI' to see debug output." : log)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Debug Log")
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

#Preview {
    ContentView()
}
