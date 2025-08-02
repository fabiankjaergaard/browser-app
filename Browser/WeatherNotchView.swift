import Cocoa
import CoreLocation

protocol WeatherNotchViewDelegate: AnyObject {
    func weatherNotchDidUpdateWeather(_ weather: WeatherData)
    func weatherNotchDidFailToLoad(_ error: String)
}

struct WeatherData: Codable {
    let temperature: Double
    let condition: String
    let description: String
    let humidity: Int
    let windSpeed: Double
    let city: String
    let country: String
    let icon: String
    
    var temperatureString: String {
        return String(format: "%.0f°", temperature)
    }
    
    var windSpeedString: String {
        return String(format: "%.1f m/s", windSpeed)
    }
    
    var emoji: String {
        switch icon {
        case "01d", "01n": return "☀️"
        case "02d", "02n": return "⛅"
        case "03d", "03n", "04d", "04n": return "☁️"
        case "09d", "09n": return "🌧️"
        case "10d", "10n": return "🌦️"
        case "11d", "11n": return "⛈️"
        case "13d", "13n": return "❄️"
        case "50d", "50n": return "🌫️"
        default: return "🌤️"
        }
    }
}

struct ForecastItem: Codable {
    let date: String
    let temperature: Double
    let condition: String
    let icon: String
    
    var emoji: String {
        switch icon {
        case "01d", "01n": return "☀️"
        case "02d", "02n": return "⛅"
        case "03d", "03n", "04d", "04n": return "☁️"
        case "09d", "09n": return "🌧️"
        case "10d", "10n": return "🌦️"
        case "11d", "11n": return "⛈️"
        case "13d", "13n": return "❄️"
        case "50d", "50n": return "🌫️"
        default: return "🌤️"
        }
    }
}

class WeatherNotchView: NSView {
    
    weak var delegate: WeatherNotchViewDelegate?
    weak var contentViewController: ContentViewController?
    
    // UI Components
    private var weatherIconView: NSView!
    private var weatherIconLabel: NSTextField!
    private var dropdownWindow: KeyablePanel!
    private var weatherContainer: NSView!
    private var currentWeatherView: NSView!
    private var temperatureLabel: NSTextField!
    private var conditionLabel: NSTextField!
    private var locationLabel: NSTextField!
    private var detailsStack: NSStackView!
    private var humidityLabel: NSTextField!
    private var windLabel: NSTextField!
    private var forecastScrollView: NSScrollView!
    private var forecastStackView: NSStackView!
    private var refreshButton: NSButton!
    private var statusLabel: NSTextField!
    
    // State
    private var isDropdownVisible = false
    private var mouseExitTimer: Timer?
    private var globalMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var currentWeather: WeatherData?
    private var forecast: [ForecastItem] = []
    private var isLoading = false
    
    // Location
    private var locationManager: CLLocationManager!
    private var currentLocation: CLLocation?
    
