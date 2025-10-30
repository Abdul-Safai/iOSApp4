import Foundation
import FirebaseDatabase
import FirebaseStorage
import UIKit

@MainActor
final class ItemStore: ObservableObject {
    @Published var items: [Item] = []
    @Published var uploadProgress: Double = 0
    @Published var isUploading: Bool = false
    @Published var errorMessage: String?

    private var handle: DatabaseHandle?
    private let uid: String

    init(uid: String) {
        self.uid = uid
        observeItems()
    }
    deinit {
        if let handle { FirebaseManager.itemsRef(uid: uid).removeObserver(withHandle: handle) }
    }

    // LIVE list from Realtime DB
    func observeItems() {
        handle = FirebaseManager.itemsRef(uid: uid)
            .queryOrdered(byChild: "createdAt")
            .observe(.value, with: { [weak self] snap in
                var list: [Item] = []
                for child in snap.children {
                    if let s = child as? DataSnapshot,
                       let dict = s.value as? [String: Any],
                       let item = Item.from(dict) { list.append(item) }
                }
                self?.items = list.sorted { $0.createdAt > $1.createdAt }
            }, withCancel: { [weak self] err in
                self?.errorMessage = err.localizedDescription
            })
    }

    // CRUD
    func add(title: String) {
        let it = Item(title: title)
        FirebaseManager.itemsRef(uid: uid).child(it.id).setValue(it.asDict)
    }
    func update(item: Item, newTitle: String) {
        FirebaseManager.itemsRef(uid: uid).child(item.id).updateChildValues(["title": newTitle])
    }
    func delete(item: Item) {
        FirebaseManager.itemsRef(uid: uid).child(item.id).removeValue()
        if let url = item.imageURL.flatMap(URL.init(string:)) {
            Storage.storage().reference(forURL: url.absoluteString).delete(completion: nil)
        }
    }

    // Upload image → Storage, then save download URL back to item
    func uploadImage(_ image: UIImage, for item: Item) {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            errorMessage = "Could not encode image."; return
        }
        isUploading = true; uploadProgress = 0

        let ref = FirebaseManager.itemImagesRef(uid: uid)
            .child("\(item.id)_\(UUID().uuidString).jpg")
        let meta = StorageMetadata(); meta.contentType = "image/jpeg"

        let task = ref.putData(data, metadata: meta)

        task.observe(.progress) { [weak self] s in
            if let frac = s.progress?.fractionCompleted {
                Task { @MainActor in self?.uploadProgress = frac }
            }
        }
        task.observe(.success) { [weak self] _ in
            ref.downloadURL { url, err in
                Task { @MainActor in
                    self?.isUploading = false; self?.uploadProgress = 1
                    if let u = url {
                        FirebaseManager.itemsRef(uid: self?.uid ?? "")
                            .child(item.id)
                            .updateChildValues(["imageURL": u.absoluteString])
                    } else if let err { self?.errorMessage = err.localizedDescription }
                }
            }
        }
        task.observe(.failure) { [weak self] s in
            Task { @MainActor in
                self?.isUploading = false
                self?.errorMessage = s.error?.localizedDescription ?? "Upload failed."
            }
        }
    }
}
