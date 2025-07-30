import Cocoa

/// Centralized color management for consistent theming throughout the browser
class ColorManager {
    static let shared = ColorManager()
    
    private init() {}
    
    // MARK: - Primary Colors
    
    /// Primary background color - Deep elegant gray for professional look
    static var primaryBackground: NSColor {
        return NSColor(hex: "1a1a1a") // #1a1a1a Deep gray, warmer than pure black
    }
    
    /// Secondary background color - Elevated surfaces and cards
    static var secondaryBackground: NSColor {
        return NSColor(hex: "2a2a2a") // #2a2a2a Medium gray for elevated elements
    }
    
    /// Tertiary background color - For subtle differentiation
    static var tertiaryBackground: NSColor {
        return NSColor(hex: "3a3a3a") // #3a3a3a Lighter gray for hover states
    }
    
    /// Accent color - Subtle blue for interactive elements
    static var accent: NSColor {
        return NSColor(hex: "4a9eff") // #4a9eff Elegant blue, inspired by macOS but muted
    }
    
    /// Accent color hover state - slightly brighter blue
    static var accentHover: NSColor {
        return NSColor(hex: "6db1ff") // #6db1ff Lighter blue for hover states
    }
    
    // MARK: - Text Colors
    
    /// Primary text color - Pure white for maximum contrast
    static var primaryText: NSColor {
        return NSColor(hex: "ffffff") // #ffffff Pure white for primary text
    }
    
    /// Secondary text color - Light gray for secondary information
    static var secondaryText: NSColor {
        return NSColor(hex: "b8b8b8") // #b8b8b8 Light gray for subtitles and secondary text
    }
    
    /// Tertiary text color - Medium gray for inactive elements
    static var tertiaryText: NSColor {
        return NSColor(hex: "6b6b6b") // #6b6b6b Medium gray for inactive/disabled text
    }
    
    /// Placeholder text color
    static var placeholderText: NSColor {
        return NSColor(calibratedWhite: 0.5, alpha: 1.0)
    }
    
    // MARK: - State Colors
    
