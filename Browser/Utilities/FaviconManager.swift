import Cocoa
import Foundation

/// Manages fetching and caching of favicons for bookmarks
class FaviconManager {
    static let shared = FaviconManager()
    
    private var faviconCache: [String: NSImage] = [:]
    private let session = URLSession.shared
    
    private init() {}
    
    /// Fetches favicon for a given URL and calls completion handler
    func fetchFavicon(for url: URL, completion: @escaping (NSImage?) -> Void) {
        guard let host = url.host else {
            completion(nil)
            return
        }
        
        // Check cache first
        if let cachedFavicon = faviconCache[host] {
            completion(cachedFavicon)
            return
        }
        
        // Try multiple favicon URLs in order of preference
        let faviconURLs = [
            URL(string: "https://\(host)/apple-touch-icon.png"),
            URL(string: "https://\(host)/favicon.ico"),
            URL(string: "https://\(host)/favicon.png"),
            URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=32"),
        ].compactMap { $0 }
        
        fetchFaviconFromURLs(faviconURLs, host: host, completion: completion)
    }
    
    /// Tries to fetch favicon from multiple URLs
    private func fetchFaviconFromURLs(_ urls: [URL], host: String, completion: @escaping (NSImage?) -> Void) {
        guard !urls.isEmpty else {
            completion(nil)
            return
        }
        
        let currentURL = urls[0]
        let remainingURLs = Array(urls.dropFirst())
        
        var request = URLRequest(url: currentURL)
        request.timeoutInterval = 5.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = NSImage(data: data),
                  error == nil else {
                // Try next URL if this one failed
                if !remainingURLs.isEmpty {
                    self?.fetchFaviconFromURLs(remainingURLs, host: host, completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
                return
            }
            
            // Resize image to standard size
            let resizedImage = self.resizeImage(image, to: NSSize(width: 32, height: 32))
            
            // Cache the result
            self.faviconCache[host] = resizedImage
            
            DispatchQueue.main.async {
                completion(resizedImage)
            }
        }.resume()
    }
    
    /// Resizes an image to the specified size
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        resizedImage.unlockFocus()
        return resizedImage
    }
    
    /// This function is no longer used as we keep colors separate from favicons
    /// Colors are handled by getIconStyle in SidebarFavoritesView
    func getFallbackIcon(for url: URL) -> (image: NSImage?, backgroundColor: NSColor, textColor: NSColor, iconText: String) {
        // Just return neutral values - the real styling is done in SidebarFavoritesView
        let firstLetter = String((url.host ?? url.absoluteString).prefix(1)).uppercased()
        return (nil, NSColor.gray, .white, firstLetter)
    }
    
    /// Creates a simple brand icon with text on colored background
    private func createBrandIcon(text: String, backgroundColor: NSColor, textColor: NSColor) -> NSImage {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw background
        backgroundColor.setFill()
        let rect = NSRect(origin: .zero, size: size)
        rect.fill()
        
        // Draw text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: textColor
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        attributedString.draw(in: textRect)
        
        image.unlockFocus()
        
        return image
    }
    
    /// Clears the favicon cache
    func clearCache() {
        faviconCache.removeAll()
    }
}