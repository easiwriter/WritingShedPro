# Writing Shed Export Bug Fixes

## Overview
Fixed critical bugs in the Writing Shed v1 JSON export code that prevented proper import into Writing Shed Pro.

## Bugs Found and Fixed

### 1. VersionData.swift - Critical Notes Bug (Line 26-30)

**Original Code:**
```swift
var theNotes = NSAttributedString()
if version.notes != nil {
    theNotes = NSAttributedString()  // ❌ BUG: Creates EMPTY string
}
self.notes = encodeString(text: theNotes)
```

**Problem:** When version notes exist, the code creates a NEW empty NSAttributedString instead of using the actual notes content. This means ALL version notes are lost during export.

**Fixed Code:**
```swift
var theNotes = NSAttributedString()
if let versionNotes = version.notes as? NSAttributedString {
    theNotes = versionNotes  // ✅ Use actual notes
}
self.notes = encodeString(text: theNotes)
```

---

### 2. VersionData.swift - Text File Handling (Line 19-31)

**Original Code:**
```swift
var theTextFile = NSAttributedString()
if (version.textString?.textFile) is NSAttributedString {
    theTextFile = (version.textString?.textFile) as! NSAttributedString
    self.textFile = encodeString(text: theTextFile)
    self.text = theTextFile.string
}
else {
    quickfile = true
    self.text = ""
    self.textFile = (version.textString?.textFile) as! Data
}
```

**Problem:** The else branch force-casts to Data which could crash if the type is unexpected.

**Fixed Code:**
```swift
var theTextFile = NSAttributedString()
if let textFileObj = version.textString?.textFile as? NSAttributedString {
    // Rich text content
    theTextFile = textFileObj
    self.textFile = encodeString(text: theTextFile)
    self.text = theTextFile.string
    self.quickfile = false
} else if let textFileData = version.textString?.textFile as? Data {
    // Already encoded as Data (quickfile)
    self.textFile = textFileData
    self.text = ""
    self.quickfile = true
} else {
    // Fallback: empty content
    self.textFile = encodeString(text: NSAttributedString())
    self.text = ""
    self.quickfile = false
}
```

---

### 3. CollectionComponentData.swift - Logic Errors

**Multiple methods had incorrect guard conditions:**

**Original Code:**
```swift
func addCollectionSubmissions(_ collectionSubmissions: NSSet?) -> [CollectionSubmissionData] {
    var result = [CollectionSubmissionData]()
    guard let cSubmissions = collectionSubmissions, cSubmissions.count == 0 else {
        //                                                              ↑↑ BUG!
        self.collectionSubmissionsDatas = [CollectionSubmissionData]()
        return result
    }
    // Process submissions...
}
```

**Problem:** `count == 0` means "if empty, process items" which is backwards. Should be `count > 0`.

**Fixed in these methods:**
- `addCollectionSubmissions()` - Line 35
- `addCollectionSubmissionIds()` - Line 57
- `addSubmissionSubmissionIds()` - Line 71
- `addCollectedTextIds()` - Line 95

**Fixed Code:**
```swift
guard let cSubmissions = collectionSubmissions, cSubmissions.count > 0 else {
    // Return empty if no submissions
    self.collectionSubmissionsDatas = [CollectionSubmissionData]()
    return result
}
```

---

### 4. CollectionSubmissionData - Missing Fields

**Original Code:**
```swift
class CollectionSubmissionData:Codable {
    var type = kCollectionSubmissionEntity
    var id:String
    var collectionSubmission:String
    
    init(id:String, collectionSubmission:String) {
        self.id = id
        self.collectionSubmission = collectionSubmission
    }
}
```

**Problem:** Import service expects `submissionId` and `collectionId` fields (see JSONImportService.swift line 728).

**Fixed Code:**
```swift
class CollectionSubmissionData: Codable {
    var type = kCollectionSubmissionEntity
    var id: String
    var submissionId: String  // ✅ Added
    var collectionId: String  // ✅ Added
    var collectionSubmission: String
    
    init(id: String, submissionId: String, collectionId: String, collectionSubmission: String) {
        self.id = id
        self.submissionId = submissionId
        self.collectionId = collectionId
        self.collectionSubmission = collectionSubmission
    }
}
```

---

### 5. TextCollectionData.swift - Same Logic Error

**Original Code:**
```swift
func addCollectedVersionIds(_ collectedVersions:NSSet?) {
    guard let collectedVersions = collectedVersions, collectedVersions.count == 0 else {
        //                                                                    ↑↑ BUG!
        collectedVersionIds = Data()
        return
    }
```

**Fixed Code:**
```swift
guard let collectedVersions = collectedVersions, collectedVersions.count > 0 else {
```

---

### 6. SceneComponentData.swift - Same Logic Error

**Original Code:**
```swift
func addScenes(_ scenes: NSSet?) {
    guard let scenes = scenes, scenes.count == 0 else {
        //                                     ↑↑ BUG!
        self.scenes = Data()
        return
    }
```

**Fixed Code:**
```swift
guard let scenes = scenes, scenes.count > 0 else {
```

---

## Summary of Changes

| File | Bug Type | Impact |
|------|----------|--------|
| VersionData.swift | Empty notes creation | **CRITICAL** - All version notes lost |
| VersionData.swift | Unsafe force cast | **HIGH** - Potential crashes |
| CollectionComponentData.swift | Inverted logic (4 methods) | **HIGH** - Collections not exported |
| CollectionSubmissionData | Missing fields | **HIGH** - Import fails |
| TextCollectionData.swift | Inverted logic | **MEDIUM** - Text collections incomplete |
| SceneComponentData.swift | Inverted logic | **MEDIUM** - Scene data incomplete |

---

## Files to Replace

Replace these files in Writing Shed v1:

1. `Writing Shed Models/ImportExport/VersionData.swift` → `VersionData_FIXED.swift`
2. `Writing Shed Models/ImportExport/CollectionComponentData.swift` → `CollectionComponentData_FIXED.swift`
3. `Writing Shed Models/ImportExport/TextCollectionData.swift` → `TextCollectionData_FIXED.swift`
4. `Writing Shed Models/ImportExport/SceneComponentData.swift` → `SceneComponentData_FIXED.swift`

---

## Testing Recommendations

After applying fixes:

1. **Export a test project** with:
   - Multiple text files
   - Multiple versions per file
   - Version notes (to verify notes bug is fixed)
   - Collections with submissions
   - Scene components (characters/locations)

2. **Import into Writing Shed Pro** and verify:
   - All text files imported
   - All versions present
   - **Version notes are NOT empty** (critical test)
   - Collections and submissions linked correctly
   - Scene components linked correctly

3. **Compare exported JSON** before/after fixes:
   - Check `versions[].notes` field is not empty Data
   - Check `versions[].notesText` contains actual text
   - Check collection arrays are populated when data exists

---

## Root Cause Analysis

The bugs appear to stem from:

1. **Copy-paste error** in VersionData (line 28) - someone likely copy-pasted line 27 instead of using the actual notes
2. **Logic inversion** in guard statements - multiple files have `count == 0` when they should check `count > 0`
3. **Incomplete struct definition** - CollectionSubmissionData missing required fields that the import service expects

These are systematic bugs that would cause ALL exports to be incomplete/incorrect.
