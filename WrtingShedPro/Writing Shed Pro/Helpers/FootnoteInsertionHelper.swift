//
//  FootnoteInsertionHelper.swift
//  Writing Shed Pro
//
//  Feature 017: Footnotes
//  Created by GitHub Copilot on 21/11/2025.
//

import Foundation
import UIKit
import SwiftData

/// Helper methods for inserting and managing footnote attachments in attributed text
struct FootnoteInsertionHelper {
    
    // MARK: - Insertion
    
    /// Insert a footnote attachment at the specified position
    /// - Parameters:
    ///   - attributedText: The attributed string to modify
    ///   - position: Character position where to insert the footnote
    ///   - footnoteText: The footnote text content
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: Tuple of (updated attributed string, created FootnoteModel)
    @MainActor
    static func insertFootnote(
        in attributedText: NSAttributedString,
        at position: Int,
        footnoteText: String,
        textFileID: UUID,
        context: ModelContext
    ) -> (NSAttributedString, FootnoteModel) {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Calculate the footnote number
        let number = FootnoteManager.shared.calculateFootnoteNumber(
            forTextFile: textFileID,
            at: position,
            context: context
        )
        
        // Create the footnote attachment
        let attachmentID = UUID()
        let attachment = FootnoteAttachment(footnoteID: attachmentID, number: number)
        
        // Create attributed string with the attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        
        // Insert at the specified position
        let safePosition = min(max(0, position), mutableText.length)
        mutableText.insert(attachmentString, at: safePosition)
        
        // Create the footnote model in the database
        let footnote = FootnoteManager.shared.createFootnote(
            textFileID: textFileID,
            characterPosition: safePosition,
            attachmentID: attachmentID,
            text: footnoteText,
            context: context
        )
        
        return (mutableText, footnote)
    }
    
    /// Insert a footnote at the current cursor position in a UITextView
    /// - Parameters:
    ///   - textView: The text view
    ///   - footnoteText: The footnote text content
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: The created FootnoteModel
    @MainActor
    @discardableResult
    static func insertFootnoteAtCursor(
        in textView: UITextView,
        footnoteText: String,
        textFileID: UUID,
        context: ModelContext
    ) -> FootnoteModel? {
        let textStorage = textView.textStorage
        
        let insertPosition = textView.selectedRange.location
        
        // Calculate the footnote number
        let number = FootnoteManager.shared.calculateFootnoteNumber(
            forTextFile: textFileID,
            at: insertPosition,
            context: context
        )
        
        // Create the footnote attachment
        let attachmentID = UUID()
        let attachment = FootnoteAttachment(footnoteID: attachmentID, number: number)
        
        // Create attributed string with the attachment
        let attachmentString = NSAttributedString(attachment: attachment)
        
        // Insert at cursor
        textStorage.insert(attachmentString, at: insertPosition)
        
        // Move cursor after the attachment
        textView.selectedRange = NSRange(location: insertPosition + 1, length: 0)
        
        // Create the footnote model in the database
        let footnote = FootnoteManager.shared.createFootnote(
            textFileID: textFileID,
            characterPosition: insertPosition,
            attachmentID: attachmentID,
            text: footnoteText,
            context: context
        )
        
        return footnote
    }
    
    // MARK: - Updating
    
    /// Update a footnote attachment's number
    /// - Parameters:
    ///   - attributedText: The attributed string containing the footnote
    ///   - footnoteID: ID of the footnote to update
    ///   - newNumber: New footnote number
    /// - Returns: Updated attributed string
    static func updateFootnoteNumber(
        in attributedText: NSAttributedString,
        footnoteID: UUID,
        newNumber: Int
    ) -> NSAttributedString {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Find the footnote attachment
        if let (attachment, range) = attributedText.footnoteAttachment(withID: footnoteID) {
            // Update the number
            attachment.number = newNumber
            
            // Create new attachment string with updated number
            let newAttachmentString = NSAttributedString(attachment: attachment)
            
            // Replace the old attachment
            mutableText.replaceCharacters(in: range, with: newAttachmentString)
            
            print("📝🔄 Updated footnote \(footnoteID) to number \(newNumber)")
        }
        
        return mutableText
    }
    
