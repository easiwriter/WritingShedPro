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
        return try helper.createDOCXPackage(documentXML: docXML, images: helper.collectedImages)
    }
    
    func exportMultipleToDOCX(_ attributedStrings: [NSAttributedString], filename: String) throws -> Data {
        guard !attributedStrings.isEmpty else {
            throw DOCXExportError.noContent
        }
        let helper = DOCXExportHelper()
        let docXML = helper.createDocumentXML(withAttributedStrings: attributedStrings)
        return try helper.createDOCXPackage(documentXML: docXML, images: helper.collectedImages)
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

/// Represents an image collected during document XML generation
struct DOCXImageEntry {
    let relationshipID: String   // e.g. "rId2"
    let filename: String         // e.g. "image1.jpeg"
    let data: Data               // JPEG data
    let pixelWidth: Int
    let pixelHeight: Int
}

class DOCXExportHelper {
    
    /// Maximum dimension (width or height in pixels) for images embedded in DOCX.
    private let maxImageDimension: CGFloat = 1200
    
    /// Images collected during XML generation, needed for the ZIP package.
    private(set) var collectedImages: [DOCXImageEntry] = []
    
    /// Counter for generating unique relationship IDs (rId1 is reserved for styles).
    private var nextRelID = 2
    
    func createDocumentXML(withAttributedString attributedString: NSAttributedString) -> String {
        collectedImages = []
        nextRelID = 2
        let bodyContent = convertAttributedStringToWordXML(attributedString)
        return wrapBodyContent(bodyContent)
    }
    
    func createDocumentXML(withAttributedStrings attributedStrings: [NSAttributedString]) -> String {
        collectedImages = []
        nextRelID = 2
        var bodyContent = ""
        for (index, attributedString) in attributedStrings.enumerated() {
            bodyContent += convertAttributedStringToWordXML(attributedString)
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
        return wrapBodyContent(bodyContent)
    }
    
    /// Wrap body content with the document root element and required namespaces.
    private func wrapBodyContent(_ bodyContent: String) -> String {
        // Only include DrawingML namespaces if we actually have images
        if collectedImages.isEmpty {
            return """
            <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
            <w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">
                <w:body>
            \(bodyContent)
                </w:body>
            </w:document>
            """
        } else {
            return """
            <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
            <w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"
                        xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"
                        xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"
                        xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"
                        xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">
                <w:body>
            \(bodyContent)
                </w:body>
            </w:document>
            """
        }
    }
    
    private func convertAttributedStringToWordXML(_ attributedString: NSAttributedString) -> String {
        var xml = ""
        let string = attributedString.string
        let paragraphs = string.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for paragraph in paragraphs {
            let paragraphLength = (paragraph as NSString).length
            let paragraphRange = NSRange(location: currentLocation, length: paragraphLength)
            
            xml += "            <w:p>\n"
            
            if paragraphLength > 0 && currentLocation + paragraphLength <= attributedString.length {
                attributedString.enumerateAttributes(in: paragraphRange, options: []) { attributes, range, _ in
                    // Check for image attachments first
                    if let imageXML = generateImageXML(from: attributes) {
                        // Image occupies its own run
                        xml += "                <w:r>\n"
                        xml += imageXML
                        xml += "                </w:r>\n"
                        return
                    }
                    
                    let text = (attributedString.string as NSString).substring(with: range)
                    // Skip the U+FFFC replacement character (object replacement char for attachments)
                    let cleanText = text.replacingOccurrences(of: "\u{FFFC}", with: "")
                    guard !cleanText.isEmpty else { return }
                    let escapedText = escapeXML(cleanText)
                    
                    xml += "                <w:r>\n"
                    
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
                xml += "                <w:r><w:t></w:t></w:r>\n"
            }
            
            xml += "            </w:p>\n"
            currentLocation += paragraphLength + 1
        }
        
        return xml
    }
    
    // MARK: - Image Support
    
    /// Try to generate a DrawingML inline image element from attachment attributes.
    /// Returns nil if no image attachment is found.
    private func generateImageXML(from attributes: [NSAttributedString.Key: Any]) -> String? {
        let image: UIImage?
        var imageScale: CGFloat = 1.0
        var captionText: String?
        
        if let imageAttachment = attributes[.attachment] as? ImageAttachment {
            image = imageAttachment.image ?? (imageAttachment.imageData.flatMap { UIImage(data: $0) })
            imageScale = imageAttachment.scale
            if imageAttachment.hasCaption {
                let parts: [String] = [
                    imageAttachment.captionPrefix,
                    imageAttachment.captionNumber > 0 ? "\(imageAttachment.captionNumber)" : nil,
                    imageAttachment.captionText
                ].compactMap { $0?.isEmpty == false ? $0 : nil }
                if !parts.isEmpty {
                    captionText = parts.joined(separator: " ")
                }
            }
        } else if let genericAttachment = attributes[.attachment] as? NSTextAttachment {
            if let img = genericAttachment.image {
                image = img
            } else if let data = genericAttachment.contents {
                image = UIImage(data: data)
            } else if let fw = genericAttachment.fileWrapper, let data = fw.regularFileContents {
                image = UIImage(data: data)
            } else {
                return nil
            }
        } else {
            return nil
        }
        
        guard let resolvedImage = image else { return nil }
        
        // Calculate pixel dimensions
        let originalSize = resolvedImage.size
        var pixelWidth = originalSize.width * imageScale
        var pixelHeight = originalSize.height * imageScale
        
        if pixelWidth > maxImageDimension || pixelHeight > maxImageDimension {
            let factor = min(maxImageDimension / pixelWidth, maxImageDimension / pixelHeight)
            pixelWidth *= factor
            pixelHeight *= factor
        }
        
        // Render at target size and encode as JPEG
        let targetSize = CGSize(width: pixelWidth, height: pixelHeight)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            resolvedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.85) else { return nil }
        
        let relID = "rId\(nextRelID)"
        let imageFilename = "image\(nextRelID - 1).jpeg"
        nextRelID += 1
        
        #if DEBUG
        print("📷 DOCX: Embedding image \(imageFilename) (\(Int(pixelWidth))×\(Int(pixelHeight)), \(jpegData.count) bytes)")
        #endif
        
        collectedImages.append(DOCXImageEntry(
            relationshipID: relID,
            filename: imageFilename,
            data: jpegData,
            pixelWidth: Int(pixelWidth),
            pixelHeight: Int(pixelHeight)
        ))
        
        // OOXML dimensions are in EMU (English Metric Units): 1 inch = 914400 EMU
        // Assume 72 dpi: 1 pixel = 914400/72 = 12700 EMU
        let emuWidth = Int(pixelWidth) * 12700
        let emuHeight = Int(pixelHeight) * 12700
        
        var drawingXML = """
                        <w:drawing>
                            <wp:inline distT="0" distB="0" distL="0" distR="0">
                                <wp:extent cx="\(emuWidth)" cy="\(emuHeight)"/>
                                <wp:docPr id="\(collectedImages.count)" name="\(imageFilename)"/>
                                <a:graphic>
                                    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                                        <pic:pic>
                                            <pic:nvPicPr>
                                                <pic:cNvPr id="\(collectedImages.count)" name="\(imageFilename)"/>
                                                <pic:cNvPicPr/>
                                            </pic:nvPicPr>
                                            <pic:blipFill>
                                                <a:blip r:embed="\(relID)"/>
                                                <a:stretch>
                                                    <a:fillRect/>
                                                </a:stretch>
                                            </pic:blipFill>
                                            <pic:spPr>
                                                <a:xfrm>
                                                    <a:off x="0" y="0"/>
                                                    <a:ext cx="\(emuWidth)" cy="\(emuHeight)"/>
                                                </a:xfrm>
                                                <a:prstGeom prst="rect">
                                                    <a:avLst/>
                                                </a:prstGeom>
                                            </pic:spPr>
                                        </pic:pic>
                                    </a:graphicData>
                                </a:graphic>
                            </wp:inline>
                        </w:drawing>

        """
        
        // If there's a caption, add it as a separate paragraph after the image paragraph
        if let caption = captionText {
            drawingXML += """
                    </w:r>
                </w:p>
                <w:p>
                    <w:pPr><w:jc w:val="center"/></w:pPr>
                    <w:r>
                        <w:rPr><w:i/><w:sz w:val="20"/></w:rPr>
                        <w:t xml:space="preserve">\(escapeXML(caption))</w:t>

            """
        }
        
        return drawingXML
    }
    
    // MARK: - XML Helpers
    
    func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    // MARK: - DOCX Package (ZIP)
    
    func createDOCXPackage(documentXML: String, images: [DOCXImageEntry] = []) throws -> Data {
        // Content types — include jpeg if we have images
        var contentTypesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
        """
        if !images.isEmpty {
            contentTypesXML += """
            
                <Default Extension="jpeg" ContentType="image/jpeg"/>
            """
        }
        contentTypesXML += """
        
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
        
        let relsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
        
        // Document relationships — link to each image
        var docRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        """
        for img in images {
            docRelsXML += """
            
                <Relationship Id="\(img.relationshipID)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/\(img.filename)"/>
            """
        }
        docRelsXML += """
        
        </Relationships>
        """
        
        // Build file entries for the ZIP
        var files: [(path: String, data: Data)] = [
            ("[Content_Types].xml", contentTypesXML.data(using: .utf8)!),
            ("_rels/.rels", relsXML.data(using: .utf8)!),
            ("word/document.xml", documentXML.data(using: .utf8)!)
        ]
        
        // Only include word/_rels/document.xml.rels if we have images
        if !images.isEmpty {
            files.append(("word/_rels/document.xml.rels", docRelsXML.data(using: .utf8)!))
            for img in images {
                files.append(("word/media/\(img.filename)", img.data))
            }
        }
        
        // Build ZIP
        var zipData = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0
        
        for file in files {
            let data = file.data
            let path = file.path
            let pathData = path.data(using: .utf8)!
            
            // Local file header
            zipData.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            zipData.append(contentsOf: [0x14, 0x00]) // Version needed (2.0)
            zipData.append(contentsOf: [0x00, 0x00]) // Flags
            zipData.append(contentsOf: [0x00, 0x00]) // Compression (stored)
            zipData.append(contentsOf: [0x00, 0x00]) // Mod time
            zipData.append(contentsOf: [0x00, 0x00]) // Mod date
            
            let crc = calculateCRC32(data)
            zipData.append(contentsOf: UInt32(crc).littleEndianBytes)
            zipData.append(contentsOf: UInt32(data.count).littleEndianBytes)
            zipData.append(contentsOf: UInt32(data.count).littleEndianBytes)
            zipData.append(contentsOf: UInt16(pathData.count).littleEndianBytes)
            zipData.append(contentsOf: [0x00, 0x00]) // Extra field length
            
            zipData.append(pathData)
            zipData.append(data)
            
            // Central directory header
            centralDirectory.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            centralDirectory.append(contentsOf: [0x14, 0x00]) // Version made by
            centralDirectory.append(contentsOf: [0x14, 0x00]) // Version needed
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Flags
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Compression
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Mod time
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Mod date
            centralDirectory.append(contentsOf: UInt32(crc).littleEndianBytes)
            centralDirectory.append(contentsOf: UInt32(data.count).littleEndianBytes)
            centralDirectory.append(contentsOf: UInt32(data.count).littleEndianBytes)
            centralDirectory.append(contentsOf: UInt16(pathData.count).littleEndianBytes)
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Extra field length
            centralDirectory.append(contentsOf: [0x00, 0x00]) // File comment length
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Disk number start
            centralDirectory.append(contentsOf: [0x00, 0x00]) // Internal attributes
            centralDirectory.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // External attributes
            centralDirectory.append(contentsOf: offset.littleEndianBytes)
            centralDirectory.append(pathData)
            
            offset = UInt32(zipData.count)
        }
        
        let centralDirOffset = UInt32(zipData.count)
        zipData.append(centralDirectory)
        
        // End of central directory
        zipData.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        zipData.append(contentsOf: [0x00, 0x00]) // Disk number
        zipData.append(contentsOf: [0x00, 0x00]) // Disk with central dir
        zipData.append(contentsOf: UInt16(files.count).littleEndianBytes)
        zipData.append(contentsOf: UInt16(files.count).littleEndianBytes)
        zipData.append(contentsOf: UInt32(centralDirectory.count).littleEndianBytes)
        zipData.append(contentsOf: centralDirOffset.littleEndianBytes)
        zipData.append(contentsOf: [0x00, 0x00]) // Comment length
        
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
