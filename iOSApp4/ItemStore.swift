// ItemStore.swift
import SwiftUI
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage

// MARK: - AppItem model (renamed to avoid conflicts)
struct AppItem: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var createdAt: TimeInterval            // seconds since 1970
    var imageURL: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        createdAt: TimeInterval = Date().timeIntervalSince1970,
        imageURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.imageURL = imageURL
    }

    // Write to RTDB
    var asDict: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "createdAt": createdAt
        ]
        if let url = imageURL { dict["imageURL"] = url }
        return dict
    }

    // Read from RTDB
    init?(from dict: [String: Any]) {
        guard
            let id = dict["id"] as? String,
            let title = dict["title"] as? String,
            let createdAt = dict["createdAt"] as? TimeInterval
        else { return nil }
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.imageURL = dict["imageURL"] as? String
    }
}

extension AppItem {
    var createdAtFormatted: String {
        let d = Date(timeIntervalSince1970: createdAt)
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}

// MARK: - Store
@MainActor
final class ItemStore: ObservableObject {
    @Published var items: [AppItem] = []
    @Published var notice: String?
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0

    private var uid: String?
    private var baseRef: DatabaseReference? {
        uid.map { Database.database().reference().child("users").child($0).child("items") }
    }

    init() {
        Task { await ensureAuthAndStart() }
    }

    // MARK: - Auth & live sync
    private func ensureAuthAndStart() async {
        if Auth.auth().currentUser == nil {
            _ = try? await Auth.auth().signInAnonymously()
        }
        uid = Auth.auth().currentUser?.uid
        startListening()
    }

    private func startListening() {
        guard let ref = baseRef else {
            notice = "Waiting for Firebase sign-in…"
            return
        }

        ref.observe(.value) { [weak self] snap in
            var list: [AppItem] = []
            for child in snap.children {
                guard
                    let s = child as? DataSnapshot,
                    let dict = s.value as? [String: Any],
                    let item = AppItem(from: dict)
                else { continue }
                list.append(item)
            }
            DispatchQueue.main.async {
                self?.items = list.sorted { $0.createdAt > $1.createdAt }
                // Debug to confirm imageURL is being parsed
                if let first = list.first {
                    print("DEBUG AppItem.imageURL:", first.imageURL ?? "nil")
                }
            }
        }
    }

    // MARK: - CRUD
    func add(title: String) {
        guard let ref = baseRef else { return }
        let item = AppItem(title: title)
        ref.child(item.id).setValue(item.asDict)
    }

    func updateTitle(_ item: AppItem, to newTitle: String) {
        guard let ref = baseRef else { return }
        ref.child(item.id).updateChildValues(["title": newTitle])
    }

    func delete(_ item: AppItem) {
        baseRef?.child(item.id).removeValue()
    }

    // MARK: - Upload image (stable callback version)
    func attachImage(_ image: UIImage, to item: AppItem) {
        guard let uid = uid, let baseRef = baseRef else {
            notice = "No user signed in."
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            notice = "Image encoding failed."
            return
        }

        isUploading = true
        uploadProgress = 0
        notice = "Uploading image…"

        let filename = "\(UUID().uuidString).jpg"
        let storageRef = Storage.storage().reference()
            .child("users")
            .child(uid)
            .child("item-images")
            .child(filename)

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        // Start upload
        let uploadTask = storageRef.putData(data, metadata: meta) { [weak self] _, error in
            guard let self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.isUploading = false
                    self.notice = "Upload failed: \(error.localizedDescription)"
                }
                return
            }

            // Get download URL and save it into the item's node
            storageRef.downloadURL { url, err in
                if let err = err {
                    DispatchQueue.main.async {
                        self.isUploading = false
                        self.notice = "Failed to get URL: \(err.localizedDescription)"
                    }
                    return
                }

                guard let url = url else {
                    DispatchQueue.main.async {
                        self.isUploading = false
                        self.notice = "URL missing after upload."
                    }
                    return
                }

                baseRef.child(item.id).updateChildValues(["imageURL": url.absoluteString])

                DispatchQueue.main.async {
                    self.isUploading = false
                    self.uploadProgress = 1
                    self.notice = "Image uploaded successfully."
                }
            }
        }

        // Progress (explicit snapshot type fixes “cannot infer” errors)
        uploadTask.observe(.progress) { (snapshot: StorageTaskSnapshot) in
            if let p = snapshot.progress {
                DispatchQueue.main.async {
                    self.uploadProgress = Double(p.completedUnitCount) / Double(p.totalUnitCount)
                }
            }
        }
    }
}
