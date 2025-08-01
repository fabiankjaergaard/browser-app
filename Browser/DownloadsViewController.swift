import Cocoa
import WebKit

// MARK: - Downloads View Controller
class DownloadsViewController: NSViewController {
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var downloads: [DownloadItem] = []
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = ColorManager.primaryBackground.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📱 DownloadsViewController: viewDidLoad called")
        setupUI()
        loadDownloads()
        setupNotifications()
        print("📱 DownloadsViewController: Setup complete")
    }
    
    private func setupUI() {
        // Title label
        let titleLabel = NSTextField(labelWithString: "Downloads")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = ColorManager.primaryText
        
        // Scroll view for downloads list
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.clear
        
        // Stack view for downloads
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.distribution = .fill
        
        scrollView.documentView = stackView
        
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func loadDownloads() {
        downloads = DownloadsManager.shared.getDownloads()
        refreshDownloadsList()
    }
    
    private func refreshDownloadsList() {
        // Clear existing views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if downloads.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No downloads yet")
            emptyLabel.textColor = ColorManager.secondaryText
            emptyLabel.font = NSFont.systemFont(ofSize: 16)
            emptyLabel.alignment = .center
            
            stackView.addArrangedSubview(emptyLabel)
            
            NSLayoutConstraint.activate([
                emptyLabel.centerYAnchor.constraint(equalTo: stackView.centerYAnchor),
                emptyLabel.centerXAnchor.constraint(equalTo: stackView.centerXAnchor)
            ])
            return
        }
        
        for download in downloads {
            let downloadView = createDownloadView(for: download)
            stackView.addArrangedSubview(downloadView)
        }
    }
    
    private func createDownloadView(for download: DownloadItem) -> NSView {
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.backgroundColor = ColorManager.secondaryBackground.cgColor
        
        // File icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = download.fileIcon ?? NSImage(systemSymbolName: "doc", accessibilityDescription: "File")
        iconView.imageScaling = .scaleProportionallyUpOrDown
        
        // File name
        let nameLabel = NSTextField(labelWithString: download.fileName)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = ColorManager.primaryText
        nameLabel.backgroundColor = NSColor.clear
        nameLabel.isBordered = false
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        nameLabel.lineBreakMode = .byTruncatingMiddle
        
        // File info (size and date)
        let infoText = "\(download.formattedFileSize) • \(download.formattedDate)"
        let infoLabel = NSTextField(labelWithString: infoText)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        infoLabel.textColor = ColorManager.secondaryText
        infoLabel.backgroundColor = NSColor.clear
        infoLabel.isBordered = false
        infoLabel.isEditable = false
        infoLabel.isSelectable = false
        
        containerView.addSubview(iconView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(infoLabel)
        
        // Add click gesture to open file
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(downloadClicked(_:)))
        containerView.addGestureRecognizer(clickGesture)
        
        // Store download item in container view for click handling
        containerView.identifier = NSUserInterfaceItemIdentifier(download.id.uuidString)
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 70),
            
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 18),
            
            infoLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            infoLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            infoLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4)
        ])
        
        return containerView
    }
    
    @objc private func downloadClicked(_ sender: NSClickGestureRecognizer) {
        guard let containerView = sender.view,
              let identifier = containerView.identifier?.rawValue,
              let downloadId = UUID(uuidString: identifier),
              let download = downloads.first(where: { $0.id == downloadId }) else { return }
        
        // Open the file
        NSWorkspace.shared.open(download.filePath)
    }
    
    private func setupNotifications() {
        print("🔧 DownloadsViewController: Setting up notification observers")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(downloadAdded(_:)),
            name: .downloadAdded,
            object: nil
        )
        print("✅ DownloadsViewController: Notification observer setup complete")
    }
    
    @objc private func downloadAdded(_ notification: Notification) {
        print("🔔 DownloadsViewController: Received downloadAdded notification")
        guard let download = notification.object as? DownloadItem else { 
            print("❌ DownloadsViewController: Invalid download object in notification")
            return 
        }
        print("📦 DownloadsViewController: Adding download \(download.fileName) to list")
        downloads.insert(download, at: 0)
        DispatchQueue.main.async {
            print("🔄 DownloadsViewController: Refreshing downloads list")
            self.refreshDownloadsList()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

