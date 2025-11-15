# Quick Setup: JSON Import Document Types

## Option 1: Via Xcode UI (Recommended)

1. Open `Writing Shed Pro.xcodeproj` in Xcode
2. Select the project in Navigator (top blue icon)
3. Select **"Writing Shed Pro"** target
4. Click **"Info"** tab
5. Scroll to **"Document Types"** section (or add it)
6. Click **"+"** to add a new document type:

```
Name:             Writing Shed Export
Identifier:       com.writingshed.export
Types:            public.json
Role:             Viewer
Handler Rank:     Alternate
```

7. Build and run (Cmd+R)

## Option 2: Edit Info.plist

If Info.plist exists in your project, add:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Writing Shed Export</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.json</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
    </dict>
</array>
```

## Option 3: No Configuration Needed (iOS 14+)

The code uses `.fileImporter(allowedContentTypes: [.json])` which works without explicit document type declarations on modern iOS. The configuration above just provides better integration with the Files app.

## Test It

1. Run the app
2. Tap the Import button (down arrow with document)
3. File picker should appear
4. Select a `.json` file
5. Project imports and appears in list

If the file picker doesn't filter to JSON files, complete the Xcode configuration above.

## See Also

- `JSON_IMPORT_CONFIGURATION.md` - Complete documentation
- `JSON_IMPORT.md` - JSONImportService technical details
