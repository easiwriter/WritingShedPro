# Feature 018: Automatic Paragraph Numbering - Data Model

## Core Models

### NumberingSettings
Numbering configuration for each paragraph style:

```swift
struct NumberingSettings: Codable, Hashable {
    var enabled: Bool = false
    var format: NumberingFormat = .numeric
    var adornment: NumberingAdornment = .plain
    var startingNumber: Int = 1
    var resetBehavior: ResetBehavior = .never
    var customPrefix: String? = nil
    var customSuffix: String? = nil
    var indentLevel: Int = 0
    var parentStyleID: String? = nil  // For hierarchical nesting
}

enum NumberingFormat: String, Codable, CaseIterable {
    case none
    case numeric           // 1, 2, 3...
    case alphabeticUpper  // A, B, C...
    case alphabeticLower  // a, b, c...
    case romanUpper       // I, II, III...
    case romanLower       // i, ii, iii...
    case bullet           // •, ◦, ▪...
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .numeric: return "1, 2, 3"
        case .alphabeticUpper: return "A, B, C"
        case .alphabeticLower: return "a, b, c"
        case .romanUpper: return "I, II, III"
        case .romanLower: return "i, ii, iii"
        case .bullet: return "• ◦ ▪"
        }
    }
}

enum NumberingAdornment: String, Codable, CaseIterable {
    case plain            // 1
    case period           // 1.
    case parentheses      // (1)
    case rightParen       // 1)
    case dashes          // -1-
    case custom          // Uses customPrefix/Suffix
    
    var displayName: String {
        switch self {
        case .plain: return "1"
        case .period: return "1."
        case .parentheses: return "(1)"
        case .rightParen: return "1)"
        case .dashes: return "-1-"
        case .custom: return "Custom"
        }
    }
    
    func format(number: String, prefix: String?, suffix: String?) -> String {
        switch self {
        case .plain: return number
        case .period: return "\(number)."
        case .parentheses: return "(\(number))"
        case .rightParen: return "\(number))"
        case .dashes: return "-\(number)-"
        case .custom: return "\(prefix ?? "")\(number)\(suffix ?? "")"
        }
    }
}

enum ResetBehavior: String, Codable, CaseIterable {
    case never           // Never reset counter
    case onParentChange  // Reset when parent style changes
    case onSection       // Reset at section boundaries
    case onChapter       // Reset at chapter boundaries
    
    var displayName: String {
        switch self {
        case .never: return "Never"
        case .onParentChange: return "On Parent Change"
        case .onSection: return "On Section"
        case .onChapter: return "On Chapter"
        }
    }
}
```

### ParagraphStyle Extension
Add numbering settings to existing ParagraphStyle:

```swift
extension ParagraphStyle {
    var numberingSettings: NumberingSettings? = nil
    
    var hasNumbering: Bool {
        numberingSettings?.enabled ?? false
    }
    
    func formattedNumber(for counter: Int) -> String? {
        guard let settings = numberingSettings, settings.enabled else { return nil }
        
        let rawNumber = formatNumber(counter, using: settings.format)
        return settings.adornment.format(
            number: rawNumber,
            prefix: settings.customPrefix,
            suffix: settings.customSuffix
        )
    }
}
```

### DocumentNumberingState
SwiftData model to track numbering state per document:

```swift
@Model
final class DocumentNumberingState {
    @Attribute(.unique) var id: UUID = UUID()
    var documentID: UUID  // Reference to FileEntry
    var lastUpdate: Date = Date()
    
    // Counter state for each style
    // Key: styleID, Value: array of counters for each nesting level
    var styleCounters: [String: [Int]] = [:]
    
    // Track paragraph order for correct numbering
    var paragraphOrder: [UUID] = []  // Paragraph IDs in order
    
    init(documentID: UUID) {
        self.documentID = documentID
    }
    
    func counter(for styleID: String, level: Int = 0) -> Int {
        styleCounters[styleID, default: []].indices.contains(level)
            ? styleCounters[styleID]![level]
            : 1
    }
    
    mutating func incrementCounter(for styleID: String, level: Int = 0) {
        if !styleCounters.keys.contains(styleID) {
            styleCounters[styleID] = [1]
        }
        
        while styleCounters[styleID]!.count <= level {
            styleCounters[styleID]!.append(1)
        }
        
        styleCounters[styleID]![level] += 1
        lastUpdate = Date()
    }
    
    mutating func resetCounter(for styleID: String, level: Int = 0) {
        if let _ = styleCounters[styleID], level < styleCounters[styleID]!.count {
            styleCounters[styleID]![level] = 1
        } else {
            styleCounters[styleID] = [1]
        }
        lastUpdate = Date()
    }
    
    mutating func resetAllCounters() {
        styleCounters.removeAll()
        lastUpdate = Date()
    }
}
```

