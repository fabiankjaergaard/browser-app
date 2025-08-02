import Foundation
import WebKit
import Cocoa
import AuthenticationServices
import UniformTypeIdentifiers

class Tab: NSObject, Identifiable, ObservableObject, WKNavigationDelegate, WKDownloadDelegate, WKUIDelegate, WKScriptMessageHandler {
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
        
        // Add context menu download script
        let contextMenuScript = """
            // Enhanced right-click downloads with custom menu
            let rightClickedElement = null;
            let customMenu = null;
            
            document.addEventListener('contextmenu', function(e) {
                rightClickedElement = e.target;
                let downloadUrl = null;
                let isImage = false;
                
                // Check if it's an image
                if (e.target.tagName === 'IMG') {
                    downloadUrl = e.target.src;
                    isImage = true;
                } 
                // Check if it's a link
                else if (e.target.tagName === 'A' && e.target.href) {
                    downloadUrl = e.target.href;
                }
                // Check if parent is a link
                else if (e.target.parentElement && e.target.parentElement.tagName === 'A') {
                    downloadUrl = e.target.parentElement.href;
                }
                
                if (downloadUrl) {
                    // Prevent default context menu
                    e.preventDefault();
                    
                    // Create custom context menu
                    createCustomContextMenu(e.pageX, e.pageY, downloadUrl, isImage);
                }
            });
            
            function createCustomContextMenu(x, y, url, isImage) {
                // Remove existing menu
                if (customMenu) {
                    customMenu.remove();
                }
                
                // Create menu container
                customMenu = document.createElement('div');
                customMenu.style.position = 'absolute';
                customMenu.style.left = x + 'px';
                customMenu.style.top = y + 'px';
                customMenu.style.backgroundColor = 'rgba(40, 40, 40, 0.95)';
                customMenu.style.border = '1px solid rgba(255, 255, 255, 0.2)';
                customMenu.style.borderRadius = '8px';
                customMenu.style.padding = '8px 0';
                customMenu.style.minWidth = '200px';
                customMenu.style.fontSize = '14px';
                customMenu.style.fontFamily = '-apple-system, BlinkMacSystemFont, sans-serif';
                customMenu.style.color = 'white';
                customMenu.style.zIndex = '10000';
                customMenu.style.boxShadow = '0 4px 20px rgba(0, 0, 0, 0.3)';
                customMenu.style.backdropFilter = 'blur(20px)';
                
                // Add menu items
                if (isImage) {
                    addMenuItem('Open Image in New Tab', function() {
                        window.open(url, '_blank');
                        removeMenu();
                    });
                    
                    addMenuItem('Download Image', function() {
                        webkit.messageHandlers.downloadHandler.postMessage(url);
                        removeMenu();
                    });
                    
                    addMenuItem('Copy Image', function() {
                        // This would copy the image URL for now
                        navigator.clipboard.writeText(url);
                        removeMenu();
                    });
                } else {
                    addMenuItem('Open Link', function() {
                        window.location.href = url;
                        removeMenu();
                    });
                    
                    addMenuItem('Open Link in New Tab', function() {
                        window.open(url, '_blank');
                        removeMenu();
                    });
                    
                    addMenuItem('Download Linked File', function() {
                        webkit.messageHandlers.downloadHandler.postMessage(url);
                        removeMenu();
                    });
                    
                    addMenuItem('Copy Link', function() {
                        navigator.clipboard.writeText(url);
                        removeMenu();
                    });
                }
                
                document.body.appendChild(customMenu);
                
                // Remove menu on click outside
                setTimeout(function() {
                    document.addEventListener('click', removeMenu, { once: true });
                }, 100);
            }
            
            function addMenuItem(text, onclick) {
                let item = document.createElement('div');
                item.textContent = text;
                item.style.padding = '8px 16px';
                item.style.cursor = 'pointer';
                item.style.borderBottom = '1px solid rgba(255, 255, 255, 0.1)';
                
                item.addEventListener('mouseenter', function() {
                    item.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                });
                
                item.addEventListener('mouseleave', function() {
                    item.style.backgroundColor = 'transparent';
                });
                
                item.addEventListener('click', onclick);
                
                customMenu.appendChild(item);
                
                // Remove border from last item
                let items = customMenu.children;
                if (items.length > 0) {
                    items[items.length - 1].style.borderBottom = 'none';
                }
            }
            
            function removeMenu() {
                if (customMenu) {
                    customMenu.remove();
                    customMenu = null;
                }
            }
            
            // Hide menu on scroll or resize
            document.addEventListener('scroll', removeMenu);
            window.addEventListener('resize', removeMenu);
        """
        
