import Cocoa

protocol QuickSearchDelegate: AnyObject {
    func quickSearchDidCreateNewTab(with url: URL)
    func quickSearchDidCancel()
}

class QuickSearchViewController: NSViewController {
    
    weak var delegate: QuickSearchDelegate?
    
    private var overlayView: NSView!
    private var containerView: NSView!
    private var searchField: NSTextField!
    private var resultsScrollView: NSScrollView!
    private var resultsStackView: NSStackView!
    
    private var searchDebounceTimer: Timer?
    private var selectedIndex: Int = 0
    private var resultViews: [NSView] = []
    
    // Stable results management
    private var masterResultsPool: [StableSearchResult] = []
    private var currentQuery: String = ""
    private var popularSites: [(name: String, url: String, icon: String)] = [
        ("LinkedIn", "https://www.linkedin.com", "🔗"),
        ("Facebook", "https://www.facebook.com", "📘"),
        ("GitHub", "https://github.com", "🐱"),
        ("Netflix", "https://www.netflix.com", "🎬"),
        ("Twitter", "https://twitter.com", "🐦"),
        ("Instagram", "https://www.instagram.com", "📷"),
        ("Gmail", "https://mail.google.com", "📧")
    ]
    
    // Stable search result structure
    private struct StableSearchResult {
        let id: String
        let type: ResultType
        let title: String
        let subtitle: String
        let url: String
        let icon: NSImage?
        let action: () -> Void
        var isVisible: Bool = false
        var view: NSView?
        
        enum ResultType {
            case smartSuggestion
            case popularSite
            case googleSuggestion
            case sectionHeader
        }
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupOverlay()
        setupContainer()
        setupSearchField()
        setupResultsArea()
        updateResults()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        searchField.becomeFirstResponder()
    }
    