### ParagraphNumberingInfo
Runtime struct to store per-paragraph numbering information:

```swift
struct ParagraphNumberingInfo: Codable {
    var formattedNumber: String        // Display number (e.g., "1.2.3")
    var rawValue: Int                  // Actual counter value
    var level: Int                     // Nesting level (0-based)
    var styleID: String                // Associated style
    var isOverridden: Bool = false     // Manual override flag
    var overrideValue: String?         // Custom number if overridden
    
    var displayNumber: String {
        isOverridden ? (overrideValue ?? formattedNumber) : formattedNumber
    }
}
```

## Manager Classes

### NumberingManager
Singleton to manage all numbering operations:

```swift
class NumberingManager {
    static let shared = NumberingManager()
    
    private var documentStates: [UUID: DocumentNumberingState] = [:]
    
    // Get or create numbering state for document
    func state(for documentID: UUID) -> DocumentNumberingState {
        if let existing = documentStates[documentID] {
            return existing
        }
        let newState = DocumentNumberingState(documentID: documentID)
        documentStates[documentID] = newState
        return newState
    }
    
    // Generate formatted number for paragraph
    func formattedNumber(
        for style: ParagraphStyle,
        in documentID: UUID,
        level: Int = 0
    ) -> String? {
        guard let settings = style.numberingSettings, settings.enabled else { return nil }
        
        var state = state(for: documentID)
        let counter = state.counter(for: style.id, level: level)
        
        return formatNumber(counter, settings: settings, level: level)
    }
    
    // Update numbering after document change
    func updateNumbering(for documentID: UUID, paragraphs: [ParagraphInfo]) {
        var state = state(for: documentID)
        state.resetAllCounters()
        
        for paragraph in paragraphs {
            guard let style = paragraph.style, style.hasNumbering else { continue }
            state.incrementCounter(for: style.id, level: paragraph.level)
        }
        
        documentStates[documentID] = state
    }
    
    // Format number based on settings
    private func formatNumber(_ value: Int, settings: NumberingSettings, level: Int) -> String {
        let raw = convertNumber(value, to: settings.format)
        return settings.adornment.format(
            number: raw,
            prefix: settings.customPrefix,
            suffix: settings.customSuffix
        )
    }
    
    // Convert integer to specified format
    private func convertNumber(_ value: Int, to format: NumberingFormat) -> String {
        switch format {
        case .none: return ""
        case .numeric: return "\(value)"
        case .alphabeticUpper: return toAlphabetic(value, uppercase: true)
        case .alphabeticLower: return toAlphabetic(value, uppercase: false)
        case .romanUpper: return toRoman(value, uppercase: true)
        case .romanLower: return toRoman(value, uppercase: false)
        case .bullet: return bulletForLevel(level: value - 1)
        }
    }
}
```

## Format Conversion Utilities

```swift
extension NumberingManager {
    // Convert to alphabetic (1 -> A, 2 -> B, 26 -> Z, 27 -> AA)
    func toAlphabetic(_ value: Int, uppercase: Bool) -> String {
        let base = uppercase ? "A" : "a"
        let offset = base.unicodeScalars.first!.value
        
        var result = ""
        var num = value - 1
        
        repeat {
            let char = UnicodeScalar(offset + UInt32(num % 26))!
            result = String(char) + result
            num = num / 26 - 1
        } while num >= 0
        
        return result
    }
    
    // Convert to roman numerals
    func toRoman(_ value: Int, uppercase: Bool) -> String {
        let romanMap: [(Int, String)] = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]
        
        var result = ""
        var remaining = value
        
        for (num, roman) in romanMap {
            while remaining >= num {
                result += roman
                remaining -= num
            }
        }
        
        return uppercase ? result : result.lowercased()
    }
    
    // Get bullet character for nesting level
    func bulletForLevel(level: Int) -> String {
        let bullets = ["•", "◦", "▪", "‣", "⁃"]
        return bullets[level % bullets.count]
    }
}
```

## Serialization

### AttributedString Storage
Store numbering info in custom attributes:

```swift
extension AttributedString {
    struct NumberingInfoKey: AttributedStringKey {
        typealias Value = ParagraphNumberingInfo
        static let name = "numberingInfo"
    }
    
    var numberingInfo: ParagraphNumberingInfo? {
        get { self[NumberingInfoKey.self] }
        set { self[NumberingInfoKey.self] = newValue }
    }
}
```

### JSON Export
Include numbering in document export:

```swift
struct ExportedParagraph: Codable {
    var text: String
    var styleID: String
    var numberingInfo: ParagraphNumberingInfo?
}
```

## CloudKit Sync
DocumentNumberingState syncs via CloudKit:
- Counters sync across devices
- Conflicts resolved by latest timestamp
- Reset operations sync immediately
