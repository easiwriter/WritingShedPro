//
//  PageSetupModels.swift
//  Writing Shed Pro
//
//  SwiftData models for Page Setup functionality
//

import Foundation
import SwiftData

// MARK: - PageSetup Model

@Model
@Syncable
final class PageSetup {
    var id: UUID = UUID()
    var paperName: String?
    var orientation: Int16 = 0  // 0 = portrait, 1 = landscape
    var headers: Int16 = 0      // 0 = false, 1 = true
    var footers: Int16 = 0      // 0 = false, 1 = true
    var facingPages: Int16 = 0  // 0 = false, 1 = true
    var hideFirstSection: Int16 = 0
    var matchPreviousSection: Int16 = 0
    
    // Margins (in points)
    var marginTop: Double = 0.0
    var marginBottom: Double = 0.0
    var marginLeft: Double = 0.0
    var marginRight: Double = 0.0
    
    // Header/Footer depths (in points)
    var headerDepth: Double = 0.0
    var footerDepth: Double = 0.0
    
    // Scale factor for unit conversion
    var scaleFactor: Double = 96.0  // Default to inches
    
    // Relationships
    // Note: Project relationship removed - page setup is now global (UserDefaults)
    
    @Relationship(deleteRule: .cascade, inverse: \PrinterPaper.pageSetup)
    var printerPapers: [PrinterPaper]?
    
    init(
        paperName: String? = nil,
        orientation: Orientation = .portrait,
        headers: Bool = false,
        footers: Bool = false,
        facingPages: Bool = false,
        marginTop: Double = PageSetupDefaults.marginTop,
        marginBottom: Double = PageSetupDefaults.marginBottom,
        marginLeft: Double = PageSetupDefaults.marginLeft,
        marginRight: Double = PageSetupDefaults.marginRight,
        headerDepth: Double = PageSetupDefaults.headerDepth,
        footerDepth: Double = PageSetupDefaults.footerDepth,
        scaleFactor: Double = PageSetupDefaults.scaleFactorInches
    ) {
        // Use region-appropriate default paper if none specified
        self.paperName = paperName ?? PaperSizes.defaultForRegion.rawValue
        self.orientation = orientation.rawValue
        self.headers = headers ? 1 : 0
        self.footers = footers ? 1 : 0
        self.facingPages = facingPages ? 1 : 0
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.marginLeft = marginLeft
        self.marginRight = marginRight
        self.headerDepth = headerDepth
        self.footerDepth = footerDepth
        self.scaleFactor = scaleFactor
        self.printerPapers = []
    }
    
    // MARK: - Computed Properties
    
    var orientationEnum: Orientation {
        get { Orientation(rawValue: orientation) ?? .portrait }
        set { orientation = newValue.rawValue }
    }
    
    var hasHeaders: Bool {
        get { headers == 1 }
        set { headers = newValue ? 1 : 0 }
    }
    
    var hasFooters: Bool {
        get { footers == 1 }
        set { footers = newValue ? 1 : 0 }
    }
    
    var hasFacingPages: Bool {
        get { facingPages == 1 }
        set { facingPages = newValue ? 1 : 0 }
    }
    
    var paperSize: PaperSizes {
        get {
            guard let paperName = paperName,
                  let size = PaperSizes(rawValue: paperName) else {
                return .defaultForRegion
            }
            return size
        }
        set {
            paperName = newValue.rawValue
        }
    }
}

// MARK: - PrinterPaper Model

@Model
@Syncable
final class PrinterPaper {
    var id: UUID = UUID()
    var paperName: String?
    var sizeH: Double = 0.0     // Horizontal size
    var sizeV: Double = 0.0     // Vertical size
    var rectH: Double = 0.0     // Printable rect horizontal
    var rectV: Double = 0.0     // Printable rect vertical
    var scalefactor: Double = 96.0
    
    // Relationship
    @Relationship(deleteRule: .nullify)
    var pageSetup: PageSetup?
    
    init(
        paperName: String? = nil,
        sizeH: Double = 0.0,
        sizeV: Double = 0.0,
        rectH: Double = 0.0,
        rectV: Double = 0.0,
        scalefactor: Double = 96.0
    ) {
        self.paperName = paperName
        self.sizeH = sizeH
        self.sizeV = sizeV
        self.rectH = rectH
        self.rectV = rectV
        self.scalefactor = scalefactor
    }
}
