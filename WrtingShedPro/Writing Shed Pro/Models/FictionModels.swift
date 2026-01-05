//
//  FictionModels.swift
//  Writing Shed Pro
//
//  Feature 022: Smart Fiction Creation
//  Models for fiction projects including scenes, chapters, characters, locations, and plot elements
//

import Foundation
import SwiftData

// MARK: - Enums

/// The class of fiction project - determines structure
enum FictionClass: String, Codable, CaseIterable {
    case novel       // Long fiction with chapters containing scenes
    case shortFiction // Short fiction with scenes directly (no chapters)
    
    var localizedName: String {
        switch self {
        case .novel:
            return NSLocalizedString("fictionClass.novel", comment: "Novel fiction class")
        case .shortFiction:
            return NSLocalizedString("fictionClass.shortFiction", comment: "Short Fiction class")
        }
    }
}

/// Character archetypes from The Writer's Journey (Christopher Vogler)
enum CharacterArchetype: String, Codable, CaseIterable {
    case hero
    case mentor
    case herald
    case thresholdGuardian
    case shapeshifter
    case shadow
    case ally
    case trickster
    
    var localizedName: String {
        switch self {
        case .hero:
            return NSLocalizedString("archetype.hero", comment: "Hero archetype")
        case .mentor:
            return NSLocalizedString("archetype.mentor", comment: "Mentor archetype")
        case .herald:
            return NSLocalizedString("archetype.herald", comment: "Herald archetype")
        case .thresholdGuardian:
            return NSLocalizedString("archetype.thresholdGuardian", comment: "Threshold Guardian archetype")
        case .shapeshifter:
            return NSLocalizedString("archetype.shapeshifter", comment: "Shapeshifter archetype")
        case .shadow:
            return NSLocalizedString("archetype.shadow", comment: "Shadow archetype")
        case .ally:
            return NSLocalizedString("archetype.ally", comment: "Ally archetype")
        case .trickster:
            return NSLocalizedString("archetype.trickster", comment: "Trickster archetype")
        }
    }
    
    var description: String {
        switch self {
        case .hero:
            return NSLocalizedString("archetype.hero.description", comment: "Hero description")
        case .mentor:
            return NSLocalizedString("archetype.mentor.description", comment: "Mentor description")
        case .herald:
            return NSLocalizedString("archetype.herald.description", comment: "Herald description")
        case .thresholdGuardian:
            return NSLocalizedString("archetype.thresholdGuardian.description", comment: "Threshold Guardian description")
        case .shapeshifter:
            return NSLocalizedString("archetype.shapeshifter.description", comment: "Shapeshifter description")
        case .shadow:
            return NSLocalizedString("archetype.shadow.description", comment: "Shadow description")
        case .ally:
            return NSLocalizedString("archetype.ally.description", comment: "Ally description")
        case .trickster:
            return NSLocalizedString("archetype.trickster.description", comment: "Trickster description")
        }
    }
}

/// The 12 stages of the monomyth (Hero's Journey)
enum MonomythStage: String, Codable, CaseIterable {
    case ordinaryWorld
    case callToAdventure
    case refusalOfTheCall
    case meetingTheMentor
    case crossingTheThreshold
    case testsAlliesEnemies
    case approachToTheInmostCave
    case ordeal
    case reward
    case theRoadBack
    case resurrection
    case returnWithTheElixir
    
    var localizedName: String {
        switch self {
        case .ordinaryWorld:
            return NSLocalizedString("monomyth.ordinaryWorld", comment: "Ordinary World stage")
        case .callToAdventure:
            return NSLocalizedString("monomyth.callToAdventure", comment: "Call to Adventure stage")
        case .refusalOfTheCall:
            return NSLocalizedString("monomyth.refusalOfTheCall", comment: "Refusal of the Call stage")
        case .meetingTheMentor:
            return NSLocalizedString("monomyth.meetingTheMentor", comment: "Meeting the Mentor stage")
        case .crossingTheThreshold:
            return NSLocalizedString("monomyth.crossingTheThreshold", comment: "Crossing the Threshold stage")
        case .testsAlliesEnemies:
            return NSLocalizedString("monomyth.testsAlliesEnemies", comment: "Tests, Allies, Enemies stage")
        case .approachToTheInmostCave:
            return NSLocalizedString("monomyth.approachToTheInmostCave", comment: "Approach to the Inmost Cave stage")
        case .ordeal:
            return NSLocalizedString("monomyth.ordeal", comment: "Ordeal stage")
        case .reward:
            return NSLocalizedString("monomyth.reward", comment: "Reward stage")
        case .theRoadBack:
            return NSLocalizedString("monomyth.theRoadBack", comment: "The Road Back stage")
        case .resurrection:
            return NSLocalizedString("monomyth.resurrection", comment: "Resurrection stage")
        case .returnWithTheElixir:
            return NSLocalizedString("monomyth.returnWithTheElixir", comment: "Return with the Elixir stage")
        }
    }
    
