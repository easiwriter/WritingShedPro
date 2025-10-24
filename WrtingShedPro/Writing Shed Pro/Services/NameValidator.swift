import Foundation

enum ValidationError: Error, LocalizedError, Equatable {
    case emptyName(entity: String)
    case invalidCharacters(entity: String)
    
    var errorDescription: String? {
        switch self {
        case .emptyName(let entity):
            if entity == "Project" {
                return NSLocalizedString("validation.emptyProjectName", comment: "Error when project name is empty")
            } else if entity == "File" {
                return NSLocalizedString("validation.emptyFileName", comment: "Error when file name is empty")
            } else if entity == "Folder" {
                return NSLocalizedString("validation.emptyFolderName", comment: "Error when folder name is empty")
            }
            return "\(entity) name cannot be empty."
        case .invalidCharacters(let entity):
            return "\(entity) name contains invalid characters."
        }
    }
}

struct NameValidator {
    static func validateProjectName(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyName(entity: "Project")
        }
    }
    
    static func validateFileName(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyName(entity: "File")
        }
    }
    
    static func validateFolderName(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyName(entity: "Folder")
        }
    }
}
