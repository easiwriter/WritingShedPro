//
//  UIColor+Hex.swift
//  Writing Shed Pro
//
//  UIColor extension for hex string conversion
//

import UIKit

extension UIColor {
    /// Convert UIColor to hex string
    func toHex() -> String? {
        guard let components = cgColor.components, components.count >= 1 else { return nil }
        
        let r, g, b, a: Float
        
        if components.count == 2 {
            // Grayscale color (white, alpha)
            r = Float(components[0])
            g = Float(components[0])
            b = Float(components[0])
            a = Float(components[1])
        } else if components.count >= 3 {
            // RGB color
            r = Float(components[0])
            g = Float(components[1])
            b = Float(components[2])
            a = Float(components.count >= 4 ? components[3] : 1.0)
        } else {
            return nil
        }
        
        if a == 1.0 {
            return String(format: "#%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255),
                         lroundf(a * 255))
        }
    }
    
    /// Create UIColor from hex string
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        let r, g, b, a: CGFloat
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    /// Create a darker version of the color
    /// - Parameter percentage: Amount to darken (0.0 to 1.0)
    /// - Returns: Darker color or nil if components can't be extracted
    func darker(by percentage: CGFloat = 0.3) -> UIColor? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        return UIColor(
            red: max(red * (1.0 - percentage), 0.0),
            green: max(green * (1.0 - percentage), 0.0),
            blue: max(blue * (1.0 - percentage), 0.0),
            alpha: alpha
        )
    }
}
