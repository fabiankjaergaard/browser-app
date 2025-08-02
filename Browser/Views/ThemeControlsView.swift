import Cocoa

protocol ThemeControlsViewDelegate: AnyObject {
    func themeControlsView(_ controlsView: ThemeControlsView, didUpdateBrightness brightness: Float)
    func themeControlsView(_ controlsView: ThemeControlsView, didUpdateContrast contrast: Float)
    func themeControlsView(_ controlsView: ThemeControlsView, didUpdateSaturation saturation: Float)
}

class ThemeControlsView: NSView {
    
    weak var delegate: ThemeControlsViewDelegate?
    
    // Control components
    private var brightnessSlider: WaveSlider!
    private var contrastDial: CircularDial!
    private var saturationSlider: NSSlider!
    
    // Labels
    private var brightnessLabel: NSTextField!
    private var contrastLabel: NSTextField!
    private var saturationLabel: NSTextField!
    
    // Values
    private var currentBrightness: Float = 0.5
    private var currentContrast: Float = 0.5
    private var currentSaturation: Float = 0.5
    
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
        
        setupLabels()
        setupControls()
        setupLayout()
    }
    
    private func setupLabels() {
        brightnessLabel = createLabel("Brightness")
        contrastLabel = createLabel("Contrast")
        saturationLabel = createLabel("Saturation")
        
        addSubview(brightnessLabel)
        addSubview(contrastLabel)
        addSubview(saturationLabel)
    }
    
    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = NSColor.secondaryLabelColor
        label.alignment = .left
        return label
    }
    
    private func setupControls() {
        // Wave-style brightness slider
        brightnessSlider = WaveSlider()
        brightnessSlider.translatesAutoresizingMaskIntoConstraints = false
        brightnessSlider.delegate = self
        brightnessSlider.value = currentBrightness
        
        // Circular dial for contrast
        contrastDial = CircularDial()
        contrastDial.translatesAutoresizingMaskIntoConstraints = false
        contrastDial.delegate = self
        contrastDial.value = currentContrast
        
        // Standard slider for saturation with Arc-style appearance
        saturationSlider = NSSlider()
        saturationSlider.translatesAutoresizingMaskIntoConstraints = false
        saturationSlider.sliderType = .linear
        saturationSlider.minValue = 0.0
        saturationSlider.maxValue = 1.0
        saturationSlider.doubleValue = Double(currentSaturation)
        saturationSlider.target = self
        saturationSlider.action = #selector(saturationChanged(_:))
        
        // Style the saturation slider
        styleSaturationSlider()
        
        addSubview(brightnessSlider)
        addSubview(contrastDial)
        addSubview(saturationSlider)
    }
    
    private func styleSaturationSlider() {
        saturationSlider.wantsLayer = true
        
        // Style the slider with Arc-like appearance
        saturationSlider.layer?.cornerRadius = 4
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Brightness section
            brightnessLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            brightnessLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            brightnessSlider.topAnchor.constraint(equalTo: brightnessLabel.bottomAnchor, constant: 8),
            brightnessSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            brightnessSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            brightnessSlider.heightAnchor.constraint(equalToConstant: 40),
            
            // Contrast section
            contrastLabel.topAnchor.constraint(equalTo: brightnessSlider.bottomAnchor, constant: 20),
            contrastLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            contrastDial.topAnchor.constraint(equalTo: contrastLabel.bottomAnchor, constant: 8),
            contrastDial.centerXAnchor.constraint(equalTo: centerXAnchor),
            contrastDial.widthAnchor.constraint(equalToConstant: 60),
            contrastDial.heightAnchor.constraint(equalToConstant: 60),
            
            // Saturation section
            saturationLabel.topAnchor.constraint(equalTo: contrastDial.bottomAnchor, constant: 20),
            saturationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            saturationSlider.topAnchor.constraint(equalTo: saturationLabel.bottomAnchor, constant: 8),
            saturationSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            saturationSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            saturationSlider.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func saturationChanged(_ sender: NSSlider) {
        currentSaturation = Float(sender.doubleValue)
        delegate?.themeControlsView(self, didUpdateSaturation: currentSaturation)
    }
    
    // MARK: - Public Interface
    
    func setBrightness(_ brightness: Float) {
        currentBrightness = brightness
        brightnessSlider.value = brightness
    }
    
    func setContrast(_ contrast: Float) {
        currentContrast = contrast
        contrastDial.value = contrast
    }
    
    func setSaturation(_ saturation: Float) {
        currentSaturation = saturation
        saturationSlider.doubleValue = Double(saturation)
    }
    
    func getValues() -> (brightness: Float, contrast: Float, saturation: Float) {
        return (currentBrightness, currentContrast, currentSaturation)
    }
}

// MARK: - WaveSliderDelegate
extension ThemeControlsView: WaveSliderDelegate {
    func waveSlider(_ slider: WaveSlider, didChangeValue value: Float) {
        currentBrightness = value
        delegate?.themeControlsView(self, didUpdateBrightness: currentBrightness)
    }
}

