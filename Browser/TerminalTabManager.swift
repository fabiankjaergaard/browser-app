import Foundation
import AppKit

class TerminalTabManager: ObservableObject {
    static let shared = TerminalTabManager()
    
    @Published var terminalTabs: [TerminalTab] = []
    @Published var activeTerminalTab: TerminalTab?
    
    private init() {}
    
    func createNewTerminalTab(title: String = "Terminal", workingDirectory: String = NSHomeDirectory()) -> TerminalTab {
        let newTab = TerminalTab(title: title, workingDirectory: workingDirectory)
        terminalTabs.append(newTab)
        setActiveTab(newTab)
        
        print("🆕 Created new terminal tab: \(newTab.title)")
        NotificationCenter.default.post(name: .terminalTabCreated, object: newTab)
        
        return newTab
    }
    
    func closeTerminalTab(_ tab: TerminalTab) {
        guard let index = terminalTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        
        terminalTabs.remove(at: index)
        print("🗑️ Closed terminal tab: \(tab.title)")
        
        // If closing the active tab, switch to another tab or close panel
        if activeTerminalTab?.id == tab.id {
            if !terminalTabs.isEmpty {
                // Switch to the next tab, or previous if we closed the last one
                let newIndex = min(index, terminalTabs.count - 1)
                setActiveTab(terminalTabs[newIndex])
            } else {
                // No more tabs, clear active tab
                activeTerminalTab = nil
                NotificationCenter.default.post(name: .allTerminalTabsClosed, object: nil)
            }
        }
        
        NotificationCenter.default.post(name: .terminalTabClosed, object: tab)
    }
    
    func setActiveTab(_ tab: TerminalTab) {
        // Deactivate current active tab
        activeTerminalTab?.isActive = false
        
        // Set new active tab
        activeTerminalTab = tab
        tab.isActive = true
        tab.updateLastAccessed()
        
        print("🎯 Switched to terminal tab: \(tab.title)")
        NotificationCenter.default.post(name: .terminalTabSelected, object: tab)
    }
    
    func getTabIndex(_ tab: TerminalTab) -> Int? {
        return terminalTabs.firstIndex(where: { $0.id == tab.id })
    }
    
    func hasAnyTabs() -> Bool {
        return !terminalTabs.isEmpty
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let terminalTabCreated = Notification.Name("TerminalTabCreated")
    static let terminalTabClosed = Notification.Name("TerminalTabClosed")
    static let terminalTabSelected = Notification.Name("TerminalTabSelected")
    static let allTerminalTabsClosed = Notification.Name("AllTerminalTabsClosed")
}