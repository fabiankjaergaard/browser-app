//
//  AppDelegate.swift
//  Browser
//
//  Created by Fabian Kjaergaard on 2025-07-24.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var windowController: BrowserWindowController!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Clear any window restoration data to prevent className issues
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame ")
        
        // Close any storyboard windows that might have opened
        NSApp.windows.forEach { window in
            if window.windowController != nil && !(window.windowController is BrowserWindowController) {
                window.close()
            }
        }
        
        windowController = BrowserWindowController()
        windowController.showWindow(nil)
        
        // Setup menu to override Command+T
        setupMenu()
    }
    
    private func setupMenu() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        // File menu with custom Command+T
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        
        // Override Command+T with our custom action
        let newTabItem = NSMenuItem(title: "Toggle Quick Search", action: #selector(toggleQuickSearch), keyEquivalent: "t")
        newTabItem.target = self
        fileMenu.addItem(newTabItem)
        
        // Edit menu 
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        // Find in page
        let findItem = NSMenuItem(title: "Find in Page", action: #selector(showFindInPage), keyEquivalent: "f")
        findItem.target = self
        editMenu.addItem(findItem)
        
        // View menu
        let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        
        // Toggle Sidebar
        let toggleSidebarItem = NSMenuItem(title: "Toggle Sidebar", action: #selector(toggleSidebar), keyEquivalent: "s")
        toggleSidebarItem.target = self
        viewMenu.addItem(toggleSidebarItem)
        
        // Toggle Terminal
        let toggleTerminalItem = NSMenuItem(title: "Toggle Terminal", action: #selector(toggleTerminal), keyEquivalent: "e")
        toggleTerminalItem.target = self
        viewMenu.addItem(toggleTerminalItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc private func toggleQuickSearch() {
        NotificationCenter.default.post(name: .showQuickSearch, object: nil)
    }
    
    @objc private func showFindInPage() {
        NotificationCenter.default.post(name: .showFindInPage, object: nil)
    }
    
    @objc private func toggleSidebar() {
        print("🎯 AppDelegate.toggleSidebar() called - posting notification")
        NotificationCenter.default.post(name: .toggleSidebar, object: nil)
    }
    
    @objc private func toggleTerminal() {
        NotificationCenter.default.post(name: .toggleTerminal, object: nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false  // Disable window restoration to prevent className issues
    }
    
    func application(_ application: NSApplication, willEncodeRestorableState coder: NSCoder) {
        // Prevent any restoration encoding
    }
    
    func application(_ application: NSApplication, didDecodeRestorableState coder: NSCoder) {
        // Prevent any restoration decoding
    }


}

