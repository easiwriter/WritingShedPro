import Foundation

/// Extension to TextFile model for version navigation and management
extension TextFile {
    private func markVersionStateChanged(flushImmediately: Bool = false) {
        modifiedDate = Date()
        Task { @MainActor in
            if flushImmediately {
                WriteCoalescer.shared?.requestSave()
                WriteCoalescer.shared?.flush()
            } else {
                WriteCoalescer.shared?.requestSave()
            }
        }
    }
    
    /// Check if currently at the first version
    func atFirstVersion() -> Bool {
        guard let versions = versions, !versions.isEmpty else { return true }
        
        // currentVersionIndex is in sorted space - first is index 0
        return currentVersionIndex == 0
    }
    
    /// Check if currently at the last version
    func atLastVersion() -> Bool {
        guard let versions = versions, !versions.isEmpty else { return true }
        
        // currentVersionIndex is in sorted space - last is count - 1
        return currentVersionIndex >= versions.count - 1
    }
    
    /// Get label for current version
    func versionLabel() -> String {
        guard let versions = versions, !versions.isEmpty else { return "No versions" }
        
        // currentVersionIndex is in sorted space - use it directly
        // Display as 1-based for user (index 0 = "Version 1")
        return "v\(currentVersionIndex + 1)/\(versions.count)"
    }
    
    /// Change version by offset (-1 for previous, +1 for next)
    func changeVersion(by offset: Int) {
        guard let versions = versions, !versions.isEmpty else {
            #if DEBUG
            print("⚠️ changeVersion: No versions available")
            #endif
            return
        }
        
        #if DEBUG
        print("🔢 changeVersion called:")
        #endif
        #if DEBUG
        print("   - offset: \(offset)")
        #endif
        #if DEBUG
        print("   - current index: \(currentVersionIndex)")
        #endif
        #if DEBUG
        print("   - versions count: \(versions.count)")
        #endif
        
        // Sort versions by version number to ensure consistent navigation
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        #if DEBUG
        print("   - sorted versions: \(sortedVersions.map { $0.versionNumber })")
        #endif
        
        // Calculate new index (currentVersionIndex is already in sorted order)
        let newIndex = currentVersionIndex + offset
        #if DEBUG
        print("   - calculated new index: \(newIndex)")
        #endif
        
        guard newIndex >= 0 && newIndex < sortedVersions.count else {
            #if DEBUG
            print("   ❌ New index out of bounds")
            #endif
            return
        }
        
        // Set new index directly (no conversion needed - we work in sorted space)
        self.currentVersionIndex = newIndex
        markVersionStateChanged()
        #if DEBUG
        print("   ✅ Updated currentVersionIndex to: \(newIndex)")
        #endif
        #if DEBUG
        print("   - new version number: \(sortedVersions[newIndex].versionNumber)")
        #endif
        #if DEBUG
        print("   - new content length: \(sortedVersions[newIndex].content.count)")
        #endif
    }
    
    /// Add a new version (duplicate current version)
    func addVersion() {
        guard let currentVersion = currentVersion else { return }
        
        // Get highest version number
        let maxVersionNumber = versions?.map { $0.versionNumber }.max() ?? 0
        
        // Create new version with duplicated content
        let newVersion = Version(
            content: currentVersion.content,
            versionNumber: maxVersionNumber + 1
        )
        newVersion.attributedContent = currentVersion.attributedContent
        newVersion.textFile = self
        
        // Duplicate comments from current version
        if let currentComments = currentVersion.comments {
            for comment in currentComments {
                let newComment = CommentModel(
                    version: newVersion,
                    characterPosition: comment.characterPosition,
                    attachmentID: comment.attachmentID,
                    text: comment.text,
                    author: comment.author,
                    createdAt: comment.createdAt,
                    resolvedAt: comment.resolvedAt
                )
                if newVersion.comments == nil {
                    newVersion.comments = []
                }
                newVersion.comments?.append(newComment)
            }
        }
        
        // Duplicate footnotes from current version
        if let currentFootnotes = currentVersion.footnotes {
            for footnote in currentFootnotes {
                let newFootnote = FootnoteModel(
                    version: newVersion,
                    characterPosition: footnote.characterPosition,
                    attachmentID: footnote.attachmentID,
                    text: footnote.text,
                    number: footnote.number
                )
                if newVersion.footnotes == nil {
                    newVersion.footnotes = []
                }
                newVersion.footnotes?.append(newFootnote)
            }
        }
        
        // Add to versions array
        if versions == nil {
            versions = []
        }
        versions?.append(newVersion)
        
        // Set as current version (last index)
        self.currentVersionIndex = (versions?.count ?? 1) - 1
        markVersionStateChanged()
    }
    
