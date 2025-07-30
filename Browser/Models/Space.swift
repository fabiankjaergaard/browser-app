import Foundation
import AppKit

class Space: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var color: NSColor
    @Published var icon: String
    @Published var tabs: [Tab] = []
    @Published var isActive: Bool = false
    
    var createdAt: Date
    
    init(name: String, color: NSColor = .systemBlue, icon: String = "square.stack.3d.up") {
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = Date()
    }
    
    func addTab(_ tab: Tab, at index: Int? = 0) {
        if let index = index, index <= tabs.count {
            tabs.insert(tab, at: index)
        } else {
            tabs.append(tab)
        }
    }
    
    func removeTab(_ tab: Tab) {
        tabs.removeAll { $0.id == tab.id }
    }
    
    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }
    
    func getActiveTab() -> Tab? {
        return tabs.first
    }
}