// Models.swift
import Foundation

struct Item: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var createdAt: TimeInterval
    var imageURL: String?

    init(id: String = UUID().uuidString,
         title: String,
         createdAt: TimeInterval = Date().timeIntervalSince1970,
         imageURL: String? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.imageURL = imageURL
    }

    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let createdAt = dict["createdAt"] as? TimeInterval else { return nil }
        self.id = id
        self.title = title
        self.createdAt = createdAt
        // Accept both spellings to be tolerant of existing data
        self.imageURL = (dict["imageURL"] as? String) ?? (dict["imageUrl"] as? String)
    }

    var asDict: [String: Any] {
        var d: [String: Any] = [
            "id": id,
            "title": title,
            "createdAt": createdAt
        ]
        if let imageURL { d["imageURL"] = imageURL }
        return d
    }
}
