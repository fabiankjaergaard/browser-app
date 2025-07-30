import Foundation
import WebKit
import Cocoa
import AuthenticationServices

class Tab: NSObject, Identifiable, ObservableObject, WKNavigationDelegate {
    let id = UUID()
    @Published var title: String {
        didSet {
            NotificationCenter.default.post(name: .tabUpdated, object: self, userInfo: nil)
        }
    }
    @Published var url: URL?
    @Published var favicon: NSImage?
    @Published var isLoading: Bool = false
    @Published var isPinned: Bool = false
    @Published var webView: WKWebView
    @Published var isShowingNewTabPage: Bool = true
    
    var createdAt: Date
    var lastAccessedAt: Date
    var newTabViewController: NewTabViewController?
    
    init(title: String = "New Tab", url: URL? = nil) {
        self.title = title
        self.url = url
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        
        // Create WebView configuration
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        // Set modern user agent to get current Google interface (Updated for 2025)
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        
        // Enable modern web features and security
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true // Allow popups for OAuth
        
        // Enable modern web APIs needed for authentication
        if #available(macOS 11.0, *) {
            configuration.preferences.isElementFullscreenEnabled = true
        }
        
        // Allow secure contexts and modern authentication
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Configure media playback for better compatibility
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Set secure data store for authentication
        configuration.websiteDataStore.httpCookieStore.setCookiePolicy(.allow)
        
        // Inject CSS to force dark mode on websites (but avoid authentication pages)
        let darkModeScript = """
            // Skip dark mode injection on authentication/login pages
            const hostname = window.location.hostname;
            const pathname = window.location.pathname;
            const isAuthPage = hostname.includes('accounts.google.com') ||
                             hostname.includes('accounts.youtube.com') ||
                             pathname.includes('/auth') ||
                             pathname.includes('/login') ||
                             pathname.includes('/signin') ||
                             pathname.includes('/oauth');
            
            if (!isAuthPage) {
                document.documentElement.style.colorScheme = 'dark';
                const meta = document.createElement('meta');
                meta.name = 'color-scheme';
                meta.content = 'dark';
                if (document.getElementsByTagName('head')[0]) {
                    document.getElementsByTagName('head')[0].appendChild(meta);
                }
            }
        """
        
        let userScript = WKUserScript(source: darkModeScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(userScript)
        
        // Initialize WebView before calling super.init()
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        
        super.init()
        
        // Set navigation delegate for authentication handling
        self.webView.navigationDelegate = self
        
        // Set custom user agent for even better compatibility (Updated for 2025)
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        
        // Set appearance but allow authentication pages to use their preferred theme
        if #available(macOS 10.14, *) {
            // Don't force dark mode appearance as it can interfere with auth
            self.webView.underPageBackgroundColor = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        }
        
        if let url = url {
            self.webView.load(URLRequest(url: url))
            self.isShowingNewTabPage = false
        } else {
            // No URL provided, show new tab page
            self.isShowingNewTabPage = true
        }
    }
    
    func updateLastAccessed() {
        self.lastAccessedAt = Date()
    }
    
    func navigate(to url: URL) {
        self.url = url
        self.webView.load(URLRequest(url: url))
        self.isShowingNewTabPage = false
        updateLastAccessed()
        loadFavicon(from: url)
    }
    
    func loadFavicon(from url: URL) {
        guard let host = url.host else { return }
        
        // Try common favicon locations
        let faviconURLs = [
            URL(string: "https://\(host)/favicon.ico"),
            URL(string: "https://\(host)/favicon.png"),
            URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=16")
        ].compactMap { $0 }
        
        loadFaviconFromURLs(faviconURLs)
    }
    
    private func loadFaviconFromURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        let url = urls[0]
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, 
                  let image = NSImage(data: data),
                  error == nil else {
                // Try next URL if this one fails
                let remainingURLs = Array(urls.dropFirst())
                if !remainingURLs.isEmpty {
                    self?.loadFaviconFromURLs(remainingURLs)
                }
                return
            }
            
            DispatchQueue.main.async {
                image.size = NSSize(width: 16, height: 16)
                self?.favicon = image
                NotificationCenter.default.post(name: .tabUpdated, object: self, userInfo: nil)
            }
        }
        task.resume()
    }
    
    // MARK: - WKNavigationDelegate for Authentication Support
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        // Allow all navigation for authentication flows
        if let url = navigationAction.request.url {
            print("🔐 Navigation to: \(url.absoluteString)")
            
            // Special handling for authentication URLs
            if url.absoluteString.contains("accounts.google.com") ||
               url.absoluteString.contains("oauth") ||
               url.absoluteString.contains("signin") ||
               url.absoluteString.contains("login") ||
               url.absoluteString.contains("youtube.com") {
                print("🔑 Authentication URL detected - allowing navigation")
                
                // Ensure no appearance restrictions on auth pages
                DispatchQueue.main.async {
                    webView.appearance = nil
                }
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // Allow all responses for authentication flows
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ Navigation failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Update title when page loads
        webView.evaluateJavaScript("document.title") { [weak self] result, error in
            if let title = result as? String, !title.isEmpty {
                DispatchQueue.main.async {
                    self?.title = title
                    print("🏷️ Updating tab title to: \(title)")
                }
            }
        }
    }
}