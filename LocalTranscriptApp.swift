import SwiftUI

@main
struct LocalTranscriptApp: App {
    @StateObject private var viewModel = TranscriptionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)

        Settings {
            EmptyView()
        }
    }
}
