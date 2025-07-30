import Foundation
import AppKit

class Bookmark: Identifiable, ObservableObject, Codable {
    let id = UUID()
    @Published var title: String
    @Published var url: URL
    @Published var favicon: NSImage?
    @Published var folder: BookmarkFolder?
    
    var createdAt: Date
    var lastVisitedAt: Date?
    
    init(title: String, url: URL, folder: BookmarkFolder? = nil) {
        self.title = title
        self.url = url
        self.folder = folder
        self.createdAt = Date()
    }
    
    func updateLastVisited() {
        self.lastVisitedAt = Date()
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, title, url, createdAt, lastVisitedAt, faviconData
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastVisitedAt, forKey: .lastVisitedAt)
        
        // Encode favicon as data if available
        if let favicon = favicon,
           let tiffData = favicon.tiffRepresentation,
           let bitmapImageRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImageRep.representation(using: .png, properties: [:]) {
            try container.encode(pngData, forKey: .faviconData)
        }
    }
    
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let title = try container.decode(String.self, forKey: .title)
        let url = try container.decode(URL.self, forKey: .url)
        
        self.init(title: title, url: url)
        
        // Decode other properties
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.lastVisitedAt = try container.decodeIfPresent(Date.self, forKey: .lastVisitedAt)
        
        // Decode favicon from data if available
        if let faviconData = try container.decodeIfPresent(Data.self, forKey: .faviconData) {
            self.favicon = NSImage(data: faviconData)
        }
    }
}

class BookmarkFolder: Identifiable, ObservableObject, Codable {
    let id = UUID()
    @Published var name: String
    @Published var bookmarks: [Bookmark] = []
    @Published var subfolders: [BookmarkFolder] = []
    
    init(name: String) {
        self.name = name
    }
    
    func addBookmark(_ bookmark: Bookmark) {
        bookmarks.append(bookmark)
        bookmark.folder = self
    }
    
    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, name, bookmarks, subfolders
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(bookmarks, forKey: .bookmarks)
        try container.encode(subfolders, forKey: .subfolders)
    }
    
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        self.init(name: name)
        
        // Decode other properties
        let bookmarks = try container.decode([Bookmark].self, forKey: .bookmarks)
        let subfolders = try container.decode([BookmarkFolder].self, forKey: .subfolders)
        
        self.bookmarks = bookmarks
        self.subfolders = subfolders
    }
}

// MARK: - Favorite Groups (Arc-style)
class FavoriteGroup: Identifiable, ObservableObject, Codable {
    let id = UUID()
    @Published var name: String
    @Published var iconName: String  // SF Symbol name
    @Published var bookmarks: [Bookmark] = []
    @Published var isExpanded: Bool = false
    @Published var color: String = "systemBlue"  // Color identifier
    
    init(name: String, iconName: String = "folder", color: String = "systemBlue") {
        self.name = name
        self.iconName = iconName
        self.color = color
    }
    
    func addBookmark(_ bookmark: Bookmark) {
        bookmarks.append(bookmark)
    }
    
    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, bookmarks, isExpanded, color
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(bookmarks, forKey: .bookmarks)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(color, forKey: .color)
    }
    
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let iconName = try container.decode(String.self, forKey: .iconName)
        let color = try container.decode(String.self, forKey: .color)
        
        self.init(name: name, iconName: iconName, color: color)
        
        // Decode other properties
        let bookmarks = try container.decode([Bookmark].self, forKey: .bookmarks)
        let isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        
        self.bookmarks = bookmarks
        self.isExpanded = isExpanded
    }
}