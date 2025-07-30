import Cocoa

class HistoryViewController: NSViewController {
    
    @IBOutlet weak var tableView: NSTableView!
    
    private var historyItems: [HistoryItem] = []
    private var searchField: NSSearchField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupSearchField()
        setupTableView()
        setupNotifications()
        loadHistory()
    }
    
    private func setupView() {
        title = "History"
        view.wantsLayer = true
        view.layer?.backgroundColor = ColorManager.primaryBackground.cgColor
        
        // Add subtle border pattern
        let borderLayer = CALayer()
        borderLayer.backgroundColor = ColorManager.primaryBorder.cgColor
        borderLayer.frame = CGRect(x: 0, y: 0, width: 2000, height: 1)
        view.layer?.addSublayer(borderLayer)
    }
    
    private func setupSearchField() {
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search history..."
        searchField.target = self
        searchField.action = #selector(searchHistory(_:))
        searchField.backgroundColor = ColorManager.tertiaryBackground
        searchField.textColor = ColorManager.primaryText
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.wantsLayer = true
        searchField.layer?.cornerRadius = 8
        searchField.layer?.borderWidth = 1
        searchField.layer?.borderColor = ColorManager.secondaryBorder.cgColor
        
        // Add subtle shadow for depth
        searchField.layer?.shadowColor = ColorManager.lightShadow.cgColor
        searchField.layer?.shadowOffset = CGSize(width: 0, height: 1)
        searchField.layer?.shadowRadius = 2
        searchField.layer?.shadowOpacity = 0.5
        
        view.addSubview(searchField)
        
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func setupTableView() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let tableViewInstance = NSTableView()
        tableView = tableViewInstance
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = NSColor.clear
        tableView.rowHeight = 48
        tableView.headerView = nil
        tableView.wantsLayer = true
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = true
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        
        // Create modern table styling
        tableView.gridStyleMask = []
        tableView.usesAlternatingRowBackgroundColors = false
        
        // Create columns
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Title"
        titleColumn.width = 300
        tableView.addTableColumn(titleColumn)
        
        let urlColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("url"))
        urlColumn.title = "URL"
        urlColumn.width = 200
        tableView.addTableColumn(urlColumn)
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Date"
        dateColumn.width = 120
        tableView.addTableColumn(dateColumn)
        
        scrollView.documentView = tableView
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyUpdated),
            name: .historyUpdated,
            object: nil
        )
    }
    
    @objc private func searchHistory(_ sender: NSSearchField) {
        let query = sender.stringValue
        historyItems = HistoryManager.shared.searchHistory(query: query)
        tableView.reloadData()
    }
    
    @objc private func historyUpdated() {
        loadHistory()
    }
    
    private func loadHistory() {
        historyItems = Array(HistoryManager.shared.historyItems.prefix(100)) // Show last 100 items
        
        // Sort by date (most recent first)
        historyItems.sort { $0.visitedAt > $1.visitedAt }
        
        tableView?.reloadData()
        
        // Scroll to top
        if !historyItems.isEmpty {
            tableView?.scrollRowToVisible(0)
        }
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }
}

// MARK: - NSTableViewDataSource
extension HistoryViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return historyItems.count
    }
}

// MARK: - NSTableViewDelegate
extension HistoryViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < historyItems.count else { return nil }
        
        let item = historyItems[row]
        let cellView = NSTableCellView()
        
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.textColor = ColorManager.primaryText
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.drawsBackground = false
        textField.isBordered = false
        textField.isEditable = false
        textField.isSelectable = false
        
        // Add modern cell background
        cellView.wantsLayer = true
        cellView.layer?.backgroundColor = row % 2 == 0 ? ColorManager.secondaryBackground.cgColor : ColorManager.primaryBackground.cgColor
        cellView.layer?.cornerRadius = 4
        
        // Add subtle hover effect
        let trackingArea = NSTrackingArea(
            rect: cellView.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: cellView,
            userInfo: nil
        )
        cellView.addTrackingArea(trackingArea)
        
        cellView.addSubview(textField)
        cellView.textField = textField
        
        NSLayoutConstraint.activate([
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8)
        ])
        
        switch tableColumn?.identifier.rawValue {
        case "title":
            // Add favicon to title column
            let faviconView = NSImageView()
            faviconView.translatesAutoresizingMaskIntoConstraints = false
            faviconView.imageScaling = .scaleProportionallyUpOrDown
            faviconView.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Website")
            faviconView.contentTintColor = ColorManager.tertiaryText
            
            cellView.addSubview(faviconView)
            
            NSLayoutConstraint.activate([
                faviconView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 12),
                faviconView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                faviconView.widthAnchor.constraint(equalToConstant: 16),
                faviconView.heightAnchor.constraint(equalToConstant: 16),
                
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                textField.leadingAnchor.constraint(equalTo: faviconView.trailingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8)
            ])
            
            textField.stringValue = item.title
            textField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            textField.textColor = ColorManager.primaryText
            return cellView
            
        case "url":
            textField.stringValue = item.url.absoluteString
            textField.textColor = ColorManager.secondaryText
            textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        case "date":
            let formatter = DateFormatter()
            let calendar = Calendar.current
            
            if calendar.isDateInToday(item.visitedAt) {
                formatter.dateFormat = "HH:mm"
                textField.stringValue = "Today " + formatter.string(from: item.visitedAt)
            } else if calendar.isDateInYesterday(item.visitedAt) {
                formatter.dateFormat = "HH:mm"
                textField.stringValue = "Yesterday " + formatter.string(from: item.visitedAt)
            } else {
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                textField.stringValue = formatter.string(from: item.visitedAt)
            }
            
            textField.textColor = ColorManager.tertiaryText
            textField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        default:
            break
        }
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < historyItems.count else { return }
        
        let item = historyItems[selectedRow]
        
        // Navigate to selected URL in current tab
        if let currentTab = TabManager.shared.activeTab {
            currentTab.navigate(to: item.url)
        }
        
        // Close history view
        dismiss(nil)
    }
}