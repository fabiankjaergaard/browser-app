import Foundation
import AppKit

class TabManager: ObservableObject {
    static let shared = TabManager()
    
    @Published var spaces: [Space] = []
    @Published var activeSpace: Space?
    @Published var activeTab: Tab?
    @Published var looseTabs: [Tab] = []  // Tabs not in any space
    
    private init() {
        createDefaultSpace()
    }
    
    private func createDefaultSpace() {
        let defaultSpace = Space(name: "Personal", color: .systemBlue)
        spaces.append(defaultSpace)
        activeSpace = defaultSpace
        
        // Don't create a tab automatically - show blank start page instead
    }
    
    func createNewTab(in space: Space? = nil, with url: URL? = nil) {
        let newTab = Tab(url: url)
        
        if let targetSpace = space {
            // If specific space is provided, add to that space
            print("🆕 Creating new tab in space: \(targetSpace.name)")
            targetSpace.addTab(newTab)
        } else {
            // If no space specified, add as loose tab (not in any space)
            print("🆕 Creating new loose tab")
            looseTabs.insert(newTab, at: 0)
        }
        
        activeTab = newTab
        
        NotificationCenter.default.post(name: .tabCreated, object: newTab)
        NotificationCenter.default.post(name: .tabSelected, object: newTab)
    }
    
    func closeTab(_ tab: Tab, in space: Space? = nil) {
        print("🗑️ Closing tab: \(tab.title)")
        // Check if it's a loose tab first
        if let looseTabIndex = looseTabs.firstIndex(where: { $0.id == tab.id }) {
            print("🗑️ Found loose tab at index \(looseTabIndex)")
            looseTabs.remove(at: looseTabIndex)
            
            if activeTab?.id == tab.id {
                if !looseTabs.isEmpty {
                    let newIndex = min(looseTabIndex, looseTabs.count - 1)
                    activeTab = looseTabs[newIndex]
                    NotificationCenter.default.post(name: .tabSelected, object: activeTab!)
                } else {
                    // If no loose tabs left, show blank start page
                    print("📺 No loose tabs left - showing blank start page")
                    activeTab = nil
                    NotificationCenter.default.post(name: .allTabsClosed, object: nil)
                }
            }
        } else {
            // Handle space tabs
            let targetSpace = space ?? spaces.first(where: { $0.tabs.contains(where: { $0.id == tab.id }) })
            
            guard let space = targetSpace else { return }
            
            let tabIndex = space.tabs.firstIndex(where: { $0.id == tab.id })
            space.removeTab(tab)
            
            if activeTab?.id == tab.id {
                if let index = tabIndex {
                    if space.tabs.count > 0 {
                        let newIndex = min(index, space.tabs.count - 1)
                        activeTab = space.tabs[newIndex]
                        NotificationCenter.default.post(name: .tabSelected, object: activeTab!)
                    } else {
                        // Check if there are any tabs left in any space or as loose tabs
                        let totalTabs = spaces.flatMap { $0.tabs }.count + looseTabs.count
                        print("🔍 Total tabs remaining: \(totalTabs) (spaces: \(spaces.flatMap { $0.tabs }.count), loose: \(looseTabs.count))")
                        if totalTabs == 0 {
                            print("📺 No tabs left - showing blank start page")
                            activeTab = nil
                            NotificationCenter.default.post(name: .allTabsClosed, object: nil)
                        } else {
                            // Find another tab to switch to
                            if let otherTab = looseTabs.first ?? spaces.first(where: { !$0.tabs.isEmpty })?.tabs.first {
                                print("🔄 Switching to another tab: \(otherTab.title)")
                                switchToTab(otherTab)
                            }
                        }
                    }
                }
            }
        }
        
        NotificationCenter.default.post(name: .tabClosed, object: tab)
    }
    
    func switchToTab(_ tab: Tab) {
        activeTab = tab
        tab.updateLastAccessed()
        
        // Check if it's a loose tab or in a space
        if looseTabs.contains(where: { $0.id == tab.id }) {
            // It's a loose tab, no space association
            activeSpace = nil
        } else if let space = spaces.first(where: { $0.tabs.contains(where: { $0.id == tab.id }) }) {
            activeSpace = space
        }
        
        NotificationCenter.default.post(name: .tabSelected, object: tab)
    }
    
    func createSpace(name: String, color: NSColor = .systemBlue) {
        let newSpace = Space(name: name, color: color)
        spaces.append(newSpace)
        
        NotificationCenter.default.post(name: .spaceCreated, object: newSpace)
    }
    
    func switchToSpace(_ space: Space) {
        activeSpace = space
        spaces.forEach { $0.isActive = false }
        space.isActive = true
        
        if let firstTab = space.tabs.first {
            switchToTab(firstTab)
        } else {
            createNewTab(in: space)
        }
        
        NotificationCenter.default.post(name: .spaceChanged, object: space)
    }
    
    func moveTab(_ tab: Tab, from sourceSpace: Space, to destinationSpace: Space) {
        sourceSpace.removeTab(tab)
        destinationSpace.addTab(tab, at: 0)  // Add moved tabs at the beginning too
        
        NotificationCenter.default.post(name: .tabMoved, object: tab)
    }
}

extension Notification.Name {
    static let tabCreated = Notification.Name("TabCreated")
    static let tabClosed = Notification.Name("TabClosed")
    static let tabMoved = Notification.Name("TabMoved")
    static let spaceCreated = Notification.Name("SpaceCreated")
    static let spaceChanged = Notification.Name("SpaceChanged")
    static let allTabsClosed = Notification.Name("AllTabsClosed")
}