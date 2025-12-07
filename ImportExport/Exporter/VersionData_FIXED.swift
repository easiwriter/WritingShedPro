//
//  VersionData.swift
//  Writing Shed
//
//  Created by Keith Lander on 20/09/2021.
//  Copyright © 2021 www.writing-shed.com. All rights reserved.
//
//  FIXED VERSION - Corrects bugs in version and notes encoding
//

import Foundation

class VersionData: Codable {
    var type = kVersionEntity
    var id: String
    var version: String
    var notes: Data
    var notesText: String
    var textString: String?
    var quickfile: Bool = false
    var textFile: Data
    var text: String
    var collectedVersionData: [CollectedVersionData]?
    
    init(id: String, version: WS_Version_Entity) {
        self.id = id
        self.version = Writing_Shed.encode(version)
        self.textString = Writing_Shed.encode(version.textString)
        
        // FIX 1: Properly handle text file encoding
        var theTextFile = NSAttributedString()
        if let textFileObj = version.textString?.textFile as? NSAttributedString {
            // Rich text content - encode as attributed string
            theTextFile = textFileObj
            self.textFile = encodeString(text: theTextFile)
            self.text = theTextFile.string
            self.quickfile = false
        } else if let textFileData = version.textString?.textFile as? Data {
            // Already encoded as Data (quickfile) - use directly
            self.textFile = textFileData
            self.text = ""
            self.quickfile = true
        } else {
            // Fallback: empty content
            self.textFile = encodeString(text: NSAttributedString())
            self.text = ""
            self.quickfile = false
        }
        
        // FIX 2: CRITICAL BUG FIX - Actually use the version notes!
        // Original code had: if version.notes != nil { theNotes = NSAttributedString() }
        // This created an EMPTY string instead of using the actual notes
        var theNotes = NSAttributedString()
        if let versionNotes = version.notes as? NSAttributedString {
            theNotes = versionNotes  // ✅ Use the actual notes content
        }
        self.notes = encodeString(text: theNotes)
        self.notesText = theNotes.string
        
        self.collectedVersionData = [CollectedVersionData]()
    }
        
    func addCollectedVersion(collectedVersion: WS_CollectedVersion_Entity) {
        let cv = Writing_Shed.encode(collectedVersion)
        let cvd = CollectedVersionData(id: collectedVersion.uniqueIdentifier!,
                                       collectedVersion: cv)
        self.collectedVersionData?.append(cvd)
    }
}

class CollectedVersionData: Codable {
    var type = kCollectedVersionEntity
    var id: String
    var collectedVersion: String
    
    init(id: String, collectedVersion: String) {
        self.id = id
        self.collectedVersion = collectedVersion
    }
}

class TextStringData: Codable {
    var type = kTextStringEntity
    var id: String
    var textString: String
    var textAttributes: Data
    var text: String
    
    init(id: String, textString: String, textAttributes: Data, text: String) {
        self.id = id
        self.textString = textString
        self.textAttributes = textAttributes
        self.text = text
    }
}
