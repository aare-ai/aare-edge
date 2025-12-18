import SwiftUI
import AareEdgeSDK

struct ContentView: View {
    @StateObject private var viewModel = PHIDetectionViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input area
                TextEditor(text: $viewModel.inputText)
                    .font(.body)
                    .padding(8)
                    .frame(minHeight: 150, maxHeight: 200)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .padding()

                // Scan button
                Button(action: {
                    Task {
                        await viewModel.detectPHI()
                    }
                }) {
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

                // Results area
                if let result = viewModel.detectionResult {
                    ResultsView(result: result)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error)
                } else {
                    PlaceholderView()
                }

                Spacer()
            }
            .navigationTitle("Aare Edge")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sample: Medical Note") {
                            viewModel.inputText = """
                            Patient John Smith (DOB: 03/15/1985) was seen today.
                            Contact: (555) 123-4567, john.smith@email.com
                            SSN: 123-45-6789, MRN: A-12345678
                            Address: 123 Main St, Boston, MA 02115
                            """
                        }
                        Button("Sample: Prescription") {
                            viewModel.inputText = """
                            Prescription for Mary Johnson
                            Date: December 16, 2024
                            Phone: 617-555-0100
                            Insurance ID: XYZ123456789
                            """
                        }
                        Button("Sample: Clean Text") {
                            viewModel.inputText = """
                            The patient presented with symptoms of seasonal allergies.
                            Recommended over-the-counter antihistamines.
                            Follow up in two weeks if symptoms persist.
                            """
                        }
                        Divider()
                        Button("Clear", role: .destructive) {
                            viewModel.clear()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
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

#Preview {
    ContentView()
}
