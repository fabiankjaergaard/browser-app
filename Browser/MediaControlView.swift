import Cocoa
import MediaPlayer

protocol MediaControlViewDelegate: AnyObject {
    func mediaControlDidPressPrevious()
    func mediaControlDidPressPlayPause()
    func mediaControlDidPressNext()
}

class MediaControlView: NSView {
    
    weak var delegate: MediaControlViewDelegate?
    
    private var previousButton: NSButton!
    private var playPauseButton: NSButton!
    private var nextButton: NSButton!
    private var isPlaying: Bool = false
    
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
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupButtons()
        setupLayout()
        setupMediaRemoteHandling()
    }
    
    private func setupButtons() {
        // Previous button
        previousButton = createMediaButton(
            systemName: "backward.fill",
            action: #selector(previousPressed),
            tooltip: "Previous track"
        )
        
        // Play/Pause button
        playPauseButton = createMediaButton(
            systemName: "play.fill",
            action: #selector(playPausePressed),
            tooltip: "Play/Pause"
        )
        
        // Next button
        nextButton = createMediaButton(
            systemName: "forward.fill",
            action: #selector(nextPressed),
            tooltip: "Next track"
        )
        
        addSubview(previousButton)
        addSubview(playPauseButton)
        addSubview(nextButton)
    }
    
    private func setupLayout() {
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Previous button - left side
            previousButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            previousButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 28),
            previousButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Play/Pause button - center
            playPauseButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playPauseButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 32),
            playPauseButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Next button - right side
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 28),
            nextButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func createMediaButton(systemName: String, action: Selector, tooltip: String) -> NSButton {
        let button = NSButton()
        button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: tooltip)
        button.target = self
        button.action = action
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.toolTip = tooltip
        button.wantsLayer = true
        
        // Styling to match browser theme
        button.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.8)
        
        // Add subtle hover effects
        if let buttonLayer = button.layer {
            buttonLayer.cornerRadius = 14 // Half of button size for circular look
            buttonLayer.backgroundColor = NSColor.clear.cgColor
        }
        
        // Add tracking area for hover effects
        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["button": button]
        )
        button.addTrackingArea(trackingArea)
        
        return button
    }
    
    private func setupMediaRemoteHandling() {
        // Register for media remote control events if available
        if #available(macOS 10.15, *) {
            MPRemoteCommandCenter.shared().playCommand.addTarget { [weak self] _ in
                self?.setPlayingState(true)
                self?.delegate?.mediaControlDidPressPlayPause()
                return .success
            }
            
            MPRemoteCommandCenter.shared().pauseCommand.addTarget { [weak self] _ in
                self?.setPlayingState(false)
                self?.delegate?.mediaControlDidPressPlayPause()
                return .success
            }
            
            MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { [weak self] _ in
                self?.delegate?.mediaControlDidPressNext()
                return .success
            }
            
            MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { [weak self] _ in
                self?.delegate?.mediaControlDidPressPrevious()
                return .success
            }
        }
    }
    
    // MARK: - Button Actions
    
    @objc private func previousPressed() {
        animateButtonPress(previousButton)
        delegate?.mediaControlDidPressPrevious()
    }
    
    @objc private func playPausePressed() {
        isPlaying.toggle()
        updatePlayPauseButton()
        animateButtonPress(playPauseButton)
        delegate?.mediaControlDidPressPlayPause()
    }
    
    @objc private func nextPressed() {
        animateButtonPress(nextButton)
        delegate?.mediaControlDidPressNext()
    }
    
    // MARK: - State Management
    
    func setPlayingState(_ playing: Bool) {
        isPlaying = playing
        updatePlayPauseButton()
    }
    
    private func updatePlayPauseButton() {
        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        let tooltip = isPlaying ? "Pause" : "Play"
        
        playPauseButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
        playPauseButton.toolTip = tooltip
    }
    
    // MARK: - Animations
    
    private func animateButtonPress(_ button: NSButton) {
        guard let layer = button.layer else { return }
        
        // Scale animation for press feedback
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnimation.values = [1.0, 0.85, 1.0]
        scaleAnimation.keyTimes = [0, 0.5, 1.0]
        scaleAnimation.duration = 0.2
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(scaleAnimation, forKey: "buttonPress")
    }
    
    // MARK: - Hover Effects
    
    override func mouseEntered(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let button = userInfo["button"] as? NSButton,
           let layer = button.layer {
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
                button.contentTintColor = NSColor.controlAccentColor
            }
        }
        super.mouseEntered(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        if let userInfo = event.trackingArea?.userInfo,
           let button = userInfo["button"] as? NSButton,
           let layer = button.layer {
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                layer.backgroundColor = NSColor.clear.cgColor
                button.contentTintColor = NSColor.controlAccentColor.withAlphaComponent(0.8)
            }
        }
        super.mouseExited(with: event)
    }
    
    // MARK: - Override dragging behavior for the container
    
    override func mouseDown(with event: NSEvent) {
        // Check if click is on a button
        let locationInView = convert(event.locationInWindow, from: nil)
        
        if previousButton.frame.contains(locationInView) ||
           playPauseButton.frame.contains(locationInView) ||
           nextButton.frame.contains(locationInView) {
            // Let the button handle the click
            super.mouseDown(with: event)
        } else {
            // Pass through to parent for window dragging
            superview?.mouseDown(with: event)
        }
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}