// MARK: - CircularDialDelegate
extension ThemeControlsView: CircularDialDelegate {
    func circularDial(_ dial: CircularDial, didChangeValue value: Float) {
        currentContrast = value
        delegate?.themeControlsView(self, didUpdateContrast: currentContrast)
    }
}

// MARK: - Wave Slider Implementation
protocol WaveSliderDelegate: AnyObject {
    func waveSlider(_ slider: WaveSlider, didChangeValue value: Float)
}

class WaveSlider: NSView {
    weak var delegate: WaveSliderDelegate?
    
    var value: Float = 0.5 {
        didSet {
            needsDisplay = true
        }
    }
    
    private var isDragging = false
    private let waveAmplitude: CGFloat = 8
    private let waveFrequency: CGFloat = 0.03
    
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
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let trackHeight: CGFloat = 4
        let trackY = (bounds.height - trackHeight) / 2
        
        // Draw track background
        let trackRect = NSRect(x: 8, y: trackY, width: bounds.width - 16, height: trackHeight)
        context.setFillColor(NSColor.tertiaryLabelColor.withAlphaComponent(0.3).cgColor)
        context.fill(trackRect)
        
        // Draw wave progress
        drawWaveProgress(in: context, trackRect: trackRect)
        
        // Draw thumb
        drawThumb(in: context, trackRect: trackRect)
    }
    
    private func drawWaveProgress(in context: CGContext, trackRect: NSRect) {
        let progressWidth = trackRect.width * CGFloat(value)
        let progressRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: progressWidth, height: trackRect.height)
        
        context.saveGState()
        context.clip(to: progressRect)
        
        // Create wave path
        let path = NSBezierPath()
        let centerY = trackRect.midY
        let startX = trackRect.minX
        let endX = trackRect.maxX
        
        path.move(to: NSPoint(x: startX, y: centerY))
        
        for x in stride(from: startX, to: endX, by: 1) {
            let phase = (x - startX) * waveFrequency
            let amplitude = sin(phase + CGFloat(CACurrentMediaTime() * 2)) * waveAmplitude * CGFloat(value)
            let y = centerY + amplitude * 0.5
            path.line(to: NSPoint(x: x, y: y))
        }
        
        // Use system blue for wave color
        
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(3)
        path.stroke()
        
        context.restoreGState()
    }
    
    private func drawThumb(in context: CGContext, trackRect: NSRect) {
        let thumbSize: CGFloat = 16
        let thumbX = trackRect.minX + (trackRect.width * CGFloat(value)) - (thumbSize / 2)
        let thumbY = trackRect.midY - (thumbSize / 2)
        let thumbRect = NSRect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)
        
        // Draw thumb shadow
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: NSColor.black.withAlphaComponent(0.2).cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: thumbRect)
        context.restoreGState()
        
        // Draw thumb border
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: thumbRect)
    }
    
    override func mouseDown(with event: NSEvent) {
        isDragging = true
        updateValue(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isDragging {
            updateValue(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }
    
    private func updateValue(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let trackWidth = bounds.width - 16
        let relativeX = max(0, min(trackWidth, location.x - 8))
        let newValue = Float(relativeX / trackWidth)
        
        if newValue != value {
            value = newValue
            delegate?.waveSlider(self, didChangeValue: value)
        }
    }
}

// MARK: - Circular Dial Implementation
protocol CircularDialDelegate: AnyObject {
    func circularDial(_ dial: CircularDial, didChangeValue value: Float)
}

class CircularDial: NSView {
    weak var delegate: CircularDialDelegate?
    
    var value: Float = 0.5 {
        didSet {
            needsDisplay = true
        }
    }
    
    private var isDragging = false
    private var startAngle: CGFloat = 0
    
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
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 8
        
        // Draw background circle
        context.setStrokeColor(NSColor.tertiaryLabelColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        
        // Draw progress arc
        let progressAngle = CGFloat(value) * 2 * .pi
        let startAngle: CGFloat = .pi / 2 // Start at top
        let endAngle = startAngle + progressAngle
        
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(4)
        context.addArc(center: CGPoint(x: center.x, y: center.y), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        context.strokePath()
        
        // Draw handle
        let handleAngle = startAngle + progressAngle
        let handleX = center.x + cos(handleAngle) * radius
        let handleY = center.y + sin(handleAngle) * radius
        let handleSize: CGFloat = 12
        let handleRect = NSRect(x: handleX - handleSize/2, y: handleY - handleSize/2, width: handleSize, height: handleSize)
        
        // Handle shadow
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: NSColor.black.withAlphaComponent(0.2).cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: handleRect)
        context.restoreGState()
        
        // Handle border
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: handleRect)
    }
    
    override func mouseDown(with event: NSEvent) {
        isDragging = true
        updateValue(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isDragging {
            updateValue(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }
    
    private func updateValue(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        
        let deltaX = location.x - center.x
        let deltaY = location.y - center.y
        let angle = atan2(deltaY, deltaX)
        
        // Normalize angle to 0-1 range
        let normalizedAngle = (angle + .pi / 2 + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        let newValue = Float(normalizedAngle / (2 * .pi))
        
        if newValue != value {
            value = newValue
            delegate?.circularDial(self, didChangeValue: value)
        }
    }
}