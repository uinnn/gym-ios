import SwiftUI

@main
struct GymApp: App {
    @State private var scanner = ScaleScanner()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(scanner)
        }
    }
}
