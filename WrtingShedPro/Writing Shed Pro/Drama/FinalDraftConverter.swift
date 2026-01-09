//
//  FinalDraftConverter.swift
//  Writing Shed Pro
//
//  Feature 023: Smart Drama Creation
//  Import/Export support for Final Draft XML format (.fdx)
//

import Foundation

/// Converter between DML (Drama Markup Language) and Final Draft XML format (.fdx)
/// Final Draft is the industry-standard screenwriting software
final class FinalDraftConverter {
    
    // MARK: - Singleton
    
    static let shared = FinalDraftConverter()
    
    private init() {}
    
    // MARK: - Import (FDX → DML)
    
    /// Convert Final Draft XML to DML
    /// - Parameter fdxData: Final Draft XML data
    /// - Returns: DML-formatted text, or nil if parsing failed
    func fdxToDML(_ fdxData: Data) -> String? {
        guard let parser = FDXParser(data: fdxData) else {
            return nil
        }
        return parser.parseToDML()
    }
    
    /// Convert Final Draft XML string to DML
    /// - Parameter fdxString: Final Draft XML string
    /// - Returns: DML-formatted text, or nil if parsing failed
    func fdxToDML(_ fdxString: String) -> String? {
        guard let data = fdxString.data(using: .utf8) else {
            return nil
        }
        return fdxToDML(data)
    }
    
    // MARK: - Export (DML → FDX)
    
    /// Convert DML to Final Draft XML
    /// - Parameters:
    ///   - dml: DML-formatted text
    ///   - title: Optional document title
    /// - Returns: Final Draft XML string
    func dmlToFDX(_ dml: String, title: String = "Untitled") -> String {
        let document = DramaMarkupParser.shared.parse(dml)
        return generateFDX(from: document, title: title)
    }
    
    /// Convert DML to Final Draft XML data
    /// - Parameters:
    ///   - dml: DML-formatted text
    ///   - title: Optional document title
    /// - Returns: Final Draft XML data
    func dmlToFDXData(_ dml: String, title: String = "Untitled") -> Data? {
        let xml = dmlToFDX(dml, title: title)
        return xml.data(using: .utf8)
    }
    
    // MARK: - FDX Generation
    
    private func generateFDX(from document: DMLDocument, title: String) -> String {
        var paragraphs: [String] = []
        
        for element in document.elements {
            guard let paragraph = generateParagraph(for: element) else { continue }
            paragraphs.append(paragraph)
        }
        
        let content = paragraphs.joined(separator: "\n")
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="5">
            <Content>
                \(content)
            </Content>
            <TitlePage>
                <Content>
                    <Paragraph Type="Title Page">
                        <Text>\(escapeXML(title))</Text>
                    </Paragraph>
                </Content>
            </TitlePage>
        </FinalDraft>
        """
    }
    
    private func generateParagraph(for element: DMLElement) -> String? {
        let type: String
        let text: String
        
        switch element.type {
        case .sceneHeading:
            type = "Scene Heading"
            text = element.content
            
        case .action:
            type = "Action"
            text = element.content
            
        case .character:
            type = "Character"
            text = element.content
            
        case .parenthetical:
            type = "Parenthetical"
            text = element.content
            
        case .dialogue:
            type = "Dialogue"
            text = element.content
            
        case .transition:
            type = "Transition"
            text = element.content
            
        case .note:
            type = "Script Note"
            text = element.noteText ?? element.content
            
        case .locationMeta, .timeMeta:
            // Store as general text or skip
            return nil
            
        case .blank:
            return nil
        }
        
        return """
                <Paragraph Type="\(type)">
                    <Text>\(escapeXML(text))</Text>
                </Paragraph>
        """
    }
    
    private func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - FDX Parser

/// XML Parser for Final Draft files
private class FDXParser: NSObject, XMLParserDelegate {
    
    private let parser: XMLParser
    private var dmlLines: [String] = []
    private var currentElement: String = ""
    private var currentText: String = ""
    private var currentParagraphType: String = ""
    private var inContent = false
    private var inParagraph = false
    private var inText = false
    
    init?(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        parser.delegate = self
    }
    
    func parseToDML() -> String? {
        guard parser.parse() else {
            return nil
        }
        return dmlLines.joined(separator: "\n")
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, 
                namespaceURI: String?, qualifiedName qName: String?, 
                attributes attributeDict: [String: String] = [:]) {
        
        currentElement = elementName
        
        switch elementName {
        case "Content":
            inContent = true
            
        case "Paragraph":
            inParagraph = true
            currentParagraphType = attributeDict["Type"] ?? ""
            currentText = ""
            
        case "Text":
            inText = true
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText && inParagraph {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, 
                namespaceURI: String?, qualifiedName qName: String?) {
        
        switch elementName {
        case "Content":
            inContent = false
            
        case "Paragraph":
            if inContent {
                addDMLLine()
            }
            inParagraph = false
            currentParagraphType = ""
            currentText = ""
            
        case "Text":
            inText = false
            
        default:
            break
        }
    }
    
    private func addDMLLine() {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let dmlLine: String
        
        switch currentParagraphType.lowercased() {
        case "scene heading", "slug line":
            // Add # prefix if not already an INT./EXT. heading
            if text.hasPrefix("INT.") || text.hasPrefix("EXT.") || text.hasPrefix("INT/EXT") {
                dmlLine = "# \(text)"
            } else {
                dmlLine = "# \(text)"
            }
            
        case "action", "general":
            dmlLine = "> \(text)"
            
        case "character":
            dmlLine = text.uppercased()
            
        case "parenthetical":
            // Ensure it has parentheses
            if text.hasPrefix("(") && text.hasSuffix(")") {
                dmlLine = text
            } else {
                dmlLine = "(\(text))"
            }
            
        case "dialogue":
            dmlLine = text
            
        case "transition":
            dmlLine = ">> \(text)"
            
        case "script note":
            dmlLine = "[[\(text)]]"
            
        default:
            // Unknown type - treat as action
            dmlLine = "> \(text)"
        }
        
        dmlLines.append(dmlLine)
    }
}
