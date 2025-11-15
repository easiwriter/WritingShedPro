//
//  Importer.swift
//  Writing Shed
//
//  Created by Keith Lander on 20/09/2021.
//  Copyright © 2021 www.writing-shed.com. All rights reserved.
//

import Foundation

public enum ImportError: Error {
    case success, noContent, duplicateProject, corruptData, noName, noType
}

@objc class ProjectImporter: NSObject {
    var projectData: WritingShedData?
    var project: Project?
    static var theProject: Project?

    func imported(_ id: String) -> String {
        return project!.name! + id
    }

    /// Import a project
    /// - Parameters:
    ///   - contents: exported file conents
    ///   - completion: call back to a completion function which saves the project and makes it current
    func performImport(_ contents: String, completion: (String, Error) -> Void) {
        if contents.isEmpty {
            completion("", ImportError.noContent)
        }
        let decoder = JSONDecoder()
        do {
            guard let data = contents.data(using: String.Encoding.utf8) else {
                completion("", ImportError.corruptData)
                return
            }
            projectData = try decoder.decode(WritingShedData.self, from: data)
        } catch {
            completion("", ImportError.corruptData)
        }
        let isDuplicate = Project.isDuplicate(projectData!.projectName)
        if isDuplicate {
            guard let name = projectData?.projectName else {
                completion("", ImportError.noName)
                return
            }
            completion(name, ImportError.duplicateProject)
        }
        let tempProject: Project = Write_.decode(projectData!.project)
        let templates = Project.loadTemplates()
        let template = templates.first { project in
            project.name == tempProject.type
        }
        guard let template = template else {
            fatalError(ErrorDetails("template not found)"))
        }
        project = Project.clone(template: template, with: tempProject.name!, asTemplate: false)
        guard let project = project, let projectData = projectData else {
            fatalError(ErrorDetails("Missing project"))
        }
        ProjectImporter.theProject = project
        project.timeStamp = tempProject.timeStamp
        project.targetWordCount = 150000
        project.type = tempProject.type
        project.lastUpdated = tempProject.lastUpdated
        importCollectionComponentDatas(project: project, projectData: projectData)
        importSceneComponentDatas(project: project, projectData: projectData)
        importTextFileDatas(project: project, projectData: projectData)
        linkSceneComponents(project: project, projectData: projectData)
        linkCollectionSubmissions(project: project, projectData: projectData)
        linkCollectionTexts(project: project, projectData: projectData)
        MyCoreData.updateImportedEntities(for: project)
        moc().save(with: .addProject)
        completion(project.name ?? "Untitled", ImportError.success)
    }
}
