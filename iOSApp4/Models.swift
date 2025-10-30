import Foundation

struct Item: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var createdAt: TimeInterval
    var imageURL: String?

    init(id: String = UUID().uuidString,
         title: String,
         createdAt: TimeInterval = Date().timeIntervalSince1970,
         imageURL: String? = nil) {
        self.id = id; self.title = title; self.createdAt = createdAt; self.imageURL = imageURL
    }

    var asDict: [String: Any] {
        ["id": id, "title": title, "createdAt": createdAt, "imageURL": imageURL as Any]
    }

    static func from(_ dict: [String: Any]) -> Item? {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let createdAt = dict["createdAt"] as? TimeInterval else { return nil }
        return Item(id: id, title: title, createdAt: createdAt, imageURL: dict["imageURL"] as? String)
    }
}