    private func setupOverlay() {
        overlayView = NSView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        
        // Add blur effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(visualEffectView)
        
        view.addSubview(overlayView)
        
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            visualEffectView.topAnchor.constraint(equalTo: overlayView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor)
        ])
    }
    
    private func setupContainer() {
        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.13, alpha: 0.95).cgColor
        containerView.layer?.cornerRadius = 16
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor(calibratedWhite: 0.3, alpha: 0.3).cgColor
        
        // Add shadow
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOffset = CGSize(width: 0, height: 8)
        containerView.layer?.shadowRadius = 20
        containerView.layer?.shadowOpacity = 0.3
        
        overlayView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -20),
            containerView.widthAnchor.constraint(equalToConstant: 600),
            containerView.heightAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    private func setupSearchField() {
        searchField = NSTextField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search or Enter URL..."
        searchField.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        searchField.textColor = NSColor.white
        searchField.backgroundColor = NSColor.clear
        searchField.isBordered = false
        searchField.focusRingType = .none
        searchField.delegate = self
        
        // Add search icon
        let searchIcon = NSImageView()
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = NSColor.secondaryLabelColor
        searchIcon.imageScaling = .scaleProportionallyDown
        
        containerView.addSubview(searchIcon)
        containerView.addSubview(searchField)
        
        NSLayoutConstraint.activate([
            searchIcon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            searchIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            searchIcon.widthAnchor.constraint(equalToConstant: 24),
            searchIcon.heightAnchor.constraint(equalToConstant: 24),
            
            searchField.centerYAnchor.constraint(equalTo: searchIcon.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            searchField.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupResultsArea() {
        resultsScrollView = NSScrollView()
        resultsScrollView.translatesAutoresizingMaskIntoConstraints = false
        resultsScrollView.hasVerticalScroller = true
        resultsScrollView.hasHorizontalScroller = false
        resultsScrollView.autohidesScrollers = true
        resultsScrollView.borderType = .noBorder
        resultsScrollView.drawsBackground = false
        
        resultsStackView = NSStackView()
        resultsStackView.translatesAutoresizingMaskIntoConstraints = false
        resultsStackView.orientation = .vertical
        resultsStackView.spacing = 2
        resultsStackView.alignment = .leading
        resultsStackView.distribution = .gravityAreas
        
        resultsScrollView.documentView = resultsStackView
        containerView.addSubview(resultsScrollView)
        
        NSLayoutConstraint.activate([
            resultsScrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 0),
            resultsScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            resultsScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            resultsScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            
            resultsStackView.topAnchor.constraint(equalTo: resultsScrollView.topAnchor),
            resultsStackView.leadingAnchor.constraint(equalTo: resultsScrollView.leadingAnchor),
            resultsStackView.trailingAnchor.constraint(equalTo: resultsScrollView.trailingAnchor),
            resultsStackView.widthAnchor.constraint(equalTo: resultsScrollView.widthAnchor)
        ])
    }
    
    // Shortcuts removed per user request
    
    // Shortcut button creation removed per user request
    
    
    private func updateResults() {
        let searchText = searchField.stringValue.lowercased()
        currentQuery = searchText
        
        // Initialize master pool if empty
        if masterResultsPool.isEmpty {
            initializeMasterResultsPool()
        }
        
        // Update visibility based on current search
        updateResultVisibility(for: searchText)
        
        // Add Google search suggestions with debounce (if needed)
        if !searchText.isEmpty && !isValidURL(searchText) {
            scheduleGoogleSuggestions(for: searchText)
        }
        
        // Apply changes to UI with smooth transitions
        applyStableResults()
        
        // Reset selection to first visible result
        selectedIndex = 0
        updateSelection()
    }
    
    // MARK: - Stable Results Management
    
    private func initializeMasterResultsPool() {
        masterResultsPool.removeAll()
        
        // Initialize smart suggestions for all possible queries
        let allSuggestions = getAllSmartSuggestions()
        for suggestion in allSuggestions {
            let result = StableSearchResult(
                id: "smart_\(suggestion.name.lowercased())",
                type: .smartSuggestion,
                title: suggestion.name,
                subtitle: suggestion.url,
                url: suggestion.url,
                icon: NSImage(systemSymbolName: "globe", accessibilityDescription: suggestion.name),
                action: { [weak self] in
                    if let url = URL(string: suggestion.url) {
                        self?.delegate?.quickSearchDidCreateNewTab(with: url)
                        self?.dismiss()
                    }
                }
            )
            masterResultsPool.append(result)
        }
        
        // Add popular sites header
        let popularHeader = StableSearchResult(
            id: "header_popular",
            type: .sectionHeader,
            title: "Popular Sites",
            subtitle: "",
            url: "",
            icon: nil,
            action: {}
        )
        masterResultsPool.append(popularHeader)
        
        // Initialize popular sites
        for (index, site) in popularSites.enumerated() {
            let result = StableSearchResult(
                id: "popular_\(index)",
                type: .popularSite,
                title: site.name,
                subtitle: site.url,
                url: site.url,
                icon: NSImage(systemSymbolName: "globe", accessibilityDescription: site.name),
                action: { [weak self] in
                    if let url = URL(string: site.url) {
                        self?.delegate?.quickSearchDidCreateNewTab(with: url)
                        self?.dismiss()
                    }
                }
            )
            masterResultsPool.append(result)
        }
    }
    
    private func getAllSmartSuggestions() -> [(name: String, url: String, icon: String)] {
        return [
            ("YouTube", "https://www.youtube.com", "📺"),
            ("Google", "https://www.google.com", "🔍"),
            ("GitHub", "https://github.com", "🐱"),
            ("Gmail", "https://mail.google.com", "📧"),
            ("Facebook", "https://www.facebook.com", "📘"),
            ("Twitter", "https://twitter.com", "🐦"),
            ("Instagram", "https://www.instagram.com", "📷"),
            ("LinkedIn", "https://www.linkedin.com", "🔗"),
            ("Netflix", "https://www.netflix.com", "🎬")
        ]
    }
    
    private func updateResultVisibility(for searchText: String) {
        let smartSuggestions = getSmartSuggestions(for: searchText)
        let hasSmartSuggestions = !smartSuggestions.isEmpty
        
        for index in 0..<masterResultsPool.count {
            var result = masterResultsPool[index]
            
            switch result.type {
            case .smartSuggestion:
                // Show if matches current search
                result.isVisible = smartSuggestions.contains { $0.name == result.title }
                
            case .sectionHeader:
                if result.id == "header_popular" {
                    // Show popular sites header only if search is empty and no smart suggestions
                    result.isVisible = searchText.isEmpty && !hasSmartSuggestions
                }
                
            case .popularSite:
                if searchText.isEmpty && !hasSmartSuggestions {
                    // Show all popular sites when search is empty
                    result.isVisible = true
                } else if !searchText.isEmpty {
                    // Filter popular sites by search text
                    result.isVisible = result.title.lowercased().contains(searchText)
                } else {
                    result.isVisible = false
                }
                
            case .googleSuggestion:
                // Google suggestions are handled separately with debounce
                break
            }
            
            masterResultsPool[index] = result
        }
    }
    
    private func scheduleGoogleSuggestions(for searchText: String) {
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.addGoogleSuggestionsToPool(for: searchText)
        }
    }
    
    private func addGoogleSuggestionsToPool(for searchText: String) {
        // Remove existing Google suggestions
        masterResultsPool.removeAll { $0.type == .googleSuggestion }
        
        let suggestions = generateSearchSuggestions(for: searchText)
        for (index, suggestion) in suggestions.enumerated() {
            let result = StableSearchResult(
                id: "google_\(index)_\(currentQuery)",
                type: .googleSuggestion,
                title: suggestion,
                subtitle: "Search on Google",
                url: "https://www.google.com/search?q=\(suggestion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                icon: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search"),
                action: { [weak self] in
                    let encodedQuery = suggestion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let searchURL = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
                        self?.delegate?.quickSearchDidCreateNewTab(with: searchURL)
                        self?.dismiss()
                    }
                },
                isVisible: true
            )
            masterResultsPool.append(result)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.applyStableResults()
        }
    }
    
    private func applyStableResults() {
        let visibleResults = masterResultsPool.filter { $0.isVisible }
        
        // Get current views in results stack
        let currentViews = resultsStackView.arrangedSubviews
        
        // Build new result views array
        resultViews.removeAll()
        
        for result in visibleResults {
            if let existingView = result.view {
                // View already exists - ensure it's in the correct position
                if !currentViews.contains(existingView) {
                    resultsStackView.addArrangedSubview(existingView)
                }
                resultViews.append(existingView)
            } else {
                // Create new view
                let newView = createStableResultView(for: result)
                
                // Update the result in the pool with the new view
                if let index = masterResultsPool.firstIndex(where: { $0.id == result.id }) {
                    masterResultsPool[index].view = newView
                }
                
                resultsStackView.addArrangedSubview(newView)
                resultViews.append(newView)
                
                // Fade in animation
                newView.alphaValue = 0
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    newView.animator().alphaValue = 1.0
                }
            }
        }
        
        // Remove views that should no longer be visible
        let visibleViewIDs = Set(visibleResults.map { $0.id })
        let viewsToRemove = currentViews.filter { view in
            guard let result = masterResultsPool.first(where: { $0.view === view }) else { return true }
            return !visibleViewIDs.contains(result.id)
        }
        
        for view in viewsToRemove {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                view.animator().alphaValue = 0.0
            }, completionHandler: {
                view.removeFromSuperview()
            })
        }
    }
    
    private func createStableResultView(for result: StableSearchResult) -> NSView {
        if result.type == .sectionHeader {
            return createSectionHeaderView(result.title)
        } else {
            return createResultView(
                icon: result.icon,
                title: result.title,
                subtitle: result.subtitle,
                actionText: nil,
                isSelected: false,
                action: result.action
            )
        }
    }
    
    private func createSectionHeaderView(_ title: String) -> NSView {
        let headerLabel = NSTextField(labelWithString: title)
        headerLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        headerLabel.textColor = NSColor.tertiaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let headerContainer = NSView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(headerLabel)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 8),
            headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -8),
            headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4),
            headerContainer.widthAnchor.constraint(equalToConstant: 576)
        ])
        
        return headerContainer
    }
    
    // Legacy methods kept for compatibility but now handled by stable system
    private func addSmartSuggestions(for searchText: String) {
        // Now handled by stable results system
    }
    
    private func getSmartSuggestions(for query: String) -> [(name: String, url: String, icon: String)] {
        let suggestions: [(name: String, url: String, icon: String, keywords: [String])] = [
            ("YouTube", "https://www.youtube.com", "📺", ["yo", "you", "yout", "youtu", "youtub", "youtube", "video", "videos"]),
            ("Google", "https://www.google.com", "🔍", ["go", "goo", "goog", "googl", "google", "search"]),
            ("GitHub", "https://github.com", "🐱", ["gi", "git", "gith", "githu", "github", "code", "repo"]),
            ("Gmail", "https://mail.google.com", "📧", ["gm", "gma", "gmai", "gmail", "mail", "email"]),
            ("Facebook", "https://www.facebook.com", "📘", ["fa", "fac", "face", "faceb", "faceboo", "facebook", "fb"]),
            ("Twitter", "https://twitter.com", "🐦", ["tw", "twi", "twit", "twitt", "twitte", "twitter"]),
            ("Instagram", "https://www.instagram.com", "📷", ["in", "ins", "inst", "insta", "instag", "instagr", "instagra", "instagram", "ig"]),
            ("LinkedIn", "https://www.linkedin.com", "🔗", ["li", "lin", "link", "linke", "linked", "linkedi", "linkedin"]),
            ("Netflix", "https://www.netflix.com", "🎬", ["ne", "net", "netf", "netfl", "netfli", "netflix", "movies", "shows"])
        ]
        
        return suggestions.compactMap { suggestion in
            // Check if any keyword starts with the query
            if suggestion.keywords.contains(where: { $0.hasPrefix(query) }) {
                return (suggestion.name, suggestion.url, suggestion.icon)
            }
            return nil
        }.sorted { first, second in
            // Special priority for YouTube - if query starts with "you", YouTube comes first
            if query.hasPrefix("you") {
                if first.name == "YouTube" { return true }
                if second.name == "YouTube" { return false }
            }
            
            // Special priority for exact "youtube" match
            if query == "youtube" {
                if first.name == "YouTube" { return true }
                if second.name == "YouTube" { return false }
            }
            
            // Find the best matching keywords for each suggestion
            let firstSuggestion = suggestions.first { $0.0 == first.name }
            let secondSuggestion = suggestions.first { $0.0 == second.name }
            
            let firstMatches = firstSuggestion?.keywords.filter { $0.hasPrefix(query) } ?? []
            let secondMatches = secondSuggestion?.keywords.filter { $0.hasPrefix(query) } ?? []
            
            let firstBestMatch = firstMatches.min(by: { $0.count < $1.count })
            let secondBestMatch = secondMatches.min(by: { $0.count < $1.count })
            
            // Prioritize exact matches first
            let firstExact = firstMatches.contains(query)
            let secondExact = secondMatches.contains(query)
            if firstExact != secondExact {
                return firstExact
            }
            
            // Then prioritize by how close the match is to the start of keywords
            if let firstMatch = firstBestMatch, let secondMatch = secondBestMatch {
                if firstMatch.count != secondMatch.count {
                    return firstMatch.count < secondMatch.count
                }
            }
            
            // Finally, alphabetical order
            return first.name < second.name
        }
    }
    
    private func hasSmartSuggestion(for query: String) -> Bool {
        return !getSmartSuggestions(for: query).isEmpty
    }
    
    // Legacy method - now handled by stable system
    private func addSmartSuggestionResult(_ suggestion: (name: String, url: String, icon: String), originalQuery: String) {
        // Now handled by stable results system
    }
    
    // Legacy method - now handled by stable system
    private func addSectionHeader(_ title: String) {
        // Now handled by stable results system
    }
    
    
    // Legacy method - now handled by stable system
    private func addSiteResult(_ site: (name: String, url: String, icon: String)) {
        // Now handled by stable results system
    }
    
    private func addSearchResult(_ searchText: String) {
        let searchURL = URL(string: "https://www.google.com/search?q=\(searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        let resultView = createResultView(
            icon: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search"),
            title: "Search for \"\(searchText)\"",
            subtitle: "google.com",
            actionText: nil,
            isSelected: false,
            action: { [weak self] in
                self?.delegate?.quickSearchDidCreateNewTab(with: searchURL)
                self?.dismiss()
            }
        )
        resultsStackView.addArrangedSubview(resultView)
        resultViews.append(resultView)
    }
    
    private func createResultView(icon: NSImage?, title: String, subtitle: String, actionText: String?, isSelected: Bool = false, action: @escaping () -> Void) -> NSView {
        let container = QuickSearchResultView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        
        // Set selection state
        if isSelected {
            container.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.4, blue: 1.0, alpha: 0.2).cgColor
        }
        
        // Set up click action
        container.onClick = action
        
        // Add hover effect with tracking area
        let trackingArea = NSTrackingArea(
            rect: NSRect(x: 0, y: 0, width: 576, height: 50),
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: container,
            userInfo: nil
        )
        container.addTrackingArea(trackingArea)
        
        // Icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyDown
        
        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(iconView)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        
        // Action button if provided
        var trailingAnchor = container.trailingAnchor
        if let actionText = actionText {
            let actionButton = NSButton(title: actionText, target: nil, action: nil)
            actionButton.translatesAutoresizingMaskIntoConstraints = false
            actionButton.bezelStyle = .rounded
            actionButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            actionButton.contentTintColor = NSColor.secondaryLabelColor
            container.addSubview(actionButton)
            
            NSLayoutConstraint.activate([
                actionButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                actionButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
            ])
            
            trailingAnchor = actionButton.leadingAnchor
        }
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            
            container.heightAnchor.constraint(equalToConstant: 50),
            container.widthAnchor.constraint(equalToConstant: 576)
        ])
        
        return container
    }
    
    
    private func isValidURL(_ string: String) -> Bool {
        // Check for common URL patterns
        if string.hasPrefix("http://") || string.hasPrefix("https://") {
            return true
        }
        
        // Check for domain-like strings (contains . and no spaces)
        if string.contains(".") && !string.contains(" ") {
            return true
        }
        
        // Check for popular sites that don't need .com
        let popularSiteNames = ["youtube", "google", "facebook", "github", "netflix", "twitter", "instagram", "gmail", "linkedin"]
        let lowercased = string.lowercased()
        
        for siteName in popularSiteNames {
            if lowercased == siteName {
                return true
            }
        }
        
        return false
    }
    
    // Legacy method - now handled by stable system
    private func fetchGoogleSuggestions(for query: String) {
        // Now handled by stable results system
    }
    
    private func generateSearchSuggestions(for query: String) -> [String] {
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common search patterns based on query length and content
        var suggestions: [String] = []
        
        if lowercaseQuery.count >= 2 {
            suggestions.append(contentsOf: [
                "\(lowercaseQuery) meaning",
                "\(lowercaseQuery) definition",
                "\(lowercaseQuery) how to",
                "\(lowercaseQuery) what is",
                "\(lowercaseQuery) examples"
            ])
        }
        
        // Add the original query as first suggestion
        suggestions.insert(lowercaseQuery, at: 0)
        
        return Array(suggestions.prefix(5))
    }
    
    // Legacy method - now handled by stable system
    private func addGoogleSuggestions(_ suggestions: [String], originalQuery: String) {
        // Now handled by stable results system
    }
    
    private func dismiss() {
        delegate?.quickSearchDidCancel()
    }
    
    // Shortcut actions removed per user request
    
    override func keyDown(with event: NSEvent) {
        // Handle Cmd+T to toggle/close quick search
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "t" {
            dismiss()
            return
        }
        
        switch event.keyCode {
        case 53: // ESC key
            dismiss()
        case 36: // Enter key
            executeSelectedResult()
        case 48: // Tab key
            executeSelectedResult()
        case 125: // Down arrow
            moveSelection(down: true)
        case 126: // Up arrow
            moveSelection(down: false)
        default:
            super.keyDown(with: event)
        }
    }
    
    private func executeSelectedResult() {
        guard selectedIndex < resultViews.count else { return }
        let selectedView = resultViews[selectedIndex]
        if let resultView = selectedView as? QuickSearchResultView {
            resultView.onClick?()
        }
    }
    
    private func moveSelection(down: Bool) {
        guard !resultViews.isEmpty else { return }
        
        if down {
            selectedIndex = min(selectedIndex + 1, resultViews.count - 1)
        } else {
            selectedIndex = max(selectedIndex - 1, 0)
        }
        
        updateSelection()
    }
    
    private func updateSelection() {
        // Remove selection from all views
        for (index, view) in resultViews.enumerated() {
            if let resultView = view as? QuickSearchResultView {
                if index == selectedIndex {
                    resultView.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.4, blue: 1.0, alpha: 0.2).cgColor
                    resultView.showTabIndicator = true
                } else {
                    resultView.layer?.backgroundColor = NSColor.clear.cgColor
                    resultView.showTabIndicator = false
                }
            }
        }
        
        // Scroll to make selected item visible
        if selectedIndex < resultViews.count {
            let selectedView = resultViews[selectedIndex]
            resultsScrollView.scrollToVisible(selectedView.frame)
        }
    }
    
    // Mouse event handlers for shortcuts removed per user request
}

