import Cocoa

class BlankStartViewController: NSViewController {
    
    private var logoImageView: NSImageView!
    private var scrollView: NSScrollView!
    private var contentView: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupScrollView()
        setupLogo()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = ColorManager.primaryBackground.cgColor
    }
    
    private func setupScrollView() {
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor.clear
        
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true
        
        scrollView.documentView = contentView
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    
    private func setupLogo() {
        logoImageView = NSImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.wantsLayer = true
        
        // Load the HomeIcon image
        if let logoImage = NSImage(named: "HomeIcon") {
            logoImageView.image = logoImage
        } else {
            // Fallback to create a simple logo if the image isn't found
            createFallbackLogo()
        }
        
        contentView.addSubview(logoImageView)
        
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 160),
            logoImageView.heightAnchor.constraint(equalToConstant: 160)
        ])
    }
    
    
    private func createFallbackLogo() {
        // Create a simple fallback logo similar to the SVG
        let logoImage = NSImage(size: NSSize(width: 200, height: 200))
        logoImage.lockFocus()
        
        // Set background to transparent
        NSColor.clear.set()
        NSRect(x: 0, y: 0, width: 200, height: 200).fill()
        
        // Create the path similar to the SVG
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 50, y: 50))
        path.curve(to: NSPoint(x: 50, y: 100), controlPoint1: NSPoint(x: 50, y: 50), controlPoint2: NSPoint(x: 50, y: 75))
        path.curve(to: NSPoint(x: 100, y: 150), controlPoint1: NSPoint(x: 50, y: 125), controlPoint2: NSPoint(x: 75, y: 150))
        path.line(to: NSPoint(x: 150, y: 150))
        path.curve(to: NSPoint(x: 150, y: 100), controlPoint1: NSPoint(x: 150, y: 150), controlPoint2: NSPoint(x: 150, y: 125))
        path.line(to: NSPoint(x: 150, y: 50))
        path.curve(to: NSPoint(x: 100, y: 50), controlPoint1: NSPoint(x: 150, y: 50), controlPoint2: NSPoint(x: 125, y: 50))
        path.close()
        
        // Add the diagonal line
        path.move(to: NSPoint(x: 100, y: 100))
        path.line(to: NSPoint(x: 150, y: 50))
        
        // Style the path
        NSColor(calibratedWhite: 1.0, alpha: 0.05).set()
        path.lineWidth = 20
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
        
        logoImage.unlockFocus()
        logoImageView.image = logoImage
    }
} 