import Foundation
import AppKit

class TerminalTab: ObservableObject, Identifiable, Hashable {
    let id = UUID()
    @Published var title: String
    @Published var isActive: Bool = false
    let createdAt: Date
    var lastAccessedAt: Date
    var ttydPort: Int?
    var workingDirectory: String
    
    init(title: String = "Terminal", workingDirectory: String = NSHomeDirectory()) {
        self.title = title
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.workingDirectory = workingDirectory
    }
    
    func updateLastAccessed() {
        lastAccessedAt = Date()
    }
    
    func updateTitle(_ newTitle: String) {
        title = newTitle
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        return lhs.id == rhs.id
    }
}