        let contextScript = WKUserScript(source: contextMenuScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        configuration.userContentController.addUserScript(contextScript)
        
        // Initialize WebView before calling super.init()
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        
        super.init()
        
        // Set navigation delegate for authentication handling
        self.webView.navigationDelegate = self
        
        // Set UI delegate for context menu handling
        self.webView.uiDelegate = self
        
        // Add message handler for downloads
        self.webView.configuration.userContentController.add(self, name: "downloadHandler")
        
        // Configure download handling
        if #available(macOS 11.3, *) {
            // Download delegate will be set per download
        }
        
        // Configure for downloads - use modern preferences
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
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
        
        // Check if this should be downloaded
        guard let response = navigationResponse.response as? HTTPURLResponse,
              let mimeType = response.mimeType else {
            decisionHandler(.allow)
            return
        }
        
        // Determine if this should be downloaded based on content type
        let downloadMimeTypes = [
            "application/pdf",
            "application/zip",
            "application/octet-stream",
            "application/x-zip-compressed",
            "application/x-rar-compressed",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "image/jpeg", "image/png", "image/gif", "image/webp", "image/svg+xml",
            "video/mp4", "video/quicktime", "video/x-msvideo",
            "audio/mpeg", "audio/wav", "audio/aac"
        ]
        
        let contentDisposition = response.allHeaderFields["Content-Disposition"] as? String
        let shouldDownload = downloadMimeTypes.contains(mimeType) || 
                           contentDisposition?.contains("attachment") == true ||
                           contentDisposition?.contains("filename") == true
        
        if shouldDownload {
            if #available(macOS 11.3, *) {
                decisionHandler(.download)
            } else {
                // Fallback for older macOS versions
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
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
    
    // MARK: - WKDownloadDelegate
    @available(macOS 11.3, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
        print("🔽 Download started: \(download)")
    }
    
    @available(macOS 11.3, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
        print("🔽 Download started from response: \(download)")
    }
    
    @available(macOS 11.3, *)
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destinationURL = downloadsURL.appendingPathComponent(suggestedFilename)
        
        // Handle duplicate filenames
        var finalURL = destinationURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let nameWithoutExtension = (suggestedFilename as NSString).deletingPathExtension
            let fileExtension = (suggestedFilename as NSString).pathExtension
            let newFilename = "\(nameWithoutExtension) (\(counter)).\(fileExtension)"
            finalURL = downloadsURL.appendingPathComponent(newFilename)
            counter += 1
        }
        
