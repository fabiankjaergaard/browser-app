import Cocoa
import WebKit

class FindInPageView: NSView {
    
    private var searchField: NSSearchField!
    private var previousButton: NSButton!
    private var nextButton: NSButton!
    private var closeButton: NSButton!
    private var resultLabel: NSTextField!
    
    weak var webView: WKWebView?
    private var currentSearchTerm: String = ""
    private var searchResultsCount: Int = 0
    private var currentResultIndex: Int = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        
        // Modern glassmorphism effect
        layer?.backgroundColor = ColorManager.glassMorphism.cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = ColorManager.primaryBorder.cgColor
        
        // Add subtle shadow and backdrop effect
        layer?.shadowColor = ColorManager.mediumShadow.cgColor
        layer?.shadowOffset = CGSize(width: 0, height: 4)
        layer?.shadowRadius = 12
        layer?.shadowOpacity = 1.0
        layer?.masksToBounds = false
        
        // Search field with modern styling
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Find in page"
        searchField.backgroundColor = ColorManager.tertiaryBackground
        searchField.textColor = ColorManager.primaryText
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.target = self
        searchField.action = #selector(searchTextChanged(_:))
        searchField.wantsLayer = true
        searchField.layer?.cornerRadius = 8
        searchField.layer?.borderWidth = 1
        searchField.layer?.borderColor = ColorManager.secondaryBorder.cgColor
        
