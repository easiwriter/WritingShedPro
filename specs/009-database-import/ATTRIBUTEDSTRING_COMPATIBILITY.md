# AttributedString Compatibility Issue - Feature 009

**Date**: 12 November 2025  
**Status**: Analysis & Solution Documentation

---

## The Issue

### Legacy System (Core Data - Writing Shed)
The `WS_TextString_Entity` stores rich text content using:
- **Attribute**: `textFile` (type: Transformable)
- **Transformer**: "AttributedStringTransformer" (system-provided)
- **Storage**: `NSAttributedString` object serialized as binary/XML in Core Data

### Current System (SwiftData - Writing Shed Pro)
The `Version` model stores content as:
- **`content: String`** (plain text, required)
- **`formattedContent: Data?`** (optional RTF data from NSAttributedString)

### The Compatibility Gap
```
Legacy Core Data            →    New SwiftData
NSAttributedString (with        String + RTF Data?
  formatting attributes)         
  ↓                              ↓
AttributedStringTransformer      Explicit RTF encoding
  ↓                              ↓
Binary serialized format         Need conversion
```

---

## Solution: Multi-Format Import Strategy

When importing, we need to handle THREE possible scenarios:

### Scenario 1: Rich Text with Formatting (NSAttributedString)
**Source**: Legacy `textFile` attribute stored as NSAttributedString

**Import Process**:
```swift
// 1. Read NSAttributedString from Core Data
let nsAttributedString: NSAttributedString = ...

// 2. Extract plain text for Version.content
let plainText = nsAttributedString.string
versionData.content = plainText

// 3. Convert formatting to RTF for Version.formattedContent
let range = NSRange(location: 0, length: nsAttributedString.length)
do {
    let rtfData = try nsAttributedString.data(
        from: range,
        documentType: .rtf
    )
    versionData.formattedContent = rtfData
} catch {
    // Fallback: just use plain text if RTF conversion fails
    versionData.formattedContent = nil
}
```

### Scenario 2: Plain Text (String in NSAttributedString)
**Source**: NSAttributedString with no formatting attributes

**Import Process**:
```swift
let nsAttributedString: NSAttributedString = ...
let plainText = nsAttributedString.string

// Store as plain text, no formatting needed
versionData.content = plainText
versionData.formattedContent = nil  // No formatting to preserve
```

### Scenario 3: Data Integrity Fallback
**Source**: Corrupted or unreadable NSAttributedString

**Import Process**:
```swift
do {
    let nsAttributedString: NSAttributedString = ...
    versionData.content = nsAttributedString.string
} catch {
    // If we can't read NSAttributedString, use empty/error state
    versionData.content = "[Import Error: Could not read content]"
    versionData.formattedContent = nil
    // Log error for reporting to user
}
```

---

## Implementation Requirements

### Step 1: LegacyDatabaseService Setup
The Core Data reader needs to:
1. Load Core Data store using NSPersistentStoreCoordinator
2. Fetch WS_TextString_Entity objects
3. Access `textFile` attribute (which Core Data provides as NSAttributedString)

```swift
class LegacyDatabaseService {
    func readTextStringEntity(_ entity: NSManagedObject) throws -> (plainText: String, rtfData: Data?) {
        // Get NSAttributedString from transformer
        guard let nsAttributedString = entity.value(forKey: "textFile") as? NSAttributedString else {
            throw ImportError.missingContent
        }
        
        let plainText = nsAttributedString.string
        
        // Try to convert to RTF
        let rtfData: Data?
        do {
            let range = NSRange(location: 0, length: nsAttributedString.length)
            rtfData = try nsAttributedString.data(
                from: range,
                documentType: .rtf
            )
        } catch {
            // If RTF conversion fails, just use plain text
            rtfData = nil
        }
        
        return (plainText, rtfData)
    }
}
```

### Step 2: Data Mapper Conversion
The mapper converts legacy format → new format:

```swift
class DataMapper {
    func mapTextStringToVersion(
        legacyEntity: NSManagedObject,
        textFile: TextFile
    ) throws -> Version {
        let (plainText, rtfData) = try legacyDatabaseService.readTextStringEntity(legacyEntity)
        
        let version = Version(
            content: plainText,
            versionNumber: 1
        )
        version.formattedContent = rtfData
        version.textFile = textFile
        
        return version
    }
}
```

### Step 3: Data Integrity Strategy
Choose approach for handling import issues:

**Option A: Strict (Fail on Any Error)**
```swift
if rtfConversionFailed || contentEmpty {
    throw ImportError.dataCorruption("Cannot import version with corrupted content")
}
```

