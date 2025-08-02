import Cocoa

// MARK: - Custom Theme Structure
struct CustomTheme: Codable {
    let id: String
    let name: String
    let accentColor: ColorData
    let brightness: Float // 0.0 - 1.0
    let contrast: Float // 0.0 - 1.0
    let saturation: Float // 0.0 - 1.0
    let isCustom: Bool
    
    init(id: String = UUID().uuidString, 
         name: String, 
         accentColor: NSColor, 
         brightness: Float = 0.5, 
         contrast: Float = 0.5, 
         saturation: Float = 0.5,
         isCustom: Bool = true) {
        self.id = id
        self.name = name
        self.accentColor = ColorData(color: accentColor)
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.isCustom = isCustom
    }
}

// MARK: - Color Data for Persistence
struct ColorData: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(color: NSColor) {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        self.red = Double(rgbColor.redComponent)
        self.green = Double(rgbColor.greenComponent)
        self.blue = Double(rgbColor.blueComponent)
        self.alpha = Double(rgbColor.alphaComponent)
    }
    
    var nsColor: NSColor {
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Arc-style Color Palette
enum ArcColorPalette: String, CaseIterable {
    case systemBlue = "System Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case mint = "Mint"
    case cyan = "Cyan"
    case indigo = "Indigo"
    case gray = "Gray"
    case brown = "Brown"
    
    var color: NSColor {
        switch self {
        case .systemBlue: return NSColor(hex: "007AFF")
        case .purple: return NSColor(hex: "AF52DE")
        case .pink: return NSColor(hex: "FF2D92")
        case .red: return NSColor(hex: "FF3B30")
        case .orange: return NSColor(hex: "FF9500")
        case .yellow: return NSColor(hex: "FFCC00")
        case .green: return NSColor(hex: "34C759")
        case .mint: return NSColor(hex: "00C7BE")
        case .cyan: return NSColor(hex: "32D3E8")
        case .indigo: return NSColor(hex: "5856D6")
        case .gray: return NSColor(hex: "8E8E93")
        case .brown: return NSColor(hex: "A2845E")
        }
    }
    
    var icon: String {
        switch self {
        case .systemBlue: return "●"
        case .purple: return "●"
        case .pink: return "●"
        case .red: return "●"
        case .orange: return "●"
        case .yellow: return "●"
        case .green: return "●"
        case .mint: return "●"
        case .cyan: return "●"
        case .indigo: return "●"
        case .gray: return "●"
        case .brown: return "●"
        }
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentBaseTheme: AppTheme = .auto
    @Published var currentCustomTheme: CustomTheme?
    @Published var isUsingCustomTheme: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let baseThemeKey = "AppTheme"
    private let customThemeKey = "CustomTheme"
    private let isUsingCustomThemeKey = "IsUsingCustomTheme"
    private let savedThemesKey = "SavedCustomThemes"
    
    weak var themeDelegate: ThemeNotchViewDelegate?
    
    private init() {
        loadSavedTheme()
        setupDefaultThemes()
    }
    
    // MARK: - Default Themes Setup
    private func setupDefaultThemes() {
        // Create default custom themes based on Arc colors
        if getSavedThemes().isEmpty {
            let defaultThemes = ArcColorPalette.allCases.map { palette in
                CustomTheme(
                    name: palette.rawValue,
                    accentColor: palette.color,
                    isCustom: false
                )
            }
            saveThemes(defaultThemes)
        }
    }
    
    // MARK: - Theme Application
    func applyTheme(_ theme: CustomTheme) {
        currentCustomTheme = theme
        isUsingCustomTheme = true
        
        // Update ColorManager with new theme
        ColorManager.shared.updateDynamicColors(
            accent: theme.accentColor.nsColor,
            brightness: theme.brightness,
            contrast: theme.contrast,
            saturation: theme.saturation
        )
        
        // Apply system appearance
        applySystemAppearance()
        
        // Save current state
        saveCurrentTheme()
        
        // Notify delegates
        notifyThemeChange()
        
        print("🎨 Applied custom theme: \(theme.name)")
    }
    
    func applyBaseTheme(_ theme: AppTheme) {
        currentBaseTheme = theme
        isUsingCustomTheme = false
        currentCustomTheme = nil
        
        // Reset ColorManager to defaults
        ColorManager.shared.resetToDefaults()
        
        // Apply system appearance
        applySystemAppearance()
        
        // Save current state
        saveCurrentTheme()
        
        // Notify delegates
        notifyThemeChange()
        
        print("🎨 Applied base theme: \(theme.rawValue)")
    }
    
    private func applySystemAppearance() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let appearance: NSAppearance?
            
            if self.isUsingCustomTheme {
                // For custom themes, use auto to respect system preference
                appearance = nil
            } else {
                switch self.currentBaseTheme {
                case .light:
                    appearance = NSAppearance(named: .aqua)
                case .dark:
                    appearance = NSAppearance(named: .darkAqua)
                case .auto:
                    appearance = nil
                }
            }
            
            // Apply to all windows
            for window in NSApplication.shared.windows {
                window.appearance = appearance
            }
        }
    }
    
    // MARK: - Custom Theme Creation
    func createCustomTheme(
        name: String,
        baseColor: NSColor,
        brightness: Float = 0.5,
        contrast: Float = 0.5,
        saturation: Float = 0.5
    ) -> CustomTheme {
        let theme = CustomTheme(
            name: name,
            accentColor: baseColor,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation
        )
        
        // Save to collection
        var savedThemes = getSavedThemes()
        savedThemes.append(theme)
        saveThemes(savedThemes)
        
        return theme
    }
    
    func updateCurrentCustomTheme(
        brightness: Float? = nil,
        contrast: Float? = nil,
        saturation: Float? = nil
    ) {
        guard var theme = currentCustomTheme else { return }
        
        if let brightness = brightness {
            theme = CustomTheme(
                id: theme.id,
                name: theme.name,
                accentColor: theme.accentColor.nsColor,
                brightness: brightness,
                contrast: theme.contrast,
                saturation: theme.saturation,
                isCustom: theme.isCustom
            )
        }
        
        if let contrast = contrast {
            theme = CustomTheme(
                id: theme.id,
                name: theme.name,
                accentColor: theme.accentColor.nsColor,
                brightness: theme.brightness,
                contrast: contrast,
                saturation: theme.saturation,
                isCustom: theme.isCustom
            )
        }
        
        if let saturation = saturation {
            theme = CustomTheme(
                id: theme.id,
                name: theme.name,
                accentColor: theme.accentColor.nsColor,
                brightness: theme.brightness,
                contrast: theme.contrast,
                saturation: saturation,
                isCustom: theme.isCustom
            )
        }
        
        applyTheme(theme)
    }
    
    // MARK: - Persistence
    private func saveCurrentTheme() {
        userDefaults.set(currentBaseTheme.rawValue, forKey: baseThemeKey)
        userDefaults.set(isUsingCustomTheme, forKey: isUsingCustomThemeKey)
        
        if let customTheme = currentCustomTheme {
            if let encoded = try? JSONEncoder().encode(customTheme) {
                userDefaults.set(encoded, forKey: customThemeKey)
            }
        } else {
            userDefaults.removeObject(forKey: customThemeKey)
        }
    }
    
    private func loadSavedTheme() {
        // Load base theme
        if let savedTheme = userDefaults.string(forKey: baseThemeKey),
           let theme = AppTheme(rawValue: savedTheme) {
            currentBaseTheme = theme
        }
        
        // Load custom theme usage preference
        isUsingCustomTheme = userDefaults.bool(forKey: isUsingCustomThemeKey)
        
        // Load custom theme if using one
        if isUsingCustomTheme,
           let themeData = userDefaults.data(forKey: customThemeKey),
           let theme = try? JSONDecoder().decode(CustomTheme.self, from: themeData) {
            currentCustomTheme = theme
            applyTheme(theme)
        } else if !isUsingCustomTheme {
            applyBaseTheme(currentBaseTheme)
        }
    }
    
    private func saveThemes(_ themes: [CustomTheme]) {
        if let encoded = try? JSONEncoder().encode(themes) {
            userDefaults.set(encoded, forKey: savedThemesKey)
        }
    }
    
    func getSavedThemes() -> [CustomTheme] {
        guard let data = userDefaults.data(forKey: savedThemesKey),
              let themes = try? JSONDecoder().decode([CustomTheme].self, from: data) else {
            return []
        }
        return themes
    }
    
    // MARK: - Utility Methods
    func getEffectiveIsDarkMode() -> Bool {
        if isUsingCustomTheme {
            // For custom themes, check system preference
            let systemAppearance = NSApp.effectiveAppearance
            return systemAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        } else {
            switch currentBaseTheme {
            case .light: return false
            case .dark: return true
            case .auto:
                let systemAppearance = NSApp.effectiveAppearance
                return systemAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            }
        }
    }
    
    private func notifyThemeChange() {
        let isDarkMode = getEffectiveIsDarkMode()
        themeDelegate?.themeNotchDidToggleTheme(isDarkMode)
        
        // Post notification for other components
        NotificationCenter.default.post(
            name: .themeDidChange,
            object: self,
            userInfo: [
                "isUsingCustomTheme": isUsingCustomTheme,
                "isDarkMode": isDarkMode
            ]
        )
    }
    
    // MARK: - Public Interface
    func resetToDefaults() {
        userDefaults.removeObject(forKey: customThemeKey)
        userDefaults.removeObject(forKey: isUsingCustomThemeKey)
        currentCustomTheme = nil
        isUsingCustomTheme = false
        currentBaseTheme = .auto
        
        applyBaseTheme(.auto)
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChange")
}