    var description: String {
        switch self {
        case .ordinaryWorld:
            return NSLocalizedString("monomyth.ordinaryWorld.description", comment: "Ordinary World description")
        case .callToAdventure:
            return NSLocalizedString("monomyth.callToAdventure.description", comment: "Call to Adventure description")
        case .refusalOfTheCall:
            return NSLocalizedString("monomyth.refusalOfTheCall.description", comment: "Refusal of the Call description")
        case .meetingTheMentor:
            return NSLocalizedString("monomyth.meetingTheMentor.description", comment: "Meeting the Mentor description")
        case .crossingTheThreshold:
            return NSLocalizedString("monomyth.crossingTheThreshold.description", comment: "Crossing the Threshold description")
        case .testsAlliesEnemies:
            return NSLocalizedString("monomyth.testsAlliesEnemies.description", comment: "Tests, Allies, Enemies description")
        case .approachToTheInmostCave:
            return NSLocalizedString("monomyth.approachToTheInmostCave.description", comment: "Approach to the Inmost Cave description")
        case .ordeal:
            return NSLocalizedString("monomyth.ordeal.description", comment: "Ordeal description")
        case .reward:
            return NSLocalizedString("monomyth.reward.description", comment: "Reward description")
        case .theRoadBack:
            return NSLocalizedString("monomyth.theRoadBack.description", comment: "The Road Back description")
        case .resurrection:
            return NSLocalizedString("monomyth.resurrection.description", comment: "Resurrection description")
        case .returnWithTheElixir:
            return NSLocalizedString("monomyth.returnWithTheElixir.description", comment: "Return with the Elixir description")
        }
    }
    
    /// Order in the hero's journey (1-12)
    var order: Int {
        switch self {
        case .ordinaryWorld: return 1
        case .callToAdventure: return 2
        case .refusalOfTheCall: return 3
        case .meetingTheMentor: return 4
        case .crossingTheThreshold: return 5
        case .testsAlliesEnemies: return 6
        case .approachToTheInmostCave: return 7
        case .ordeal: return 8
        case .reward: return 9
        case .theRoadBack: return 10
        case .resurrection: return 11
        case .returnWithTheElixir: return 12
        }
    }
}

// MARK: - Models

/// A scene is the fundamental unit of storytelling in fiction projects
@Model
final class FictionScene {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?  // Brief description of what happens
    var monomythStageRaw: String?  // Optional monomyth stage assignment
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    @Relationship(inverse: \FictionChapter.scenes)
    var chapter: FictionChapter?  // nil for Short Fiction projects
    
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \TextFile.scene)
    var textFile: TextFile?  // Contains the actual scene content
    
    // Many-to-many with PlotElement
    var plotElements: [PlotElement]?
    
    // Scene can have multiple characters
    @Relationship(inverse: \FictionCharacter.scenes)
    var characters: [FictionCharacter]?
    
    // Scene takes place at a location
    @Relationship(inverse: \FictionLocation.scenes)
    var location: FictionLocation?
    
    var monomythStage: MonomythStage? {
        get { 
            guard let raw = monomythStageRaw else { return nil }
            return MonomythStage(rawValue: raw) 
        }
        set { monomythStageRaw = newValue?.rawValue }
    }
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}

/// A chapter is a container for scenes (Novel fiction class only)
@Model
final class FictionChapter {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .nullify)
    var scenes: [FictionScene]?
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}

/// A character in the fiction project
@Model
final class FictionCharacter {
    var id: UUID = UUID()
    var name: String?
    var role: String?  // Character's role in the story (protagonist, love interest, etc.)
    var archetypeRaw: String?  // Only used when monomyth enabled
    var biography: String?  // Character background and notes
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \CustomAttribute.character)
    var customAttributes: [CustomAttribute]?
    
    // Scenes this character appears in (many-to-many)
    var scenes: [FictionScene]?
    
    var archetype: CharacterArchetype? {
        get { 
            guard let raw = archetypeRaw else { return nil }
            return CharacterArchetype(rawValue: raw) 
        }
        set { archetypeRaw = newValue?.rawValue }
    }
    
    init(name: String? = nil, role: String? = nil, archetype: CharacterArchetype? = nil, biography: String? = nil) {
        self.name = name
        self.role = role
        self.archetypeRaw = archetype?.rawValue
        self.biography = biography
    }
}

/// A location where scenes take place
@Model
final class FictionLocation {
    var id: UUID = UUID()
    var name: String?
    var locationDescription: String?  // Description of the location
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \CustomAttribute.location)
    var customAttributes: [CustomAttribute]?
    
    // Scenes that take place at this location
    var scenes: [FictionScene]?
    
    init(name: String? = nil, description: String? = nil) {
        self.name = name
        self.locationDescription = description
    }
}

/// A custom key-value attribute for characters or locations
@Model
final class CustomAttribute {
    var id: UUID = UUID()
    var key: String?
    var value: String?
    var userOrder: Int?
    
    // Relationships (one of these will be set)
    var character: FictionCharacter?
    var location: FictionLocation?
    
    init(key: String? = nil, value: String? = nil, userOrder: Int? = nil) {
        self.key = key
        self.value = value
        self.userOrder = userOrder
    }
}

/// A plot element for structuring the story
@Model
final class PlotElement {
    var id: UUID = UUID()
    var name: String?
    var notes: String?
    var userOrder: Int?
    var monomythStageRaw: String?  // Only for monomyth projects
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    // Many-to-many with FictionScene
    @Relationship(inverse: \FictionScene.plotElements)
    var linkedScenes: [FictionScene]?
    
    var monomythStage: MonomythStage? {
        get { 
            guard let raw = monomythStageRaw else { return nil }
            return MonomythStage(rawValue: raw) 
        }
        set { monomythStageRaw = newValue?.rawValue }
    }
    
    init(name: String? = nil, notes: String? = nil, monomythStage: MonomythStage? = nil, userOrder: Int? = nil) {
        self.name = name ?? monomythStage?.localizedName
        self.notes = notes
        self.monomythStageRaw = monomythStage?.rawValue
        self.userOrder = userOrder ?? monomythStage?.order
    }
}
