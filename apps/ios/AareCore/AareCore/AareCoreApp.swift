// AareCore - HIPAA Verification Reference App
// Demonstrates the Aare Edge SDK

import SwiftUI

@main
struct AareCoreApp: App {
    @StateObject private var viewModel = VerificationViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
