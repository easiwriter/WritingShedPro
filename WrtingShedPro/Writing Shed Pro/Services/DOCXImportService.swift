import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class DOCXImportService {
    
    enum DOCXImportError: LocalizedError {
        case invalidFile
        case missingDocumentXML
        case parsingFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidFile: return "Invalid DOCX file format"
            case .missingDocumentXML: return "DOCX file is missing document content"
            case .parsingFailed: return "Failed to parse DOCX content"
            }
        }
    }
    
    /// Import a DOCX file and convert it to NSAttributedString
    static func importDOCX(from url: URL) throws -> NSAttributedString {
        // Read the DOCX file data
        let data = try Data(contentsOf: url)
        return try importDOCX(from: data)
    }
    
    /// Import DOCX data and convert it to NSAttributedString
    static func importDOCX(from data: Data) throws -> NSAttributedString {
        // Extract the XML from the DOCX ZIP structure
        let documentXML = try extractDocumentXML(from: data)
        
        // Parse the XML and create attributed string
        return try parseDocumentXML(documentXML)
    }
    
    private static func extractDocumentXML(from data: Data) throws -> String {
        // DOCX is a ZIP file - extract document.xml directly
        return try extractXMLFromZIP(data)
    }
    
    // Extract document.xml from DOCX ZIP structure
    private static func extractXMLFromZIP(_ zipData: Data) throws -> String {
        // Simple ZIP parser to extract word/document.xml
        // ZIP local file header signature: 0x04034b50
        let localFileHeaderSignature: UInt32 = 0x04034b50
        
        var offset = 0
        let data = zipData
        
        while offset < data.count - 30 {
            // Read potential signature
            guard offset + 4 <= data.count else { break }
            let signature = data.withUnsafeBytes { buffer -> UInt32 in
                buffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            }
            
            if signature == localFileHeaderSignature {
                // Found a file entry
                guard offset + 30 <= data.count else { break }
                
                // Read filename length (at offset 26-27)
                let filenameLength = data.withUnsafeBytes { buffer -> UInt16 in
                    buffer.loadUnaligned(fromByteOffset: offset + 26, as: UInt16.self)
                }
                
                // Read extra field length (at offset 28-29)
                let extraFieldLength = data.withUnsafeBytes { buffer -> UInt16 in
                    buffer.loadUnaligned(fromByteOffset: offset + 28, as: UInt16.self)
                }
                
                // Read compressed size (at offset 18-21)
                let compressedSize = data.withUnsafeBytes { buffer -> UInt32 in
                    buffer.loadUnaligned(fromByteOffset: offset + 18, as: UInt32.self)
                }
                
                // Read compression method (at offset 8-9)
                let compressionMethod = data.withUnsafeBytes { buffer -> UInt16 in
                    buffer.loadUnaligned(fromByteOffset: offset + 8, as: UInt16.self)
                }
                
                // Read filename
                let filenameStart = offset + 30
                guard filenameStart + Int(filenameLength) <= data.count else { break }
                let filenameData = data.subdata(in: filenameStart..<(filenameStart + Int(filenameLength)))
                let filename = String(data: filenameData, encoding: .utf8) ?? ""
                
                // Check if this is word/document.xml
                if filename == "word/document.xml" {
                    let contentStart = filenameStart + Int(filenameLength) + Int(extraFieldLength)
                    guard contentStart + Int(compressedSize) <= data.count else {
                        throw DOCXImportError.parsingFailed
                    }
                    
                    let contentData = data.subdata(in: contentStart..<(contentStart + Int(compressedSize)))
                    
                    // If not compressed (stored), return directly
                    if compressionMethod == 0 {
                        if let xmlString = String(data: contentData, encoding: .utf8) {
                            return xmlString
                        }
                    } else if compressionMethod == 8 {
                        // Deflate compression - decompress
                        do {
                            let decompressed = try (contentData as NSData).decompressed(using: .zlib) as Data
                            if let xmlString = String(data: decompressed, encoding: .utf8) {
                                return xmlString
                            }
                        } catch {
                            throw DOCXImportError.parsingFailed
                        }
                    }
                }
                
                // Move to next entry
                offset = filenameStart + Int(filenameLength) + Int(extraFieldLength) + Int(compressedSize)
            } else {
                offset += 1
            }
        }
        
        throw DOCXImportError.missingDocumentXML
    }
    
    private static func parseDocumentXML(_ xml: String) throws -> NSAttributedString {
        let parser = DOCXXMLParser()
        return try parser.parse(xml)
    }
}

