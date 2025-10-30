import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct iOSApp4App: App {
    init() { FirebaseApp.configure() }
    var body: some Scene { WindowGroup { RootView() } }
}

/// Signs in anonymously, then shows the main UI.
struct RootView: View {
    @State private var uid: String?

    var body: some View {
        Group {
            if let uid {
                ContentView(uid: uid)
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Connecting to Firebase…")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .task {
                    if let u = Auth.auth().currentUser {
                        uid = u.uid
                    } else {
                        do {
                            let result = try await Auth.auth().signInAnonymously()
                            uid = result.user.uid
                        } catch {
                            print("Anon sign-in failed:", error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}