    /// Delete the current version (if more than one version exists)
    func deleteVersion() {
        guard let versions = versions, versions.count > 1 else { return }
        
        // CRITICAL: Sort versions to match navigation - currentVersionIndex refers to sorted position
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        
        #if DEBUG
        print("📝 deleteVersion called:")
        print("   currentVersionIndex: \(currentVersionIndex)")
        print("   versions count: \(versions.count)")
        print("   unsorted versions: \(versions.map { "v\($0.versionNumber)" })")
        print("   sorted versions: \(sortedVersions.map { "v\($0.versionNumber)" })")
        #endif
        
        var deleteIndex = currentVersionIndex
        if deleteIndex < 0 || deleteIndex >= sortedVersions.count {
            #if DEBUG
            print("   ⚠️ currentVersionIndex out of bounds; clamping to latest version")
            #endif
            deleteIndex = max(0, sortedVersions.count - 1)
            currentVersionIndex = deleteIndex
        }
        
        // Get the actual version object to delete
        let versionToDelete = sortedVersions[deleteIndex]
        
        #if DEBUG
        print("   versionToDelete: v\(versionToDelete.versionNumber) (id: \(versionToDelete.id))")
        #endif
        
        // Find its index in the unsorted array and remove it
        if let actualIndex = self.versions?.firstIndex(where: { $0.id == versionToDelete.id }) {
            #if DEBUG
            print("   actualIndex in unsorted array: \(actualIndex)")
            #endif
            self.versions?.remove(at: actualIndex)
            // CRITICAL: Must hard-delete from the persistent store so CloudKit exports a deletion.
            // Removing from the relationship array alone leaves the Version record in the DB,
            // which CloudKit will re-import and re-attach, causing the version to reappear.
            self.modelContext?.delete(versionToDelete)
            #if DEBUG
            print("   ✅ Removed version at index \(actualIndex) and deleted from store (will flush immediately)")
            print("   remaining versions: \(self.versions?.map { "v\($0.versionNumber)" } ?? [])")
            #endif
        } else if let fallbackIndex = self.versions?.firstIndex(where: { $0.versionNumber == versionToDelete.versionNumber }) {
            #if DEBUG
            print("   ⚠️ Could not match by id, using versionNumber fallback at index \(fallbackIndex)")
            #endif
            let fallbackVersion = self.versions?[fallbackIndex]
            self.versions?.remove(at: fallbackIndex)
            if let fallbackVersion {
                self.modelContext?.delete(fallbackVersion)
            }
        } else {
            #if DEBUG
            print("   ❌ Could not find version in array")
            #endif
        }
        
        // Adjust current version index to stay in bounds
        let newCount = (self.versions?.count ?? 0)
        if currentVersionIndex >= newCount {
            self.currentVersionIndex = max(0, newCount - 1)
        }
        // CRITICAL: flush=true ensures the deletion is persisted immediately, not deferred.
        // A deferred save risks a resurrection if any code re-reads versions from the store
        // before the flush fires, or if CloudKit imports before the deletion export is queued.
        markVersionStateChanged(flushImmediately: true)
        #if DEBUG
        print("   new currentVersionIndex: \(currentVersionIndex)")
        #endif
    }
    
    /// Jump to the latest version (highest version number)
    func selectLatestVersion() {
        guard let versions = versions, !versions.isEmpty else { return }
        
        // Sort versions - latest is last in sorted array
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        
        // Set index to last position in sorted array
        self.currentVersionIndex = sortedVersions.count - 1
        markVersionStateChanged()
    }
}
