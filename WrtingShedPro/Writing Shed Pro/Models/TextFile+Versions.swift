import Foundation

/// Extension to TextFile model for version navigation and management
extension TextFile {
    
    /// Check if currently at the first version
    func atFirstVersion() -> Bool {
        guard let versions = versions, !versions.isEmpty else { return true }
        guard let currentVersion = currentVersion else { return true }
        
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        return currentVersion.id == sortedVersions.first?.id
    }
    
    /// Check if currently at the last version
    func atLastVersion() -> Bool {
        guard let versions = versions, !versions.isEmpty else { return true }
        guard let currentVersion = currentVersion else { return true }
        
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        return currentVersion.id == sortedVersions.last?.id
    }
    
    /// Get label for current version
    func versionLabel() -> String {
        guard let versions = versions, !versions.isEmpty else { return "No versions" }
        guard let currentVersion = currentVersion else { return "No current version" }
        
        let sortedVersions = versions.sorted { $0.versionNumber < $1.versionNumber }
        if let index = sortedVersions.firstIndex(where: { $0.id == currentVersion.id }) {
            return "Version \(index + 1) of \(sortedVersions.count)"
        }
        return "Version ?"
    }
    
    /// Change version by offset (-1 for previous, +1 for next)
    func changeVersion(by offset: Int) {
        guard let versions = versions, !versions.isEmpty else { return }
        
        let newIndex = currentVersionIndex + offset
        guard newIndex >= 0 && newIndex < versions.count else { return }
        
        self.currentVersionIndex = newIndex
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
}