        print("📥 Downloading \(suggestedFilename) to: \(finalURL.path)")
        completionHandler(finalURL)
    }
    
    @available(macOS 11.3, *)
    func download(_ download: WKDownload, didFinishDownloadingTo location: URL) {
        print("✅ Download completed: \(location.path)")
        
        // Create download item and add to manager
        let fileName = location.lastPathComponent
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64) ?? 0
        
        let downloadItem = DownloadItem(
            url: location,
            fileName: fileName,
            filePath: location,
            fileSize: fileSize,
            downloadDate: Date(),
            isComplete: true
        )
        
        DispatchQueue.main.async {
            DownloadsManager.shared.addDownload(downloadItem)
        }
    }
    
    @available(macOS 11.3, *)
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        print("❌ Download failed: \(error.localizedDescription)")
    }
    
    // MARK: - WKUIDelegate for Context Menu Support
    // Note: Custom context menus on macOS use JavaScript-based detection
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "downloadHandler" {
            if let urlString = message.body as? String, let url = URL(string: urlString) {
                downloadFileWithSavePanel(from: url)
            }
        }
    }
    
    // MARK: - Download Helper Methods
    private func downloadFile(from url: URL) {
        // Use URLSession to download the file manually since right-click downloads
        // don't go through the normal WKWebView download flow
        
        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
            guard let location = location,
                  let response = response else {
                print("❌ Download failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let suggestedFilename = response.suggestedFilename ?? url.lastPathComponent
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let destinationURL = downloadsURL.appendingPathComponent(suggestedFilename)
            
            // Handle duplicate filenames
            var finalURL = destinationURL
            var counter = 1
            while FileManager.default.fileExists(atPath: finalURL.path) {
                let nameWithoutExtension = (suggestedFilename as NSString).deletingPathExtension
                let fileExtension = (suggestedFilename as NSString).pathExtension
                let newFilename = "\(nameWithoutExtension) (\(counter)).\(fileExtension)"
                finalURL = downloadsURL.appendingPathComponent(newFilename)
                counter += 1
            }
            
            do {
                try FileManager.default.moveItem(at: location, to: finalURL)
                print("✅ Downloaded: \(finalURL.path)")
                
                // Create download item and add to manager
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: finalURL.path)[.size] as? Int64) ?? 0
                
                let downloadItem = DownloadItem(
                    url: url,
                    fileName: finalURL.lastPathComponent,
                    filePath: finalURL,
                    fileSize: fileSize,
                    downloadDate: Date(),
                    isComplete: true
                )
                
                DispatchQueue.main.async {
                    DownloadsManager.shared.addDownload(downloadItem)
                }
                
            } catch {
                print("❌ Failed to move downloaded file: \(error.localizedDescription)")
            }
        }
        
        task.resume()
        print("🔽 Starting download: \(url.absoluteString)")
    }
    
    private func downloadFileWithSavePanel(from url: URL) {
        print("🔽 Starting download with save panel: \(url.absoluteString)")
        
        // Get suggested filename from URL
        let suggestedFilename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        
        DispatchQueue.main.async {
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = suggestedFilename
            savePanel.prompt = "Save"
            savePanel.message = "Choose where to save the file"
            
            // Set allowed file types based on URL extension
            let fileExtension = (suggestedFilename as NSString).pathExtension
            if !fileExtension.isEmpty {
                savePanel.allowedContentTypes = [UTType(filenameExtension: fileExtension) ?? UTType.data]
            }
            
            savePanel.begin { response in
                guard response == .OK, let destinationURL = savePanel.url else {
                    print("❌ Save cancelled by user")
                    return
                }
                
                print("💾 User chose to save to: \(destinationURL.path)")
                
                // Start download
                let task = URLSession.shared.downloadTask(with: url) { location, response, error in
                    guard let location = location else {
                        print("❌ Download failed: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    
                    do {
                        // Remove existing file if it exists
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        
                        try FileManager.default.moveItem(at: location, to: destinationURL)
                        print("✅ Downloaded successfully: \(destinationURL.path)")
                        
                        // Create download item and add to manager
                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0
                        
                        let downloadItem = DownloadItem(
                            url: url,
                            fileName: destinationURL.lastPathComponent,
                            filePath: destinationURL,
                            fileSize: fileSize,
                            downloadDate: Date(),
                            isComplete: true
                        )
                        
                        DispatchQueue.main.async {
                            print("📁 Adding download to manager: \(downloadItem.fileName)")
                            DownloadsManager.shared.addDownload(downloadItem)
                            print("📢 Download should now be added to list")
                        }
                        
                    } catch {
                        print("❌ Failed to save downloaded file: \(error.localizedDescription)")
                    }
                }
                
                task.resume()
            }
        }
    }

}