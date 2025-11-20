import Foundation

/// Extension to TextFile model for version navigation and management
extension TextFile {
    
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
        return "Version \(currentVersionIndex + 1) of \(versions.count)"
    }
    
    /// Change version by offset (-1 for previous, +1 for next)
    func changeVersion(by offset: Int) {
        guard let versions = versions, !versions.isEmpty else {
            print("⚠️ changeVersion: No versions available")
            return
        }
        
        print("🔢 changeVersion called:")
        print("   - offset: \(offset)")
        print("   - current index: \(currentVersionIndex)")
        print("   - versions count: \(versions.count)")
        
        // Sort versions by version number to ensure consistent navigation
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        print("   - sorted versions: \(sortedVersions.map { $0.versionNumber })")
        
        // Calculate new index (currentVersionIndex is already in sorted order)
        let newIndex = currentVersionIndex + offset
        print("   - calculated new index: \(newIndex)")
        
        guard newIndex >= 0 && newIndex < sortedVersions.count else {
            print("   ❌ New index out of bounds")
            return
        }
        
        // Set new index directly (no conversion needed - we work in sorted space)
        self.currentVersionIndex = newIndex
        print("   ✅ Updated currentVersionIndex to: \(newIndex)")
        print("   - new version number: \(sortedVersions[newIndex].versionNumber)")
        print("   - new content length: \(sortedVersions[newIndex].content.count)")
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
        
        // Add to versions array
        if versions == nil {
            versions = []
        }
        versions?.append(newVersion)
        
        // Set as current version (last index)
        self.currentVersionIndex = (versions?.count ?? 1) - 1
    }
    
    /// Delete the current version (if more than one version exists)
    func deleteVersion() {
        guard let versions = versions, versions.count > 1 else { return }
        
        let currentIndex = currentVersionIndex
        
        // Remove current version
        if currentIndex < versions.count {
            self.versions?.remove(at: currentIndex)
        }
        
        // Adjust current version index
        if currentIndex > 0 {
            self.currentVersionIndex = currentIndex - 1
        } else {
            self.currentVersionIndex = 0
        }
    }
    
    /// Jump to the latest version (highest version number)
    func selectLatestVersion() {
        guard let versions = versions, !versions.isEmpty else { return }
        
        // Sort versions - latest is last in sorted array
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        
        // Set index to last position in sorted array
        self.currentVersionIndex = sortedVersions.count - 1
    }
}