// MARK: - XML Parser

class DOCXXMLParser: NSObject, XMLParserDelegate {
    private var attributedString = NSMutableAttributedString()
    private var currentParagraph = NSMutableAttributedString()
    private var currentRun = NSMutableAttributedString()
    private var currentText = ""
    
    private var isBold = false
    private var isItalic = false
    private var isUnderline = false
    
    private var inBody = false
    private var inParagraph = false
    private var inRun = false
    private var inText = false
    private var inRunProperties = false
    
    func parse(_ xmlString: String) throws -> NSAttributedString {
        guard let data = xmlString.data(using: .utf8) else {
            throw DOCXImportService.DOCXImportError.parsingFailed
        }
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            throw DOCXImportService.DOCXImportError.parsingFailed
        }
        
        return attributedString
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        
        switch localName {
        case "body":
            inBody = true
            
        case "p":
            inParagraph = true
            currentParagraph = NSMutableAttributedString()
            
        case "r":
            inRun = true
            currentRun = NSMutableAttributedString()
            // Reset formatting for new run
            isBold = false
            isItalic = false
            isUnderline = false
            
        case "rPr":
            inRunProperties = true
            
        case "b":
            if inRunProperties {
                isBold = true
            }
            
        case "i":
            if inRunProperties {
                isItalic = true
            }
            
        case "u":
            if inRunProperties {
                isUnderline = true
            }
            
        case "t":
            inText = true
            currentText = ""
            
        case "br":
            // Handle line breaks and page breaks
            if inParagraph && attributeDict["w:type"] == "page" {
                // Page break - add some newlines
                currentParagraph.append(NSAttributedString(string: "\n\n"))
            } else if inRun {
                // Regular line break
                currentRun.append(NSAttributedString(string: "\n"))
            }
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        
        switch localName {
        case "body":
            inBody = false
            
        case "p":
            // End of paragraph - add newline if not empty
            if currentParagraph.length > 0 {
                attributedString.append(currentParagraph)
                attributedString.append(NSAttributedString(string: "\n"))
            } else {
                // Empty paragraph
                attributedString.append(NSAttributedString(string: "\n"))
            }
            inParagraph = false
            
        case "r":
            // End of run - add to current paragraph
            currentParagraph.append(currentRun)
            inRun = false
            
        case "rPr":
            inRunProperties = false
            
        case "t":
            // End of text - create attributed string with formatting
            if !currentText.isEmpty {
                var attributes: [NSAttributedString.Key: Any] = [:]
                
                #if canImport(UIKit)
                var font = UIFont.systemFont(ofSize: 17)
                var traits: UIFontDescriptor.SymbolicTraits = []
                
                if isBold {
                    traits.insert(.traitBold)
                }
                if isItalic {
                    traits.insert(.traitItalic)
                }
                
                if !traits.isEmpty {
                    if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                        font = UIFont(descriptor: descriptor, size: 17)
                    }
                }
                
                attributes[.font] = font
                
                #elseif canImport(AppKit)
                var font = NSFont.systemFont(ofSize: 13)
                var traits: NSFontDescriptor.SymbolicTraits = []
                
                if isBold {
                    traits.insert(.bold)
                }
                if isItalic {
                    traits.insert(.italic)
                }
                
                if !traits.isEmpty {
                    if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                        font = NSFont(descriptor: descriptor, size: 13) ?? font
                    }
                }
                
                attributes[.font] = font
                #endif
                
                if isUnderline {
                    attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }
                
                let attrString = NSAttributedString(string: currentText, attributes: attributes)
                currentRun.append(attrString)
            }
            inText = false
            currentText = ""
            
        default:
            break
        }
    }
}
