import Foundation
import SwiftData
import UniformTypeIdentifiers
import Observation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Observable
class DOCXExportService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func exportToDOCX(_ attributedString: NSAttributedString, filename: String) throws -> Data {
        guard attributedString.length > 0 else {
            throw DOCXExportError.noContent
        }
        let helper = DOCXExportHelper()
        let docXML = helper.createDocumentXML(withAttributedString: attributedString)
        return try helper.createDOCXPackage(documentXML: docXML)
    }
    
    func exportMultipleToDOCX(_ attributedStrings: [NSAttributedString], filename: String) throws -> Data {
        guard !attributedStrings.isEmpty else {
            throw DOCXExportError.noContent
        }
        let helper = DOCXExportHelper()
        let docXML = helper.createDocumentXML(withAttributedStrings: attributedStrings)
        return try helper.createDOCXPackage(documentXML: docXML)
    }
}

enum DOCXExportError: LocalizedError {
    case noContent
    case invalidXML
    case zipCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .noContent: return "No content to export"
        case .invalidXML: return "Failed to generate valid DOCX XML"
        case .zipCreationFailed: return "Failed to create DOCX package"
        }
    }
}

class DOCXExportHelper {
    func createDocumentXML(withAttributedString attributedString: NSAttributedString) -> String {
        let bodyContent = convertAttributedStringToWordXML(attributedString)
        return """
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">
            <w:body>
        \(bodyContent)
            </w:body>
        </w:document>
        """
    }
    
    func createDocumentXML(withAttributedStrings attributedStrings: [NSAttributedString]) -> String {
        var bodyContent = ""
        for (index, attributedString) in attributedStrings.enumerated() {
            bodyContent += convertAttributedStringToWordXML(attributedString)
            // Add page break between documents (except after the last one)
            if index < attributedStrings.count - 1 {
                bodyContent += """
            <w:p>
                <w:r>
                    <w:br w:type=\"page\"/>
                </w:r>
            </w:p>
            """
            }
        }
        return """
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">
            <w:body>
        \(bodyContent)
            </w:body>
        </w:document>
        """
    }
    
    private func convertAttributedStringToWordXML(_ attributedString: NSAttributedString) -> String {
        var xml = ""
        let string = attributedString.string
        
        // Split into paragraphs
        let paragraphs = string.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for paragraph in paragraphs {
            let paragraphLength = (paragraph as NSString).length
            let paragraphRange = NSRange(location: currentLocation, length: paragraphLength)
            
            xml += "            <w:p>\n"
            
            if paragraphLength > 0 {
                // Process runs with different formatting
                attributedString.enumerateAttributes(in: paragraphRange, options: []) { attributes, range, _ in
                    let text = (attributedString.string as NSString).substring(with: range)
                    let escapedText = escapeXML(text)
                    
                    xml += "                <w:r>\n"
                    
                    // Add formatting properties
                    var hasFormatting = false
                    var formattingXML = ""
                    
                    #if canImport(UIKit)
                    if let font = attributes[.font] as? UIFont {
                        let traits = font.fontDescriptor.symbolicTraits
                        
                        if traits.contains(.traitBold) {
                            formattingXML += "                        <w:b/>\n"
                            hasFormatting = true
                        }
                        if traits.contains(.traitItalic) {
                            formattingXML += "                        <w:i/>\n"
                            hasFormatting = true
                        }
                    }
                    #elseif canImport(AppKit)
                    if let font = attributes[.font] as? NSFont {
                        let traits = font.fontDescriptor.symbolicTraits
                        
                        if traits.contains(.bold) {
                            formattingXML += "                        <w:b/>\n"
                            hasFormatting = true
                        }
                        if traits.contains(.italic) {
                            formattingXML += "                        <w:i/>\n"
                            hasFormatting = true
                        }
                    }
                    #endif
                    
                    if let underlineStyle = attributes[.underlineStyle] as? Int, underlineStyle > 0 {
                        formattingXML += "                        <w:u w:val=\"single\"/>\n"
                        hasFormatting = true
                    }
                    
                    if hasFormatting {
                        xml += "                    <w:rPr>\n"
                        xml += formattingXML
                        xml += "                    </w:rPr>\n"
                    }
                    
                    xml += "                    <w:t xml:space=\"preserve\">\(escapedText)</w:t>\n"
                    xml += "                </w:r>\n"
                }
            } else {
                // Empty paragraph
                xml += "                <w:r><w:t></w:t></w:r>\n"
            }
            
            xml += "            </w:p>\n"
            
            // Move to next paragraph (add 1 for newline character)
            currentLocation += paragraphLength + 1
        }
        
        return xml
    }
    