    // API
    private let apiKey = "YOUR_OPENWEATHER_API_KEY" // Replace with actual API key
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    
    // Constants
    private let dropdownWidth: CGFloat = 320
    private let dropdownHeight: CGFloat = 280
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        setupLocationManager()
        loadCachedWeather()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupLocationManager()
        loadCachedWeather()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupWeatherIcon()
        setupDropdownWindow()
        setupLayout()
        setupTrackingArea()
    }
    
    private func setupWeatherIcon() {
        weatherIconView = NSView()
        weatherIconView.translatesAutoresizingMaskIntoConstraints = false
        weatherIconView.wantsLayer = true
        weatherIconView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.8).cgColor
        weatherIconView.layer?.cornerRadius = 6
        weatherIconView.layer?.borderWidth = 1
        weatherIconView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Modern minimal shadow
        weatherIconView.shadow = NSShadow()
        weatherIconView.shadow?.shadowOffset = NSSize(width: 0, height: 1)
        weatherIconView.shadow?.shadowBlurRadius = 2
        weatherIconView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.05)
        
        weatherIconLabel = NSTextField(labelWithString: "◐")
        weatherIconLabel.translatesAutoresizingMaskIntoConstraints = false
        weatherIconLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        weatherIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        weatherIconLabel.alignment = .center
        
        weatherIconView.addSubview(weatherIconLabel)
        addSubview(weatherIconView)
    }
    
    private func setupDropdownWindow() {
        dropdownWindow = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: dropdownWidth, height: dropdownHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        dropdownWindow.isOpaque = false
        dropdownWindow.backgroundColor = NSColor.clear
        dropdownWindow.hasShadow = true
        dropdownWindow.level = .floating
        dropdownWindow.animationBehavior = .utilityWindow
        dropdownWindow.acceptsMouseMovedEvents = true
        
        setupWeatherContainer()
        dropdownWindow.contentView = weatherContainer
        dropdownWindow.alphaValue = 0
    }
    
    private func setupWeatherContainer() {
        weatherContainer = NSView()
        weatherContainer.wantsLayer = true
        
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        
        weatherContainer.addSubview(visualEffect)
        
        // Header
        let headerLabel = NSTextField(labelWithString: "Weather")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = NSColor.labelColor
        
        // Refresh button
        refreshButton = NSButton()
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        refreshButton.bezelStyle = .regularSquare
        refreshButton.isBordered = false
        refreshButton.target = self
        refreshButton.action = #selector(refreshWeather)
        
        // Current weather
        setupCurrentWeatherView()
        
        // Forecast scroll view
        setupForecastView()
        
        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        statusLabel.textColor = NSColor.tertiaryLabelColor
        statusLabel.alignment = .center
        
        // Add all subviews
        weatherContainer.addSubview(headerLabel)
        weatherContainer.addSubview(refreshButton)
        weatherContainer.addSubview(currentWeatherView)
        weatherContainer.addSubview(forecastScrollView)
        weatherContainer.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            // Visual effect background
            visualEffect.topAnchor.constraint(equalTo: weatherContainer.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: weatherContainer.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: weatherContainer.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: weatherContainer.bottomAnchor),
            
            // Header
            headerLabel.topAnchor.constraint(equalTo: weatherContainer.topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: weatherContainer.leadingAnchor, constant: 16),
            
            // Refresh button
            refreshButton.topAnchor.constraint(equalTo: weatherContainer.topAnchor, constant: 8),
            refreshButton.trailingAnchor.constraint(equalTo: weatherContainer.trailingAnchor, constant: -12),
            refreshButton.widthAnchor.constraint(equalToConstant: 24),
            refreshButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Current weather
            currentWeatherView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            currentWeatherView.leadingAnchor.constraint(equalTo: weatherContainer.leadingAnchor, constant: 16),
            currentWeatherView.trailingAnchor.constraint(equalTo: weatherContainer.trailingAnchor, constant: -16),
            currentWeatherView.heightAnchor.constraint(equalToConstant: 80),
            
            // Forecast
            forecastScrollView.topAnchor.constraint(equalTo: currentWeatherView.bottomAnchor, constant: 12),
            forecastScrollView.leadingAnchor.constraint(equalTo: weatherContainer.leadingAnchor, constant: 16),
            forecastScrollView.trailingAnchor.constraint(equalTo: weatherContainer.trailingAnchor, constant: -16),
            forecastScrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            
            // Status
            statusLabel.leadingAnchor.constraint(equalTo: weatherContainer.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: weatherContainer.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: weatherContainer.bottomAnchor, constant: -8)
        ])
    }
    
    private func setupCurrentWeatherView() {
        currentWeatherView = NSView()
        currentWeatherView.translatesAutoresizingMaskIntoConstraints = false
        
        // Temperature (large)
        temperatureLabel = NSTextField(labelWithString: "--°")
        temperatureLabel.translatesAutoresizingMaskIntoConstraints = false
        temperatureLabel.font = NSFont.systemFont(ofSize: 32, weight: .light)
        temperatureLabel.textColor = NSColor.labelColor
        temperatureLabel.alignment = .center
        
        // Condition
        conditionLabel = NSTextField(labelWithString: "Loading...")
        conditionLabel.translatesAutoresizingMaskIntoConstraints = false
        conditionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        conditionLabel.textColor = NSColor.labelColor
        conditionLabel.alignment = .center
        
        // Location
        locationLabel = NSTextField(labelWithString: "")
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        locationLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        locationLabel.textColor = NSColor.secondaryLabelColor
        locationLabel.alignment = .center
        
        // Details (humidity, wind)
        humidityLabel = NSTextField(labelWithString: "💧 --%")
        humidityLabel.translatesAutoresizingMaskIntoConstraints = false
        humidityLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        humidityLabel.textColor = NSColor.secondaryLabelColor
        
        windLabel = NSTextField(labelWithString: "💨 -- m/s")
        windLabel.translatesAutoresizingMaskIntoConstraints = false
        windLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        windLabel.textColor = NSColor.secondaryLabelColor
        
        detailsStack = NSStackView(views: [humidityLabel, windLabel])
        detailsStack.translatesAutoresizingMaskIntoConstraints = false
        detailsStack.orientation = .horizontal
        detailsStack.distribution = .fillEqually
        detailsStack.spacing = 8
        
        currentWeatherView.addSubview(temperatureLabel)
        currentWeatherView.addSubview(conditionLabel)
        currentWeatherView.addSubview(locationLabel)
        currentWeatherView.addSubview(detailsStack)
        
        NSLayoutConstraint.activate([
            temperatureLabel.topAnchor.constraint(equalTo: currentWeatherView.topAnchor),
            temperatureLabel.centerXAnchor.constraint(equalTo: currentWeatherView.centerXAnchor),
            
            conditionLabel.topAnchor.constraint(equalTo: temperatureLabel.bottomAnchor, constant: -4),
            conditionLabel.centerXAnchor.constraint(equalTo: currentWeatherView.centerXAnchor),
            
            locationLabel.topAnchor.constraint(equalTo: conditionLabel.bottomAnchor, constant: 2),
            locationLabel.centerXAnchor.constraint(equalTo: currentWeatherView.centerXAnchor),
            
            detailsStack.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 4),
            detailsStack.centerXAnchor.constraint(equalTo: currentWeatherView.centerXAnchor),
            detailsStack.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupForecastView() {
        forecastScrollView = NSScrollView()
        forecastScrollView.translatesAutoresizingMaskIntoConstraints = false
        forecastScrollView.hasVerticalScroller = false
        forecastScrollView.hasHorizontalScroller = true
        forecastScrollView.autohidesScrollers = true
        forecastScrollView.borderType = .noBorder
        forecastScrollView.drawsBackground = false
        
        forecastStackView = NSStackView()
        forecastStackView.translatesAutoresizingMaskIntoConstraints = false
        forecastStackView.orientation = .horizontal
        forecastStackView.spacing = 8
        forecastStackView.distribution = .fill
        
        forecastScrollView.documentView = forecastStackView
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            weatherIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            weatherIconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            weatherIconView.widthAnchor.constraint(equalToConstant: 24),
            weatherIconView.heightAnchor.constraint(equalToConstant: 24),
            
            weatherIconLabel.centerXAnchor.constraint(equalTo: weatherIconView.centerXAnchor),
            weatherIconLabel.centerYAnchor.constraint(equalTo: weatherIconView.centerYAnchor)
        ])
    }
    
    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // MARK: - Weather API
    
    @objc private func refreshWeather() {
        guard !isLoading else { return }
        requestLocationAndFetchWeather()
    }
    
    private func requestLocationAndFetchWeather() {
        guard apiKey != "YOUR_OPENWEATHER_API_KEY" else {
            updateStatus("API key required")
            fetchWeatherForDefaultLocation()
            return
        }
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            fetchWeatherForDefaultLocation()
        @unknown default:
            fetchWeatherForDefaultLocation()
        }
    }
    
    private func fetchWeatherForDefaultLocation() {
        // Default to Stockholm, Sweden
        fetchWeather(latitude: 59.3293, longitude: 18.0686)
    }
    
    private func fetchWeather(latitude: Double, longitude: Double) {
        guard !isLoading else { return }
        isLoading = true
        updateStatus("Loading weather...")
        refreshButton.isEnabled = false
        
        let urlString = "\(baseURL)/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            handleWeatherError("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.refreshButton.isEnabled = true
                
                if let error = error {
                    self?.handleWeatherError("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self?.handleWeatherError("No data received")
                    return
                }
                
                self?.parseWeatherData(data)
            }
        }.resume()
    }
    
    private func parseWeatherData(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let main = json["main"] as? [String: Any],
               let weather = json["weather"] as? [[String: Any]],
               let firstWeather = weather.first,
               let sys = json["sys"] as? [String: Any],
               let wind = json["wind"] as? [String: Any] {
                
                let weatherData = WeatherData(
                    temperature: main["temp"] as? Double ?? 0,
                    condition: firstWeather["main"] as? String ?? "",
                    description: firstWeather["description"] as? String ?? "",
                    humidity: main["humidity"] as? Int ?? 0,
                    windSpeed: wind["speed"] as? Double ?? 0,
                    city: json["name"] as? String ?? "",
                    country: sys["country"] as? String ?? "",
                    icon: firstWeather["icon"] as? String ?? ""
                )
                
                currentWeather = weatherData
                updateWeatherDisplay()
                cacheWeatherData(weatherData)
                delegate?.weatherNotchDidUpdateWeather(weatherData)
                updateStatus("Updated \(formatLastUpdated())")
                
            } else {
                handleWeatherError("Invalid data format")
            }
        } catch {
            handleWeatherError("Parsing error: \(error.localizedDescription)")
        }
    }
    
    private func handleWeatherError(_ message: String) {
        print("🌤️ Weather error: \(message)")
        updateStatus("Error: \(message)")
        delegate?.weatherNotchDidFailToLoad(message)
    }
    
    private func updateWeatherDisplay() {
        guard let weather = currentWeather else { return }
        
        temperatureLabel.stringValue = weather.temperatureString
        conditionLabel.stringValue = weather.condition
        locationLabel.stringValue = "\(weather.city), \(weather.country)"
        humidityLabel.stringValue = "💧 \(weather.humidity)%"
        windLabel.stringValue = "💨 \(weather.windSpeedString)"
        
        // Update icon with temperature or weather emoji
        weatherIconLabel.stringValue = weather.emoji
        
        // Update text color based on temperature for subtle indication
        if weather.temperature < 0 {
            weatherIconLabel.textColor = NSColor.systemBlue.withAlphaComponent(0.9)
        } else if weather.temperature < 15 {
            weatherIconLabel.textColor = NSColor.systemTeal.withAlphaComponent(0.9)
        } else if weather.temperature < 25 {
            weatherIconLabel.textColor = NSColor.labelColor.withAlphaComponent(0.8)
        } else {
            weatherIconLabel.textColor = NSColor.systemOrange.withAlphaComponent(0.9)
        }
    }
    
    private func cacheWeatherData(_ weather: WeatherData) {
        if let encoded = try? JSONEncoder().encode(weather) {
            UserDefaults.standard.set(encoded, forKey: "CachedWeather")
            UserDefaults.standard.set(Date(), forKey: "WeatherCacheTime")
        }
    }
    
    private func loadCachedWeather() {
        guard let data = UserDefaults.standard.data(forKey: "CachedWeather"),
              let weather = try? JSONDecoder().decode(WeatherData.self, from: data),
              let cacheTime = UserDefaults.standard.object(forKey: "WeatherCacheTime") as? Date else {
            return
        }
        
        // Use cached data if less than 10 minutes old
        if Date().timeIntervalSince(cacheTime) < 600 {
            currentWeather = weather
            updateWeatherDisplay()
            updateStatus("Cached data from \(formatTime(cacheTime))")
        }
    }
    
    private func formatLastUpdated() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func updateStatus(_ status: String) {
        statusLabel.stringValue = status
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.statusLabel.stringValue == status {
                self?.statusLabel.stringValue = ""
            }
        }
    }
    
    // MARK: - Mouse Events & Dropdown (same pattern as other notches)
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        // Check if this is from dropdown tracking area
        if let userInfo = event.trackingArea?.userInfo,
           let _ = userInfo["dropdown"] {
            // Mouse entered dropdown area - cancel any hide timers
            mouseExitTimer?.invalidate()
            return
        }
        
        // Mouse entered icon area
        mouseExitTimer?.invalidate()
        if !isDropdownVisible {
            showDropdown()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // Check if this is from dropdown tracking area
        if let userInfo = event.trackingArea?.userInfo,
           let _ = userInfo["dropdown"] {
            // Mouse exited dropdown area - hide immediately
            hideDropdown()
            return
        }
        
        // Mouse exited icon area - don't hide if dropdown is visible (user might move to dropdown)
        // The dropdown tracking will handle hiding when mouse exits dropdown
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        // Toggle dropdown on click
        if isDropdownVisible {
            print("🌤️ Click detected - hiding dropdown")
            hideDropdown()
        } else {
            print("🌤️ Click detected - showing dropdown") 
            showDropdown()
        }
    }
    
    private func isMouseInSafeZone(_ mouseLocation: NSPoint) -> Bool {
        guard let window = self.window else { return false }
        
        let iconFrame = weatherIconView.frame
        let iconInWindow = convert(iconFrame, to: nil)
        let iconInScreen = window.convertToScreen(NSRect(origin: iconInWindow.origin, size: iconInWindow.size))
        let iconSafeZone = iconInScreen.insetBy(dx: -10, dy: -10)
        
        if isDropdownVisible {
            let dropdownFrame = dropdownWindow.frame
            let dropdownSafeZone = dropdownFrame.insetBy(dx: -5, dy: -5)
            return iconSafeZone.contains(mouseLocation) || dropdownSafeZone.contains(mouseLocation)
        }
        
        return iconSafeZone.contains(mouseLocation)
    }
    
    private func showDropdown() {
        guard !isDropdownVisible else { return }
        
        contentViewController?.notchWillShow(self)
        isDropdownVisible = true
        
        // Fetch fresh weather data when showing
        if currentWeather == nil || shouldRefreshWeather() {
            refreshWeather()
        }
        
        positionDropdownWindow()
        dropdownWindow.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            dropdownWindow.animator().alphaValue = 1.0
            let scaleTransform = CATransform3DMakeScale(1.1, 1.1, 1.0)
            weatherIconView.layer?.transform = scaleTransform
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.dropdownWindow.makeKey()
            print("🌤️ Made weather panel key window")
        }
        
        setupDropdownTracking()
        startGlobalMouseMonitoring()
        startGlobalClickMonitoring()
    }
    
    private func shouldRefreshWeather() -> Bool {
        guard let cacheTime = UserDefaults.standard.object(forKey: "WeatherCacheTime") as? Date else {
            return true
        }
        return Date().timeIntervalSince(cacheTime) > 600 // 10 minutes
    }
    
    private func hideDropdown() {
        guard isDropdownVisible else { return }
        isDropdownVisible = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            dropdownWindow.animator().alphaValue = 0.0
            weatherIconView.layer?.transform = CATransform3DIdentity
        }, completionHandler: { [weak self] in
            self?.dropdownWindow.orderOut(nil)
            self?.removeDropdownTracking()
            self?.stopGlobalMouseMonitoring()
            self?.stopGlobalClickMonitoring()
        })
    }
    
    private func positionDropdownWindow() {
        guard let window = self.window else { return }
        
        let iconFrame = weatherIconView.frame
        let iconInWindow = convert(iconFrame, to: nil)
        let iconInScreen = window.convertToScreen(NSRect(origin: iconInWindow.origin, size: iconInWindow.size))
        let windowFrame = window.frame
        
        // Calculate desired position (centered under icon)
        var dropdownX = iconInScreen.midX - (dropdownWidth * 0.5)
        let dropdownY = iconInScreen.minY - dropdownHeight - 10
        
        // Ensure dropdown stays within window bounds
        let windowMinX = windowFrame.minX + 10 // 10px margin from left edge
        let windowMaxX = windowFrame.maxX - dropdownWidth - 10 // 10px margin from right edge
        
        // Clamp the x position to stay within window bounds
        dropdownX = max(windowMinX, min(dropdownX, windowMaxX))
        
        let dropdownFrame = NSRect(
            x: dropdownX,
            y: dropdownY,
            width: dropdownWidth,
            height: dropdownHeight
        )
        
        dropdownWindow.setFrame(dropdownFrame, display: false)
    }
    
    private func setupDropdownTracking() {
        guard let contentView = dropdownWindow.contentView else { return }
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: ["dropdown": true]
        )
        contentView.addTrackingArea(trackingArea)
    }
    
    private func removeDropdownTracking() {
        guard let contentView = dropdownWindow.contentView else { return }
        contentView.trackingAreas.forEach { contentView.removeTrackingArea($0) }
    }
    
    private func startGlobalMouseMonitoring() {
        stopGlobalMouseMonitoring()
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleGlobalMouseMove(event)
        }
    }
    
    private func stopGlobalMouseMonitoring() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }
    
    private func startGlobalClickMonitoring() {
        stopGlobalClickMonitoring()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalClick(event)
        }
    }
    
    private func stopGlobalClickMonitoring() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
    
    private func handleGlobalClick(_ event: NSEvent) {
        guard isDropdownVisible else { return }
        let clickLocation = NSEvent.mouseLocation
        if !isMouseInSafeZone(clickLocation) {
            print("🌤️ Click detected outside weather area - hiding dropdown")
            hideDropdown()
        }
    }
    
    private func handleGlobalMouseMove(_ event: NSEvent) {
        // Simplified - no longer needed for immediate hiding
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // MARK: - Public Interface
    
    func hideDropdownIfVisible() {
        if isDropdownVisible {
            hideDropdown()
        }
    }
    
    deinit {
        mouseExitTimer?.invalidate()
        stopGlobalMouseMonitoring()
        stopGlobalClickMonitoring()
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherNotchView: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        fetchWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🌤️ Location error: \(error.localizedDescription)")
        fetchWeatherForDefaultLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            fetchWeatherForDefaultLocation()
        default:
            break
        }
    }
}