    /// Success color - for positive actions
    static var success: NSColor {
        return NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.35, alpha: 1.0) // #34C759
    }
    
    /// Warning color - for caution states
    static var warning: NSColor {
        return NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.00, alpha: 1.0) // #FF9500
    }
    
    /// Error color - for error states
    static var error: NSColor {
        return NSColor(calibratedRed: 1.00, green: 0.23, blue: 0.19, alpha: 1.0) // #FF3B30
    }
    
    // MARK: - Border Colors
    
    /// Primary border color - Subtle gray for clean separation
    static var primaryBorder: NSColor {
        return NSColor(hex: "4a4a4a") // #4a4a4a Medium gray for visible borders
    }
    
    /// Secondary border color - Very subtle for minimal separation
    static var secondaryBorder: NSColor {
        return NSColor(hex: "333333") // #333333 Darker gray for subtle borders
    }
    
    // MARK: - Overlay Colors
    
    /// Semi-transparent overlay for modal backgrounds
    static var overlay: NSColor {
        return NSColor(calibratedWhite: 0.0, alpha: 0.3)
    }
    
    /// Glass morphism background with blur effect
    static var glassMorphism: NSColor {
        return NSColor(calibratedWhite: 0.15, alpha: 0.8)
    }
    
    // MARK: - Tab Colors
    
    /// Active tab background
    static var activeTab: NSColor {
        return primaryBackground
    }
    
    /// Inactive tab background
    static var inactiveTab: NSColor {
        return NSColor.clear
    }
    
    /// Tab hover background - subtle elevation using secondary background
    static var tabHover: NSColor {
        return NSColor(hex: "3a3a3a", alpha: 0.5) // Subtle gray hover effect
    }
    
    /// Tab active glow color - soft blue accent
    static var tabGlow: NSColor {
        return NSColor(hex: "4a9eff", alpha: 0.15) // Very subtle blue glow
    }
    
    // MARK: - Gradient Colors
    
    /// Creates a subtle gradient for depth
    static func createSubtleGradient() -> NSGradient {
        let startColor = NSColor(calibratedWhite: 0.2, alpha: 1.0)
        let endColor = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        return NSGradient(starting: startColor, ending: endColor) ?? NSGradient()
    }
    
    /// Creates an accent gradient
    static func createAccentGradient() -> NSGradient {
        let startColor = accent
        let endColor = accentHover
        return NSGradient(starting: startColor, ending: endColor) ?? NSGradient()
    }
    
    // MARK: - Shadow Colors
    
    /// Light shadow color
    static var lightShadow: NSColor {
        return NSColor(calibratedWhite: 0.0, alpha: 0.05)
    }
    
    /// Medium shadow color
    static var mediumShadow: NSColor {
        return NSColor(calibratedWhite: 0.0, alpha: 0.15)
    }
    
    /// Strong shadow color
    static var strongShadow: NSColor {
        return NSColor(calibratedWhite: 0.0, alpha: 0.25)
    }
    
    // MARK: - Branded Favorite Colors (Arc-style)
    
    /// Google brand color
    static var googleBlue: NSColor {
        return NSColor(calibratedRed: 0.26, green: 0.52, blue: 0.96, alpha: 1.0) // #4285F4
    }
    
    /// YouTube brand color
    static var youtubeRed: NSColor {
        return NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) // #FF0000
    }
    
    /// GitHub dark color
    static var githubDark: NSColor {
        return NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.13, alpha: 1.0) // #212121
    }
    
    /// Stack Overflow orange
    static var stackOverflowOrange: NSColor {
        return NSColor(calibratedRed: 0.94, green: 0.45, blue: 0.20, alpha: 1.0) // #F48024
    }
    
    /// Netflix red
    static var netflixRed: NSColor {
        return NSColor(calibratedRed: 0.90, green: 0.11, blue: 0.14, alpha: 1.0) // #E50914
    }
    
    /// LinkedIn blue
    static var linkedinBlue: NSColor {
        return NSColor(calibratedRed: 0.0, green: 0.47, blue: 0.71, alpha: 1.0) // #0077B5
    }
    
    /// Facebook blue
    static var facebookBlue: NSColor {
        return NSColor(calibratedRed: 0.26, green: 0.40, blue: 0.70, alpha: 1.0) // #4267B2
    }
    
    /// Creates a branded color for a URL
    static func brandedColor(for url: URL) -> NSColor {
        let host = url.host?.lowercased() ?? ""
        
        if host.contains("google") {
            return googleBlue
        } else if host.contains("youtube") {
            return youtubeRed
        } else if host.contains("github") {
            return githubDark
        } else if host.contains("stackoverflow") {
            return stackOverflowOrange
        } else if host.contains("netflix") {
            return netflixRed
        } else if host.contains("linkedin") {
            return linkedinBlue
        } else if host.contains("facebook") {
            return facebookBlue
        } else {
            return accent
        }
    }
    
    // MARK: - Dotted Pattern Colors
    
    /// Light background for dotted pattern
    static var dottedBackground: NSColor {
        return NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.94, alpha: 1.0) // #F0F0F0
    }
    
    /// Subtle dot color for pattern
    static var dotColor: NSColor {
        return NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0) // #D9D9D9
    }
    
    /// Creates a dotted pattern background
    static func createDottedPattern(size: CGSize = CGSize(width: 20, height: 20)) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Fill background
        dottedBackground.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw dot
        let dotSize: CGFloat = 2.0
        let dotRect = NSRect(
            x: (size.width - dotSize) / 2,
            y: (size.height - dotSize) / 2,
            width: dotSize,
            height: dotSize
        )
        
        dotColor.setFill()
        let path = NSBezierPath(ovalIn: dotRect)
        path.fill()
        
        image.unlockFocus()
        return image
    }
}

// MARK: - Color Extensions for easier usage

extension NSColor {
    /// Convenience method to create color with hex string
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        
        self.init(
            calibratedRed: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: alpha
        )
    }
}