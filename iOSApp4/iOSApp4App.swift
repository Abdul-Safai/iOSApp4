import SwiftUI
import FirebaseCore

@main
struct iOSApp4App: App {
    init() {
        // Configure Firebase once (uses GoogleService-Info.plist in the app target)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure() // <-- no arguments
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView() // make sure your ContentView takes no parameters
        }
    }
}