extension QuickSearchViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        updateResults()
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Handle Enter key - execute selected result
            executeSelectedResult()
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            // Handle Down arrow
            moveSelection(down: true)
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            // Handle Up arrow
            moveSelection(down: false)
            return true
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
            // Handle Tab key
            executeSelectedResult()
            return true
        }
        return false
    }
}

// Custom view class for mouse tracking
class QuickSearchResultView: NSView {
    var onHover: ((Bool) -> Void)?
    var onClick: (() -> Void)?
    private var tabIndicatorView: NSView?
    
    var showTabIndicator: Bool = false {
        didSet {
            updateTabIndicator()
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
        if !showTabIndicator {
            self.layer?.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 0.3).cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        onHover?(false)
        if !showTabIndicator {
            self.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        onClick?()
    }
    
    private func updateTabIndicator() {
        // Remove existing indicator
        tabIndicatorView?.removeFromSuperview()
        
        if showTabIndicator {
            // Create tab indicator
            let indicator = NSView()
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.wantsLayer = true
            indicator.layer?.backgroundColor = NSColor.white.cgColor
            indicator.layer?.cornerRadius = 3
            
            // Add "Tab" label
            let label = NSTextField(labelWithString: "Tab")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            label.textColor = NSColor.black
            label.alignment = .center
            
            indicator.addSubview(label)
            addSubview(indicator)
            
            NSLayoutConstraint.activate([
                indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
                indicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
                indicator.widthAnchor.constraint(equalToConstant: 28),
                indicator.heightAnchor.constraint(equalToConstant: 18),
                
                label.centerXAnchor.constraint(equalTo: indicator.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: indicator.centerYAnchor)
            ])
            
            tabIndicatorView = indicator
        }
    }
}

// ShortcutButtonView class removed per user request

