import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct iOSApp4App: App {
    init() { FirebaseApp.configure() }
    var body: some Scene { WindowGroup { RootView() } }
}

/// Signs in anonymously once, then shows the app.
struct RootView: View {
    @State private var uid: String?

    var body: some View {
        Group {
            if let uid {
                ContentView(uid: uid)   // <-- pass the uid into your main view
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Connecting to Firebase…")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .task {
                    if let user = Auth.auth().currentUser {
                        uid = user.uid
                    } else {
                        do {
                            let result = try await Auth.auth().signInAnonymously()
                            uid = result.user.uid
                        } catch {
                            // In a real app, surface an error UI
                            print("Anon sign-in failed:", error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}
