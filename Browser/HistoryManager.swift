import Foundation
import AppKit

struct HistoryItem: Identifiable, Codable {
    let id = UUID()
    let url: URL
    let title: String
    let visitedAt: Date
    var visitCount: Int = 1
    
    init(url: URL, title: String, visitedAt: Date = Date()) {
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
    }
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var historyItems: [HistoryItem] = []
    
    private let maxHistoryItems = 1000
    private let historyFileURL: URL
    
    private init() {
        // Create history file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        historyFileURL = documentsPath.appendingPathComponent("BrowserHistory.json")
        
        loadHistory()
    }
    
    func addHistoryItem(url: URL, title: String) {
        // Don't add private browsing URLs or localhost
        guard !url.absoluteString.contains("localhost"),
              !url.absoluteString.isEmpty,
              url.scheme == "http" || url.scheme == "https" else {
            return
        }
        
        // Check if URL already exists in recent history
        if let existingIndex = historyItems.firstIndex(where: { $0.url.absoluteString == url.absoluteString && 
                                                               Calendar.current.isDate($0.visitedAt, inSameDayAs: Date()) }) {
            // Update existing item
            historyItems[existingIndex].visitCount += 1
            historyItems[existingIndex] = HistoryItem(url: url, title: title, visitedAt: Date())
            historyItems.move(fromOffsets: IndexSet(integer: existingIndex), toOffset: 0)
        } else {
            // Add new item at the beginning
            let newItem = HistoryItem(url: url, title: title)
            historyItems.insert(newItem, at: 0)
        }
        
        // Limit history size
        if historyItems.count > maxHistoryItems {
            historyItems = Array(historyItems.prefix(maxHistoryItems))
        }
        
        saveHistory()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .historyUpdated, object: nil)
    }
    
    func clearHistory() {
        historyItems.removeAll()
        saveHistory()
        NotificationCenter.default.post(name: .historyUpdated, object: nil)
    }
    
    func removeHistoryItem(_ item: HistoryItem) {
        historyItems.removeAll { $0.id == item.id }
        saveHistory()
        NotificationCenter.default.post(name: .historyUpdated, object: nil)
    }
    
    func searchHistory(query: String) -> [HistoryItem] {
        guard !query.isEmpty else { return Array(historyItems.prefix(10)) }
        
        return historyItems.filter { item in
            item.title.lowercased().contains(query.lowercased()) ||
            item.url.absoluteString.lowercased().contains(query.lowercased())
        }
    }
    
    func getHistoryForDate(_ date: Date) -> [HistoryItem] {
        return historyItems.filter { Calendar.current.isDate($0.visitedAt, inSameDayAs: date) }
    }
    
    func getRecentItems(limit: Int = 10) -> [HistoryItem] {
        return Array(historyItems.prefix(limit))
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(historyItems)
            try data.write(to: historyFileURL)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: historyFileURL)
            historyItems = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
            historyItems = []
        }
    }
}

extension Notification.Name {
    static let historyUpdated = Notification.Name("HistoryUpdated")
}