    /// Update all footnote numbers in attributed text based on database state
    /// - Parameters:
    ///   - attributedText: The attributed string
    ///   - textFileID: ID of the text file
    ///   - context: SwiftData model context
    /// - Returns: Updated attributed string
    @MainActor
    static func updateAllFootnoteNumbers(
        in attributedText: NSAttributedString,
        forTextFile textFileID: UUID,
        context: ModelContext
    ) -> NSAttributedString {
        var mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Get all footnotes from database
        let footnotes = FootnoteManager.shared.getActiveFootnotes(forTextFile: textFileID, context: context)
        
        // Update each footnote attachment
        for footnote in footnotes {
            if let (attachment, range) = mutableText.footnoteAttachment(withID: footnote.id) {
                // Check if number needs updating
                if attachment.number != footnote.number {
                    // Update the attachment
                    attachment.number = footnote.number
                    
                    // Create new attachment string
                    let newAttachmentString = NSAttributedString(attachment: attachment)
                    
                    // Replace the old attachment
                    mutableText.replaceCharacters(in: range, with: newAttachmentString)
                    
                    print("📝🔄 Updated footnote \(footnote.id) to number \(footnote.number) at position \(range.location)")
                }
            }
        }
        
        return mutableText
    }
    
    // MARK: - Removal
    
    /// Remove a footnote attachment from attributed text
    /// - Parameters:
    ///   - attributedText: The attributed string containing the footnote
    ///   - footnoteID: ID of the footnote to remove
    /// - Returns: Updated attributed string
    static func removeFootnote(
        from attributedText: NSAttributedString,
        footnoteID: UUID
    ) -> NSAttributedString {
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Find the footnote attachment
        if let (_, range) = attributedText.footnoteAttachment(withID: footnoteID) {
            // Remove the attachment
            mutableText.deleteCharacters(in: range)
            
            print("📝🗑️ Removed footnote \(footnoteID) from text")
        }
        
        return mutableText
    }
    
    /// Remove a footnote attachment from a UITextView
    /// - Parameters:
    ///   - textView: The text view
    ///   - footnoteID: ID of the footnote to remove
    /// - Returns: The range where the footnote was removed (for cursor positioning)
    static func removeFootnoteFromTextView(
        _ textView: UITextView,
        footnoteID: UUID
    ) -> NSRange? {
        let textStorage = textView.textStorage
        
        // Find the footnote attachment
        if let (_, range) = textStorage.footnoteAttachment(withID: footnoteID) {
            // Delete the attachment
            textStorage.deleteCharacters(in: range)
            
            print("📝🗑️ Removed footnote \(footnoteID) from text view at position \(range.location)")
            
            return range
        }
        
        return nil
    }
    
    // MARK: - Query
    
    /// Find the footnote attachment at a specific position
    /// - Parameters:
    ///   - attributedText: The attributed string to search
    ///   - position: Character position to check
    /// - Returns: The footnote attachment and its ID if found
    static func footnoteAttachment(
        in attributedText: NSAttributedString,
        at position: Int
    ) -> (FootnoteAttachment, UUID)? {
        guard position >= 0 && position < attributedText.length else {
            return nil
        }
        
        let attributes = attributedText.attributes(at: position, effectiveRange: nil)
        
        if let attachment = attributes[.attachment] as? FootnoteAttachment {
            return (attachment, attachment.footnoteID)
        }
        
        return nil
    }
    
    /// Get all footnote positions in the attributed text
    /// - Parameter attributedText: The attributed string
    /// - Returns: Array of (footnote ID, position) tuples
    static func getAllFootnotePositions(
        in attributedText: NSAttributedString
    ) -> [(UUID, Int)] {
        let attachments = attributedText.footnoteAttachments()
        return attachments.map { (attachment, range) in
            (attachment.footnoteID, range.location)
        }
    }
}
