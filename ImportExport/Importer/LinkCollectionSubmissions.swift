//
//  LinkCollectionSubmissions.swift
//  Write!
//
//  Created by Keith Lander on 26/11/2021.
//

import Foundation

extension ProjectImporter {
    func linkCollectionSubmissions(project: Project, projectData: WritingShedData) {
        var submissions = [Submission]()
        projectData.collectionComponentDatas.forEach({ collectionComponentData in
            if collectionComponentData.type == kSubmissionEntity {
                collectionComponentData.collectionSubmissionsDatas?.forEach({ csd in
                    submissions.append(Write_.decode(csd.collectionSubmission))
                })
                var links = [String]()
                if collectionComponentData.submissionSubmissionIds != nil {
                    do {
                        links = try PropertyListDecoder().decode([String].self,
                                                                 from: collectionComponentData.submissionSubmissionIds!)
                    } catch {
                    }
                }
                if links.count > 0 {
                    var folder = MyCoreData.getEntity("Folder",
                                                      withImported: imported(collectionComponentData.id)) as? Folder
                    if folder == nil {
                        folder = decode(collectionComponentData.collectionComponent)
                    }
                    folder!.notes = decodeString(attributeData: collectionComponentData.notes,
                                                     text: collectionComponentData.notesText).string
                    links.forEach { link in
                        let cs = submissions.first { cse in
                            cse.imported == link
                        }
                        folder!.submission = cs!
                    }
                }
            } else {
                var links = [String]()
                do {
                    links = try PropertyListDecoder().decode([String].self,
                                                             from: collectionComponentData.collectionSubmissionIds!)
                } catch {
                }
                if links.count > 0 {
                    var folder =
                    MyCoreData.getEntity("Folder",
                                         withImported: imported(collectionComponentData.id)) as? Folder
                    if folder == nil {
                        folder = Write_.decode(collectionComponentData.collectionComponent)
                    }
                    folder!.notes = decodeString(attributeData: collectionComponentData.notes,
                                                 text: collectionComponentData.notesText).string
                    let id = findParent(for: folder!)
                    let parent: Folder? = Folder.getFolder(id: id, in: ProjectImporter.theProject!)
                    if parent != nil {
                        folder?.parent = parent
                        if folder!.parent?.kind == FolderKind.publications.rawValue {
                            folder!.kind = FolderKind.submissions.rawValue
                        }
                        links.forEach { link in
                            let cs = submissions.first { cse in
                                cse.imported == link
                            }
                            folder!.submission = cs!
                        }
                    }
                }
            }
        })
    }

    private func findParent(for folder: Folder) -> String {
        var result: String?
        if folder.id == "09FC58CD-6803-4780-96BC-CC54DB542050" {
        print(folder.id)
        }

        for collectionComponentData in projectData!.collectionComponentDatas {
            if collectionComponentData.collectionSubmissionsDatas != nil {
                let csd = collectionComponentData.collectionSubmissionsDatas?.first(where: { csd in
                    print("**" + csd.collectionId + "--" + csd.submissionId)
                    return csd.collectionId == folder.id
                })
                if csd != nil {
                    result = csd?.submissionId
                    break
                }
            }
        }
        return result!
    }
}
