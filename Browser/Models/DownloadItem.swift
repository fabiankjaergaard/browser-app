import Foundation
import Cocoa

// MARK: - Download Item Model
class DownloadItem {
    let id = UUID()
    let url: URL
    let fileName: String
    let filePath: URL
    let fileSize: Int64
    let downloadDate: Date
    let fileIcon: NSImage?
    var isComplete: Bool
    
    init(url: URL, fileName: String, filePath: URL, fileSize: Int64, downloadDate: Date = Date(), isComplete: Bool = true) {
        self.url = url
        self.fileName = fileName
        self.filePath = filePath
        self.fileSize = fileSize
        self.downloadDate = downloadDate
        self.isComplete = isComplete
        self.fileIcon = NSWorkspace.shared.icon(forFile: filePath.path)
    }
    
    var formattedFileSize: String {
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: downloadDate, relativeTo: Date())
    }
}

// MARK: - Downloads Manager
class DownloadsManager {
    static let shared = DownloadsManager()
    private var downloads: [DownloadItem] = []
    
    private init() {
        loadExistingDownloads()
    }
    
    func addDownload(_ downloadItem: DownloadItem) {
        print("🗂️ DownloadsManager: Adding download \(downloadItem.fileName)")
        downloads.insert(downloadItem, at: 0) // Add to beginning for recent first
        print("📣 DownloadsManager: Posting downloadAdded notification")
        NotificationCenter.default.post(name: .downloadAdded, object: downloadItem)
        print("✅ DownloadsManager: Downloads count now: \(downloads.count)")
    }
    
    func getDownloads() -> [DownloadItem] {
        return downloads
    }
    
    private func loadExistingDownloads() {
        // Load recent downloads from Downloads folder
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            let recentFiles = fileURLs
                .compactMap { url -> (URL, Date, Int64)? in
                    guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                          let creationDate = resourceValues.creationDate,
                          let fileSize = resourceValues.fileSize else { return nil }
                    return (url, creationDate, Int64(fileSize))
                }
                .sorted { $0.1 > $1.1 } // Sort by date, newest first
                .prefix(20) // Limit to recent 20 files
            
            downloads = recentFiles.map { url, date, size in
                DownloadItem(
                    url: url,
                    fileName: url.lastPathComponent,
                    filePath: url,
                    fileSize: size,
                    downloadDate: date
                )
            }
            
        } catch {
            print("Error loading downloads: \(error)")
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let downloadAdded = Notification.Name("DownloadAdded")
}