        // Previous button with modern styling
        previousButton = NSButton(image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Previous")!, target: self, action: #selector(findPrevious))
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        previousButton.bezelStyle = .regularSquare
        previousButton.isBordered = false
        previousButton.contentTintColor = ColorManager.secondaryText
        previousButton.toolTip = "Previous result"
        previousButton.wantsLayer = true
        previousButton.layer?.cornerRadius = 6
        
        // Next button with modern styling
        nextButton = NSButton(image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Next")!, target: self, action: #selector(findNext))
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.bezelStyle = .regularSquare
        nextButton.isBordered = false
        nextButton.contentTintColor = ColorManager.secondaryText
        nextButton.toolTip = "Next result"
        nextButton.wantsLayer = true
        nextButton.layer?.cornerRadius = 6
        
        // Result label with modern styling
        resultLabel = NSTextField(labelWithString: "")
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.textColor = ColorManager.tertiaryText
        resultLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        resultLabel.alignment = .center
        
        // Close button with modern styling
        closeButton = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")!, target: self, action: #selector(closeFindBar))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .regularSquare
        closeButton.isBordered = false
        closeButton.contentTintColor = ColorManager.secondaryText
        closeButton.toolTip = "Close find bar"
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 6
        
        addSubview(searchField)
        addSubview(previousButton)
        addSubview(nextButton)
        addSubview(resultLabel)
        addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 200),
            
            previousButton.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 8),
            previousButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 24),
            
            nextButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 4),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 24),
            
            resultLabel.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 8),
            resultLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            resultLabel.widthAnchor.constraint(equalToConstant: 60),
            
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 24)
        ])
        
        // Initially disable navigation buttons
        updateNavigationButtons()
    }
    
    @objc private func searchTextChanged(_ sender: NSSearchField) {
        let searchTerm = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if searchTerm.isEmpty {
            clearSearch()
            return
        }
        
        currentSearchTerm = searchTerm
        performSearch()
    }
    
    @objc private func findPrevious() {
        guard !currentSearchTerm.isEmpty else { return }
        
        if currentResultIndex > 1 {
            currentResultIndex -= 1
        } else {
            currentResultIndex = searchResultsCount
        }
        
        highlightResult(at: currentResultIndex - 1)
        updateResultLabel()
    }
    
    @objc private func findNext() {
        guard !currentSearchTerm.isEmpty else { return }
        
        if currentResultIndex < searchResultsCount {
            currentResultIndex += 1
        } else {
            currentResultIndex = 1
        }
        
        highlightResult(at: currentResultIndex - 1)
        updateResultLabel()
    }
    
    @objc private func closeFindBar() {
        clearSearch()
        isHidden = true
        
        // Return focus to web view
        webView?.window?.makeFirstResponder(webView)
    }
    
    func showWithWebView(_ webView: WKWebView) {
        self.webView = webView
        isHidden = false
        searchField.becomeFirstResponder()
    }
    
    private func performSearch() {
        guard let webView = webView, !currentSearchTerm.isEmpty else { return }
        
        // Use WKWebView's built-in find functionality
        let searchScript = """
            window.find('\(currentSearchTerm)', false, false, true, false, true, false);
        """
        
        webView.evaluateJavaScript(searchScript) { [weak self] result, error in
            DispatchQueue.main.async {
                if error == nil {
                    self?.countSearchResults()
                }
            }
        }
    }
    
    private func countSearchResults() {
        guard let webView = webView else { return }
        
        let countScript = """
            (function() {
                var selection = window.getSelection();
                if (selection.rangeCount > 0) {
                    var range = selection.getRangeAt(0);
                    var searchTerm = '\(currentSearchTerm)';
                    var textContent = document.body.innerText || document.body.textContent || '';
                    var regex = new RegExp(searchTerm.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'), 'gi');
                    var matches = textContent.match(regex);
                    return matches ? matches.length : 0;
                }
                return 0;
            })();
        """
        
        webView.evaluateJavaScript(countScript) { [weak self] result, error in
            DispatchQueue.main.async {
                if let count = result as? Int {
                    self?.searchResultsCount = count
                    self?.currentResultIndex = count > 0 ? 1 : 0
                    self?.updateResultLabel()
                    self?.updateNavigationButtons()
                }
            }
        }
    }
    
    private func highlightResult(at index: Int) {
        guard let webView = webView, !currentSearchTerm.isEmpty else { return }
        
        // Clear previous highlights and highlight specific result
        let highlightScript = """
            (function() {
                var searchTerm = '\(currentSearchTerm)';
                var index = \(index);
                
                // Clear previous highlights
                window.find(searchTerm, false, false, true, false, true, false);
                
                // Find all matches and highlight the specific one
                var textNodes = [];
                var walker = document.createTreeWalker(
                    document.body,
                    NodeFilter.SHOW_TEXT,
                    null,
                    false
                );
                
                var node;
                while (node = walker.nextNode()) {
                    if (node.textContent.toLowerCase().includes(searchTerm.toLowerCase())) {
                        textNodes.push(node);
                    }
                }
                
                // Scroll to the result
                if (textNodes.length > index) {
                    textNodes[index].parentElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }
            })();
        """
        
        webView.evaluateJavaScript(highlightScript)
    }
    
    private func clearSearch() {
        guard let webView = webView else { return }
        
        currentSearchTerm = ""
        searchResultsCount = 0
        currentResultIndex = 0
        
        // Clear search highlights
        let clearScript = """
            if (window.getSelection) {
                window.getSelection().removeAllRanges();
            }
        """
        
        webView.evaluateJavaScript(clearScript)
        
        updateResultLabel()
        updateNavigationButtons()
    }
    
    private func updateResultLabel() {
        if searchResultsCount > 0 {
            resultLabel.stringValue = "\(currentResultIndex) of \(searchResultsCount)"
        } else if !currentSearchTerm.isEmpty {
            resultLabel.stringValue = "No results"
        } else {
            resultLabel.stringValue = ""
        }
    }
    
    private func updateNavigationButtons() {
        let hasResults = searchResultsCount > 0
        previousButton.isEnabled = hasResults
        nextButton.isEnabled = hasResults
        
        previousButton.contentTintColor = hasResults ? ColorManager.secondaryText : ColorManager.placeholderText
        nextButton.contentTintColor = hasResults ? ColorManager.secondaryText : ColorManager.placeholderText
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36: // Enter
            findNext()
        case 53: // Escape
            closeFindBar()
        default:
            super.keyDown(with: event)
        }
    }
}