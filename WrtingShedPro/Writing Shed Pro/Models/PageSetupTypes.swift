//
//  PageSetupTypes.swift
//  Writing Shed Pro
//
//  Supporting types for Page Setup functionality
//

import Foundation

// MARK: - Units

/// Measurement units for page dimensions
enum Units: String, Codable, CaseIterable {
    case points
    case millimetres
    case inches
    
    /// Scale factor for converting to points (base unit)
    var scaleFactor: Double {
        switch self {
        case .points:
            return 1.33
        case .millimetres:
            return 3.7795275591
        case .inches:
            return 96.0
        }
    }
    
    var localizedName: String {
        switch self {
        case .points:
            return NSLocalizedString("units.points", comment: "Points measurement unit")
        case .millimetres:
            return NSLocalizedString("units.millimetres", comment: "Millimetres measurement unit")
        case .inches:
            return NSLocalizedString("units.inches", comment: "Inches measurement unit")
        }
    }
}

// MARK: - Orientation

/// Page orientation
enum Orientation: Int16, Codable, CaseIterable {
    case portrait = 0
    case landscape = 1
    
    var localizedName: String {
        switch self {
        case .portrait:
            return NSLocalizedString("orientation.portrait", comment: "Portrait orientation")
        case .landscape:
            return NSLocalizedString("orientation.landscape", comment: "Landscape orientation")
        }
    }
}

// MARK: - Paper Sizes

/// Standard paper sizes
enum PaperSizes: String, Codable, CaseIterable {
    case Letter = "Letter"
    case Legal = "Legal"
    case A4 = "A4"
    case A5 = "A5"
    case Custom = "Custom"
    
    /// Paper dimensions in points (72 points = 1 inch)
    var dimensions: (width: Double, height: Double) {
        switch self {
        case .Letter:
            return (612.0, 792.0)  // 8.5" x 11"
        case .Legal:
            return (612.0, 1008.0)  // 8.5" x 14"
        case .A4:
            return (595.0, 842.0)  // 210mm x 297mm
        case .A5:
            return (420.0, 595.0)  // 148mm x 210mm
        case .Custom:
            return (612.0, 792.0)  // Default to Letter
        }
    }
    
    var localizedName: String {
        switch self {
        case .Letter:
            return NSLocalizedString("paperSize.letter", comment: "Letter paper size")
        case .Legal:
            return NSLocalizedString("paperSize.legal", comment: "Legal paper size")
        case .A4:
            return NSLocalizedString("paperSize.a4", comment: "A4 paper size")
        case .A5:
            return NSLocalizedString("paperSize.a5", comment: "A5 paper size")
        case .Custom:
            return NSLocalizedString("paperSize.custom", comment: "Custom paper size")
        }
    }
    
    /// Get default paper size based on locale
    static var defaultForRegion: PaperSizes {
        let regionCode = Locale.current.region?.identifier ?? "US"
        
        // US, Canada, Mexico, and some Latin American countries use Letter
        let letterRegions = ["US", "CA", "MX", "CL", "CO", "CR", "PA", "PH", "PR"]
        
        if letterRegions.contains(regionCode) {
            return .Letter
        } else {
            // Most of the world uses A4
            return .A4
        }
    }
}

// MARK: - Default Values

/// Default page setup values
struct PageSetupDefaults {
    static let marginTop: Double = 72.0      // 1 inch
    static let marginBottom: Double = 72.0   // 1 inch
    static let marginLeft: Double = 72.0     // 1 inch
    static let marginRight: Double = 72.0    // 1 inch
    static let headerDepth: Double = 36.0    // 0.5 inch
    static let footerDepth: Double = 36.0    // 0.5 inch
    static let scaleFactorInches: Double = 96.0
}
