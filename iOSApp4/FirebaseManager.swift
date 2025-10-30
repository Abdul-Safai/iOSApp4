import Foundation
import FirebaseDatabase
import FirebaseStorage

/// Per-user database & storage roots (secured by rules)
enum FirebaseManager {
    static func itemsRef(uid: String) -> DatabaseReference {
        Database.database().reference()
            .child("users").child(uid).child("items")
    }
    static func itemImagesRef(uid: String) -> StorageReference {
        Storage.storage().reference()
            .child("users").child(uid).child("item-images")
    }
}
