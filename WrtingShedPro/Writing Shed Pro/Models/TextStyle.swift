//
//  TextStyle.swift
//  Writing Shed Pro
//
//  Custom attribute key for storing UIFont.TextStyle in NSAttributedString
//

import UIKit

// MARK: - NSAttributedString Integration

extension NSAttributedString.Key {
    /// Custom attribute key for text style
    /// Used to store UIFont.TextStyle.rawValue as part of paragraph formatting
    static let textStyle = NSAttributedString.Key("WritingShedPro.TextStyle")
}

extension UIFont.TextStyle {
    /// Convert to attribute value for NSAttributedString
    var attributeValue: String {
        return self.rawValue
    }
    
    /// Create from attribute value
    static func from(attributeValue: Any?) -> UIFont.TextStyle? {
        guard let string = attributeValue as? String else { return nil }
        return UIFont.TextStyle(rawValue: string)
    }
}
