import Foundation
import SwiftData

class ProjectDataService {
    let modelContainer: ModelContainer
    let context: ModelContext
    
    init() throws {
        let schema = Schema([Project.self, File.self, Folder.self])
        self.modelContainer = try ModelContainer(for: schema)
        self.context = modelContainer.mainContext
    }
    
    // MARK: - Project CRUD
    func addProject(_ project: Project) throws {
        context.insert(project)
        try context.save()
    }
    
    func fetchProjects() throws -> [Project] {
        let fetchDescriptor = FetchDescriptor<Project>()
        return try context.fetch(fetchDescriptor)
    }
    
    func deleteProject(_ project: Project) throws {
        context.delete(project)
        try context.save()
    }
    
    // MARK: - File/Folder CRUD can be added similarly
}
