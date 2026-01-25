import Foundation

/// Represents a poetry form with its structural requirements and template
/// Used for smart poetry creation in Poetry projects
struct PoetryForm: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let category: PoetryFormCategory
    let lineCount: Int?
    let stanzaCount: Int?  // Number of stanzas (separated by blank lines)
    let syllablePattern: [Int]?
    let rhymeScheme: String?
    let meterPattern: String?
    let description: String
    let templateContent: String
    let isCustom: Bool
    
    // MARK: - Computed Properties
    
    /// Whether this form has syllable count requirements per line
    var hasSyllableRequirements: Bool {
        syllablePattern != nil && !(syllablePattern?.isEmpty ?? true)
    }
    
    /// Whether this form has meter/stress pattern requirements
    var hasMeterRequirements: Bool {
        meterPattern != nil && !(meterPattern?.isEmpty ?? true)
    }
    
    /// Whether this form has a rhyme scheme
    var hasRhymeScheme: Bool {
        rhymeScheme != nil && !(rhymeScheme?.isEmpty ?? true)
    }
    
    /// Whether this form has a specific line count requirement
    var hasLineCountRequirement: Bool {
        lineCount != nil && lineCount! > 0
    }
    
    /// Whether this form has a specific stanza count requirement
    var hasStanzaCountRequirement: Bool {
        stanzaCount != nil && stanzaCount! > 0
    }
    
    /// A short summary of the form's requirements for display
    var requirementsSummary: String {
        var parts: [String] = []
        
        if let lines = lineCount {
            parts.append("\(lines) lines")
        }
        
        if let stanzas = stanzaCount {
            parts.append("\(stanzas) stanzas")
        }
        
        if let syllables = syllablePattern, !syllables.isEmpty {
            let syllableStr = syllables.map { String($0) }.joined(separator: "-")
            parts.append(syllableStr + " syllables")
        }
        
        if let rhyme = rhymeScheme, !rhyme.isEmpty {
            parts.append(rhyme)
        }
        
        if let meter = meterPattern, !meter.isEmpty {
            parts.append(meter)
        }
        
        return parts.isEmpty ? "No specific requirements" : parts.joined(separator: " • ")
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        category: PoetryFormCategory,
        lineCount: Int? = nil,
        stanzaCount: Int? = nil,
        syllablePattern: [Int]? = nil,
        rhymeScheme: String? = nil,
        meterPattern: String? = nil,
        description: String,
        templateContent: String = "",
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.lineCount = lineCount
        self.stanzaCount = stanzaCount
        self.syllablePattern = syllablePattern
        self.rhymeScheme = rhymeScheme
        self.meterPattern = meterPattern
        self.description = description
        self.templateContent = templateContent
        self.isCustom = isCustom
    }
}

// MARK: - Poetry Form Category

/// Categories for grouping poetry forms in the picker
enum PoetryFormCategory: String, Codable, CaseIterable {
    case japanese = "Japanese"
    case rhymed = "Rhymed"
    case metered = "Metered"
    case free = "Free"
    case custom = "Custom"
    
    var displayName: String {
        rawValue
    }
    
    var sortOrder: Int {
        switch self {
        case .japanese: return 0
        case .rhymed: return 1
        case .metered: return 2
        case .free: return 3
        case .custom: return 4
        }
    }
}

// MARK: - Predefined Form IDs

/// Well-known UUIDs for predefined forms (enables consistent references)
extension PoetryForm {
    static let freeVerseId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let haikuId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let tankaId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let sonnetShakespeareanId = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let sonnetPetrarchanId = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let limerickId = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    static let villanelleId = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    static let ghazalId = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
    static let blankVerseId = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
    static let customId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    static let cinquainId = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    static let sestinaId = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    static let pantoumId = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
    static let trioletId = UUID(uuidString: "00000000-0000-0000-0000-000000000014")!
    static let balladId = UUID(uuidString: "00000000-0000-0000-0000-000000000015")!
    static let ottavaRimaId = UUID(uuidString: "00000000-0000-0000-0000-000000000016")!
    static let terzaRimaId = UUID(uuidString: "00000000-0000-0000-0000-000000000017")!
    static let spenserianStanzaId = UUID(uuidString: "00000000-0000-0000-0000-000000000018")!
}