    func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    func createDOCXPackage(documentXML: String) throws -> Data {
        // Create the required DOCX structure
        let contentTypesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
        
        let relsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
        
        // Create ZIP file structure manually
        var zipData = Data()
        
        // File entries with their paths and content
        let files: [(path: String, data: Data)] = [
            ("[Content_Types].xml", contentTypesXML.data(using: .utf8)!),
            ("_rels/.rels", relsXML.data(using: .utf8)!),
            ("word/document.xml", documentXML.data(using: .utf8)!)
        ]
        
        var centralDirectory = Data()
        var offset: UInt32 = 0
        
        for file in files {
            let data = file.data
            let path = file.path
            let pathData = path.data(using: .utf8)!
            
            // Local file header
            zipData.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Local file header signature
            zipData.append(contentsOf: [0x14, 0x00]) // Version needed to extract (2.0)
            zipData.append(contentsOf: [0x00, 0x00]) // General purpose bit flag
            zipData.append(contentsOf: [0x00, 0x00]) // Compression method (stored)
            zipData.append(contentsOf: [0x00, 0x00]) // Last mod file time
            zipData.append(contentsOf: [0x00, 0x00]) // Last mod file date
            
            let crc = calculateCRC32(data)
            zipData.append(contentsOf: UInt32(crc).littleEndianBytes)
            zipData.append(contentsOf: UInt32(data.count).littleEndianBytes) // Compressed size
            zipData.append(contentsOf: UInt32(data.count).littleEndianBytes) // Uncompressed size
            zipData.append(contentsOf: UInt16(pathData.count).littleEndianBytes) // File name length
            zipData.append(contentsOf: [0x00, 0x00]) // Extra field length
            
            zipData.append(pathData) // File name
            zipData.append(data) // File data
            
            // Central directory header
            centralDirectory.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // Central file header signature
            centralDirectory.append(contentsOf: [0x14, 0x00]) // Version made by
            centralDirectory.append(contentsOf: [0x14, 0x00]) // Version needed to extract
            centralDirectory.append(contentsOf: [0x00, 0x00]) // General purpose bit flag
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Compression method
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Last mod file time
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Last mod file date
            centralDirectory.append(contentsOf: UInt32(crc).littleEndianBytes)
            centralDirectory.append(contentsOf: UInt32(data.count).littleEndianBytes) // Compressed size
            centralDirectory.append(contentsOf: UInt32(data.count).littleEndianBytes) // Uncompressed size
            centralDirectory.append(contentsOf: UInt16(pathData.count).littleEndianBytes) // File name length
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Extra field length
            centralDirectory.append(contentsOf: [0x00, 0x00]) // File comment length
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Disk number start
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Internal file attributes
            centralDirectory.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // External file attributes
            centralDirectory.append(contentsOf: offset.littleEndianBytes) // Relative offset of local header
            
            centralDirectory.append(pathData) // File name
            
            offset = UInt32(zipData.count)
        }
        
        let centralDirOffset = UInt32(zipData.count)
        zipData.append(centralDirectory)
        
        // End of central directory record
        zipData.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // End of central dir signature
        zipData.append(contentsOf: [0x00, 0x00]) // Number of this disk
        zipData.append(contentsOf: [0x00, 0x00]) // Number of the disk with the start of the central directory
        zipData.append(contentsOf: UInt16(files.count).littleEndianBytes) // Total number of entries in the central directory on this disk
        zipData.append(contentsOf: UInt16(files.count).littleEndianBytes) // Total number of entries in the central directory
        zipData.append(contentsOf: UInt32(centralDirectory.count).littleEndianBytes) // Size of the central directory
        zipData.append(contentsOf: centralDirOffset.littleEndianBytes) // Offset of start of central directory
        zipData.append(contentsOf: [0x00, 0x00]) // ZIP file comment length
        
        return zipData
    }
    
    private func calculateCRC32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        
        for byte in data {
            let index = (crc ^ UInt32(byte)) & 0xFF
            crc = (crc >> 8) ^ crcTable[Int(index)]
        }
        
        return crc ^ 0xFFFFFFFF
    }
    
    private let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i)
            for _ in 0..<8 {
                if (crc & 1) != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            table[i] = crc
        }
        return table
    }()
}

// Helper extension for converting integers to little-endian byte arrays
extension UInt16 {
    var littleEndianBytes: [UInt8] {
        return [
            UInt8(self & 0xFF),
            UInt8((self >> 8) & 0xFF)
        ]
    }
}

extension UInt32 {
    var littleEndianBytes: [UInt8] {
        return [
            UInt8(self & 0xFF),
            UInt8((self >> 8) & 0xFF),
            UInt8((self >> 16) & 0xFF),
            UInt8((self >> 24) & 0xFF)
        ]
    }
}
