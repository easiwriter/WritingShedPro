//
//  SceneComponentData.swift
//  Writing Shed
//
//  Created by Keith Lander on 20/09/2021.
//  Copyright © 2021 www.writing-shed.com. All rights reserved.
//
//  FIXED VERSION - Corrects logic bug in scene encoding
//

import Foundation

class SceneComponentData: Codable {
    var type: String
    var id: String
    var sceneComponent: String
    var scenes: Data?
    
    init(id: String, sceneComponent: String, type: String) {
        self.type = type
        self.id = id
        self.sceneComponent = sceneComponent
    }
    
    // FIX: Changed logic from count == 0 to count > 0
    func addScenes(_ scenes: NSSet?) {
        guard let scenes = scenes, scenes.count > 0 else {
            self.scenes = Data()
            return
        }
        var sids = [String]()
        scenes.forEach { scene in
            let se = scene as! WS_Scene_Entity
            sids.append(ProjectExporter.newProjectName! + se.uniqueIdentifier!)
        }
        do {
            self.scenes = try PropertyListEncoder().encode(sids)
        } catch {
            fatalError("Error encoding: \(error)")
        }
    }
}