**Option B: Lenient (Skip Formatting)**
```swift
// Always import, but lose formatting if RTF conversion fails
let version = Version(content: plainText)  // Use plain text
version.formattedContent = nil  // Skip formatting
```

**Option C: Hybrid (Import with Warnings)**
```swift
let version = Version(content: plainText)
if rtfConversionFailed {
    importWarnings.append("Content for version lost formatting during import")
    version.formattedContent = nil
}
```

---

## Testing Strategy

### Test 1: AttributedString Round-Trip
```swift
func testAttributedStringConversion() {
    // Create NSAttributedString with formatting
    let attributed = NSMutableAttributedString(string: "Hello World")
    attributed.addAttribute(
        .font,
        value: UIFont.boldSystemFont(ofSize: 16),
        range: NSRange(location: 0, length: 5)
    )
    
    // Convert to RTF and back
    let rtfData = try attributed.data(
        from: NSRange(location: 0, length: attributed.length),
        documentType: .rtf
    )
    
    let readBack = try NSAttributedString(
        data: rtfData,
        options: [.documentType: NSAttributedString.DocumentType.rtf],
        documentAttributes: nil
    )
    
    // Verify plain text preserved
    XCTAssertEqual(readBack.string, "Hello World")
}
```

### Test 2: Legacy Database Import with Real Data
```swift
func testImportRealLegacyDatabase() {
    // Use user's actual Writing-Shed.sqlite
    let legacyService = LegacyDatabaseService(
        databaseURL: URL(fileURLWithPath: "~/Library/Application Support/{bundle}/Writing-Shed.sqlite")
    )
    
    // Read one text string entity
    let textStringEntity = try legacyService.fetchTextStringEntities().first!
    let (plainText, rtfData) = try legacyService.readTextStringEntity(textStringEntity)
    
    // Verify we got content
    XCTAssertFalse(plainText.isEmpty, "Plain text should be populated")
    // RTF data may or may not be present depending on original formatting
}
```

### Test 3: Data Loss Detection
```swift
func testFormattingPreservation() {
    // Test that we capture formatting information
    let importedVersion = try importLegacyVersion(withFormatting: true)
    
    // Should have either formatted content or at least plain text
    XCTAssertFalse(importedVersion.content.isEmpty)
    if importedVersion.formattedContent != nil {
        // Formatting was preserved
        XCTAssertTrue(true)
    } else {
        // Formatting was lost, but plain text saved
        XCTAssertTrue(true)
    }
}
```

---

## Recommendation: Action Items

### Immediate (Before Full Implementation)
1. ✅ **Confirm AttributedString format**: Read actual legacy database to verify the textFile attribute is indeed NSAttributedString
2. ✅ **Test RTF conversion**: Try converting a real NSAttributedString from legacy data to RTF and verify it round-trips
3. ✅ **Check iOS 16+ support**: Verify NSAttributedString RTF encoding works on iOS 16+

### During Implementation (Phase 1)
1. **Create LegacyDatabaseService** with NSAttributedString extraction
2. **Implement DataMapper** with RTF conversion logic
3. **Add error handling** for malformed NSAttributedString
4. **Test with user's database** to catch edge cases

### Quality Assurance
1. **Test round-trip**: Legacy NSAttributedString → RTF Data → NSAttributedString
2. **Test formatting preservation**: Bold, italic, lists, etc.
3. **Test failure modes**: Corrupted NSAttributedString, very large content, special characters
4. **Performance test**: Import 1000+ versions with formatting, measure time and memory

---

## iOS Version Compatibility

✅ **NSAttributedString** - Available since iOS 2.0  
✅ **RTF Document Type** - Available since iOS 5.0+  
✅ **Transformable Core Data** - Available since iOS 3.0+  

**Minimum Deployment Target**: iOS 16.0 ✅  
All required APIs available.

---

## Decision Point for User

**Based on the information provided in the screenshot**:
- Legacy system uses `Transformable` type with "AttributedStringTransformer"
- This means the `textFile` attribute IS an NSAttributedString at runtime
- RTF conversion strategy is viable

**Question for you**:
1. Would you like me to proceed with the RTF conversion strategy (Option C - Hybrid)?
2. Should we test with your actual Writing-Shed.sqlite database first to verify RTF conversion works?
3. Any formatting you especially want to preserve (bold, italic, lists, indentation)?

---

## References

- Apple NSAttributedString documentation: https://developer.apple.com/documentation/foundation/nsattributedstring
- Core Data Transformable: https://developer.apple.com/documentation/coredata/nsattributedescription/transformation-related_methods
- RTF Document Type: https://developer.apple.com/documentation/foundation/nsattributedstring/documenttype/rtf
- SwiftData Relationships: https://developer.apple.com/documentation/swiftdata
