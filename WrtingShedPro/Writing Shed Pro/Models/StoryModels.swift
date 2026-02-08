//
//  StoryModels.swift
//  Writing Shed Pro
//
//  Feature 022/023: Smart Fiction & Drama Creation
//  Shared models for fiction and drama projects including scenes, chapters/acts, characters, locations, and plot elements
//

import Foundation
import SwiftData

// MARK: - Enums

/// The class of fiction project - determines structure
enum FictionClass: String, Codable, CaseIterable {
    case novel        // Long fiction with chapters containing scenes
    case shortFiction // Short fiction with scenes directly (no chapters)
    case verseNovel   // Poetry-based fiction with books containing episodes (poems)
    
    var localizedName: String {
        switch self {
        case .novel:
            return NSLocalizedString("fictionClass.novel", comment: "Novel fiction class")
        case .shortFiction:
            return NSLocalizedString("fictionClass.shortFiction", comment: "Short Fiction class")
        case .verseNovel:
            return NSLocalizedString("fictionClass.verseNovel", comment: "Verse Novel fiction class")
        }
    }
    
    /// Whether this fiction class uses poetry editing (meter, rhyme, forms)
    var usesPoetryEditor: Bool {
        self == .verseNovel
    }
    
    /// The display name for chapters in this fiction class
    var chapterDisplayName: String {
        switch self {
        case .novel:
            return NSLocalizedString("fiction.chapters.title", comment: "Chapters")
        case .shortFiction:
            return NSLocalizedString("fiction.stories.title", comment: "Stories")
        case .verseNovel:
            return NSLocalizedString("fiction.books.title", comment: "Books")
        }
    }
    
    /// The display name for a single chapter in this fiction class
    var chapterSingularName: String {
        switch self {
        case .novel:
            return NSLocalizedString("fiction.chapter.title", comment: "Chapter")
        case .shortFiction:
            return NSLocalizedString("fiction.story.title", comment: "Story")
        case .verseNovel:
            return NSLocalizedString("fiction.book.title", comment: "Book")
        }
    }
    
    /// The display name for scenes in this fiction class
    var sceneDisplayName: String {
        switch self {
        case .novel, .shortFiction:
            return NSLocalizedString("fiction.scenes.title", comment: "Scenes")
        case .verseNovel:
            return NSLocalizedString("fiction.episodes.title", comment: "Episodes")
        }
    }
    
    /// The display name for a single scene in this fiction class
    var sceneSingularName: String {
        switch self {
        case .novel, .shortFiction:
            return NSLocalizedString("fiction.scene.title", comment: "Scene")
        case .verseNovel:
            return NSLocalizedString("fiction.episode.title", comment: "Episode")
        }
    }
}

/// Story structure options for fiction and drama projects
/// Determines how plot elements are organized and what stages are available
enum StoryStructure: String, Codable, CaseIterable {
    case freeform           // No predefined structure
    case threeAct           // 3-act structure (Setup, Confrontation, Resolution)
    case monomythVogler     // 12-stage Hero's Journey (Christopher Vogler)
    case monomythCampbell   // 17-stage Hero's Journey (Joseph Campbell)
    
    var localizedName: String {
        switch self {
        case .freeform:
            return NSLocalizedString("storyStructure.freeform", comment: "Freeform")
        case .threeAct:
            return NSLocalizedString("storyStructure.threeAct", comment: "3-Act Structure")
        case .monomythVogler:
            return NSLocalizedString("storyStructure.monomythVogler", comment: "Hero's Journey (Vogler)")
        case .monomythCampbell:
            return NSLocalizedString("storyStructure.monomythCampbell", comment: "Hero's Journey (Campbell)")
        }
    }
    
    var description: String {
        switch self {
        case .freeform:
            return NSLocalizedString("storyStructure.freeform.description", comment: "No predefined structure - organize your story freely")
        case .threeAct:
            return NSLocalizedString("storyStructure.threeAct.description", comment: "Classic 3-act structure: Setup, Confrontation, Resolution")
        case .monomythVogler:
            return NSLocalizedString("storyStructure.monomythVogler.description", comment: "12 stages from The Writer's Journey by Christopher Vogler")
        case .monomythCampbell:
            return NSLocalizedString("storyStructure.monomythCampbell.description", comment: "17 stages from The Hero with a Thousand Faces by Joseph Campbell")
        }
    }
    
    /// Whether this structure uses monomyth stages
    var usesMonomyth: Bool {
        switch self {
        case .monomythVogler, .monomythCampbell:
            return true
        case .freeform, .threeAct:
            return false
        }
    }
    
    /// Number of stages/acts in this structure
    var stageCount: Int {
        switch self {
        case .freeform:
            return 0
        case .threeAct:
            return 3
        case .monomythVogler:
            return 12
        case .monomythCampbell:
            return 17
        }
    }
}

/// The 17 stages of Joseph Campbell's monomyth from "The Hero with a Thousand Faces"
enum CampbellMonomythStage: String, Codable, CaseIterable {
    case theOrdinaryWorld
    case theCallToAdventure
    case refusalOfTheCall
    case supernaturalAid
    case crossingTheFirstThreshold
    case bellyOfTheWhale
    case theRoadOfTrials
    case meetingWithTheGoddess
    case womanAsTemptress
    case atonementWithTheFather
    case apotheosis
    case theUltimateBoon
    case refusalOfTheReturn
    case theMagicFlight
    case rescueFromWithout
    case crossingTheReturnThreshold
    case masterOfTwoWorlds
    
    var localizedName: String {
        switch self {
        case .theOrdinaryWorld:
            return NSLocalizedString("campbell.theOrdinaryWorld", comment: "The Ordinary World")
        case .theCallToAdventure:
            return NSLocalizedString("campbell.theCallToAdventure", comment: "The Call to Adventure")
        case .refusalOfTheCall:
            return NSLocalizedString("campbell.refusalOfTheCall", comment: "Refusal of the Call")
        case .supernaturalAid:
            return NSLocalizedString("campbell.supernaturalAid", comment: "Supernatural Aid")
        case .crossingTheFirstThreshold:
            return NSLocalizedString("campbell.crossingTheFirstThreshold", comment: "Crossing the First Threshold")
        case .bellyOfTheWhale:
            return NSLocalizedString("campbell.bellyOfTheWhale", comment: "Belly of the Whale")
        case .theRoadOfTrials:
            return NSLocalizedString("campbell.theRoadOfTrials", comment: "The Road of Trials")
        case .meetingWithTheGoddess:
            return NSLocalizedString("campbell.meetingWithTheGoddess", comment: "Meeting with the Goddess")
        case .womanAsTemptress:
            return NSLocalizedString("campbell.womanAsTemptress", comment: "Woman as Temptress")
        case .atonementWithTheFather:
            return NSLocalizedString("campbell.atonementWithTheFather", comment: "Atonement with the Father")
        case .apotheosis:
            return NSLocalizedString("campbell.apotheosis", comment: "Apotheosis")
        case .theUltimateBoon:
            return NSLocalizedString("campbell.theUltimateBoon", comment: "The Ultimate Boon")
        case .refusalOfTheReturn:
            return NSLocalizedString("campbell.refusalOfTheReturn", comment: "Refusal of the Return")
        case .theMagicFlight:
            return NSLocalizedString("campbell.theMagicFlight", comment: "The Magic Flight")
        case .rescueFromWithout:
            return NSLocalizedString("campbell.rescueFromWithout", comment: "Rescue from Without")
        case .crossingTheReturnThreshold:
            return NSLocalizedString("campbell.crossingTheReturnThreshold", comment: "Crossing the Return Threshold")
        case .masterOfTwoWorlds:
            return NSLocalizedString("campbell.masterOfTwoWorlds", comment: "Master of Two Worlds")
        }
    }
    
    var description: String {
        switch self {
        case .theOrdinaryWorld:
            return NSLocalizedString("campbell.theOrdinaryWorld.description", comment: "The hero's normal world before the adventure begins")
        case .theCallToAdventure:
            return NSLocalizedString("campbell.theCallToAdventure.description", comment: "The hero receives a call to action or adventure")
        case .refusalOfTheCall:
            return NSLocalizedString("campbell.refusalOfTheCall.description", comment: "The hero initially refuses the call due to fear or obligation")
        case .supernaturalAid:
            return NSLocalizedString("campbell.supernaturalAid.description", comment: "The hero receives help from a mentor or magical guide")
        case .crossingTheFirstThreshold:
            return NSLocalizedString("campbell.crossingTheFirstThreshold.description", comment: "The hero commits to the adventure and enters the special world")
        case .bellyOfTheWhale:
            return NSLocalizedString("campbell.bellyOfTheWhale.description", comment: "The hero is swallowed into the unknown, representing final separation")
        case .theRoadOfTrials:
            return NSLocalizedString("campbell.theRoadOfTrials.description", comment: "The hero faces a series of tests and obstacles")
        case .meetingWithTheGoddess:
            return NSLocalizedString("campbell.meetingWithTheGoddess.description", comment: "The hero experiences unconditional love or encounters the divine feminine")
        case .womanAsTemptress:
            return NSLocalizedString("campbell.womanAsTemptress.description", comment: "The hero faces temptation that may lead them astray")
        case .atonementWithTheFather:
            return NSLocalizedString("campbell.atonementWithTheFather.description", comment: "The hero confronts the ultimate power in their life")
        case .apotheosis:
            return NSLocalizedString("campbell.apotheosis.description", comment: "The hero achieves a higher state of being or understanding")
        case .theUltimateBoon:
            return NSLocalizedString("campbell.theUltimateBoon.description", comment: "The hero receives the goal of the quest")
        case .refusalOfTheReturn:
            return NSLocalizedString("campbell.refusalOfTheReturn.description", comment: "The hero may not want to return to the ordinary world")
        case .theMagicFlight:
            return NSLocalizedString("campbell.theMagicFlight.description", comment: "The hero escapes with the boon, possibly pursued")
        case .rescueFromWithout:
            return NSLocalizedString("campbell.rescueFromWithout.description", comment: "The hero needs help from the ordinary world to return")
        case .crossingTheReturnThreshold:
            return NSLocalizedString("campbell.crossingTheReturnThreshold.description", comment: "The hero returns to the ordinary world transformed")
        case .masterOfTwoWorlds:
            return NSLocalizedString("campbell.masterOfTwoWorlds.description", comment: "The hero achieves balance between inner and outer worlds")
        }
    }
    
    /// Order in the hero's journey (1-17)
    var order: Int {
        switch self {
        case .theOrdinaryWorld: return 1
        case .theCallToAdventure: return 2
        case .refusalOfTheCall: return 3
        case .supernaturalAid: return 4
        case .crossingTheFirstThreshold: return 5
        case .bellyOfTheWhale: return 6
        case .theRoadOfTrials: return 7
        case .meetingWithTheGoddess: return 8
        case .womanAsTemptress: return 9
        case .atonementWithTheFather: return 10
        case .apotheosis: return 11
        case .theUltimateBoon: return 12
        case .refusalOfTheReturn: return 13
        case .theMagicFlight: return 14
        case .rescueFromWithout: return 15
        case .crossingTheReturnThreshold: return 16
        case .masterOfTwoWorlds: return 17
        }
    }
}

/// Three-act structure stages
enum ThreeActStage: String, Codable, CaseIterable {
    case actOne     // Setup
    case actTwo     // Confrontation
    case actThree   // Resolution
    
    var localizedName: String {
        switch self {
        case .actOne:
            return NSLocalizedString("threeAct.actOne", comment: "Act I: Setup")
        case .actTwo:
            return NSLocalizedString("threeAct.actTwo", comment: "Act II: Confrontation")
        case .actThree:
            return NSLocalizedString("threeAct.actThree", comment: "Act III: Resolution")
        }
    }
    
    var description: String {
        switch self {
        case .actOne:
            return NSLocalizedString("threeAct.actOne.description", comment: "Introduce characters, setting, and conflict")
        case .actTwo:
            return NSLocalizedString("threeAct.actTwo.description", comment: "Develop conflict, raise stakes, build tension")
        case .actThree:
            return NSLocalizedString("threeAct.actThree.description", comment: "Resolve conflict and conclude the story")
        }
    }
    
    var order: Int {
        switch self {
        case .actOne: return 1
        case .actTwo: return 2
        case .actThree: return 3
        }
    }
}

/// Plot structure options - monomyth or act-based
/// @available(*, deprecated, message: "Use StoryStructure instead")
enum PlotStructure: String, Codable, CaseIterable {
    case monomyth    // 12-stage Hero's Journey
    case threeAct    // 3-act structure (Setup, Confrontation, Resolution)
    case fiveAct     // 5-act structure (Exposition, Rising Action, Climax, Falling Action, Denouement)
    case freeform    // No predefined structure
    
    var localizedName: String {
        switch self {
        case .monomyth:
            return NSLocalizedString("plotStructure.monomyth", comment: "Hero's Journey")
        case .threeAct:
            return NSLocalizedString("plotStructure.threeAct", comment: "3-Act Structure")
        case .fiveAct:
            return NSLocalizedString("plotStructure.fiveAct", comment: "5-Act Structure")
        case .freeform:
            return NSLocalizedString("plotStructure.freeform", comment: "Freeform")
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
final class StoryScene {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?  // Brief description of what happens
    var monomythStageRaw: String?  // Vogler's 12 stages
    var campbellStageRaw: String?  // Campbell's 17 stages
    var threeActStageRaw: String?  // Three-act structure
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    /// Soft delete support - when true, scene is in trash
    var isTrashed: Bool = false
    var trashedDate: Date?
    
    // Relationships
    @Relationship(inverse: \Chapter.scenes)
    var chapter: Chapter?  // Used for both Novel and Short Fiction projects
    
    @Relationship(inverse: \Act.scenes)
    var act: Act?  // nil for Fiction projects, used for Drama projects
    
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \TextFile.scene)
    var textFile: TextFile?  // Contains the actual scene content
    
    // Many-to-many with PlotElement
    @Relationship(inverse: \PlotElement.linkedScenes)
    var plotElements: [PlotElement]?
    
    // Scene can have multiple characters
    @Relationship(inverse: \Character.scenes)
    var characters: [Character]?
    
    // Scene takes place at a location
    @Relationship(inverse: \Location.scenes)
    var location: Location?
    
    var monomythStage: MonomythStage? {
        get { 
            guard let raw = monomythStageRaw else { return nil }
            return MonomythStage(rawValue: raw) 
        }
        set { monomythStageRaw = newValue?.rawValue }
    }
    
    var campbellStage: CampbellMonomythStage? {
        get {
            guard let raw = campbellStageRaw else { return nil }
            return CampbellMonomythStage(rawValue: raw)
        }
        set { campbellStageRaw = newValue?.rawValue }
    }
    
    var threeActStage: ThreeActStage? {
        get {
            guard let raw = threeActStageRaw else { return nil }
            return ThreeActStage(rawValue: raw)
        }
        set { threeActStageRaw = newValue?.rawValue }
    }
    
    /// Returns the stage order based on whichever stage type is set
    var stageOrder: Int? {
        if let stage = monomythStage { return stage.order }
        if let stage = campbellStage { return stage.order }
        if let stage = threeActStage { return stage.order }
        return nil
    }
    
    /// Returns the localized stage name based on whichever stage type is set
    var stageLocalizedName: String? {
        if let stage = monomythStage { return stage.localizedName }
        if let stage = campbellStage { return stage.localizedName }
        if let stage = threeActStage { return stage.localizedName }
        return nil
    }
    
    /// Moves scene to trash (soft delete)
    func moveToTrash() {
        isTrashed = true
        trashedDate = Date()
    }
    
    /// Restores scene from trash
    func restore() {
        isTrashed = false
        trashedDate = nil
    }
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}

/// A chapter is a container for scenes (Novel fiction class only)
@Model
final class Chapter {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .nullify)
    var scenes: [StoryScene]?
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}

/// An act is a container for scenes (Drama projects only)
/// Similar to Chapter in Fiction Novel projects
@Model
final class Act {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .nullify)
    var scenes: [StoryScene]?
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}

/// A section is a container for text files (Prose projects only)
/// Similar to Chapter in Fiction Novel projects and Act in Drama projects
@Model
final class ProseSection {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .nullify, inverse: \TextFile.section)
    var textFiles: [TextFile]?
    
    init(name: String? = nil, synopsis: String? = nil, userOrder: Int? = nil) {
        self.name = name
        self.synopsis = synopsis
        self.userOrder = userOrder
    }
}

/// A character in the fiction project
@Model
final class Character {
    var id: UUID = UUID()
    var name: String?
    var role: String?  // Character's role in the story (protagonist, love interest, etc.)
    var archetypeRaw: String?  // Only used when monomyth enabled
    var history: String?  // Character's background/history
    var looks: String?  // Physical appearance description
    var traits: String?  // Personality traits
    var work: String?  // Occupation/what they do
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \CustomAttribute.character)
    var customAttributes: [CustomAttribute]?
    
    // Scenes this character appears in (many-to-many)
    var scenes: [StoryScene]?
    
    // Plot elements this character is planned for (many-to-many)
    var plotElements: [PlotElement]?
    
    var archetype: CharacterArchetype? {
        get { 
            guard let raw = archetypeRaw else { return nil }
            return CharacterArchetype(rawValue: raw) 
        }
        set { archetypeRaw = newValue?.rawValue }
    }
    
    init(name: String? = nil, role: String? = nil, archetype: CharacterArchetype? = nil, history: String? = nil, looks: String? = nil, traits: String? = nil, work: String? = nil) {
        self.name = name
        self.role = role
        self.archetypeRaw = archetype?.rawValue
        self.history = history
        self.looks = looks
        self.traits = traits
        self.work = work
    }
}

/// A location where scenes take place
@Model
final class Location {
    var id: UUID = UUID()
    var name: String?
    var detail: String?  // General description/details of the location
    var sights: String?  // Visual descriptions
    var sounds: String?  // Auditory descriptions
    var smells: String?  // Olfactory descriptions
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \CustomAttribute.location)
    var customAttributes: [CustomAttribute]?
    
    // Scenes that take place at this location
    var scenes: [StoryScene]?
    
    // Plot elements this location is planned for (many-to-many)
    var plotElements: [PlotElement]?
    
    init(name: String? = nil, detail: String? = nil, sights: String? = nil, sounds: String? = nil, smells: String? = nil) {
        self.name = name
        self.detail = detail
        self.sights = sights
        self.sounds = sounds
        self.smells = smells
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
    var character: Character?
    var location: Location?
    
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
    var monomythStageRaw: String?  // Vogler's 12 stages
    var campbellStageRaw: String?  // Campbell's 17 stages
    var threeActStageRaw: String?  // Three-act structure
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    // Many-to-many with Scene (inverse defined on Scene.plotElements)
    var linkedScenes: [StoryScene]?
    
    // Characters involved in this plot beat (planned involvement)
    @Relationship(inverse: \Character.plotElements)
    var characters: [Character]?
    
    // Locations for this plot beat (planned involvement)
    @Relationship(inverse: \Location.plotElements)
    var locations: [Location]?
    
    var monomythStage: MonomythStage? {
        get { 
            guard let raw = monomythStageRaw else { return nil }
            return MonomythStage(rawValue: raw) 
        }
        set { monomythStageRaw = newValue?.rawValue }
    }
    
    var campbellStage: CampbellMonomythStage? {
        get {
            guard let raw = campbellStageRaw else { return nil }
            return CampbellMonomythStage(rawValue: raw)
        }
        set { campbellStageRaw = newValue?.rawValue }
    }
    
    var threeActStage: ThreeActStage? {
        get {
            guard let raw = threeActStageRaw else { return nil }
            return ThreeActStage(rawValue: raw)
        }
        set { threeActStageRaw = newValue?.rawValue }
    }
    
    /// Returns the stage order based on whichever stage type is set
    var stageOrder: Int? {
        if let stage = monomythStage { return stage.order }
        if let stage = campbellStage { return stage.order }
        if let stage = threeActStage { return stage.order }
        return nil
    }
    
    /// Returns the localized stage name based on whichever stage type is set
    var stageLocalizedName: String? {
        if let stage = monomythStage { return stage.localizedName }
        if let stage = campbellStage { return stage.localizedName }
        if let stage = threeActStage { return stage.localizedName }
        return nil
    }
    
    init(name: String? = nil, notes: String? = nil, monomythStage: MonomythStage? = nil, campbellStage: CampbellMonomythStage? = nil, threeActStage: ThreeActStage? = nil, userOrder: Int? = nil) {
        // Set name from provided name or from stage
        self.name = name ?? monomythStage?.localizedName ?? campbellStage?.localizedName ?? threeActStage?.localizedName
        self.notes = notes
        self.monomythStageRaw = monomythStage?.rawValue
        self.campbellStageRaw = campbellStage?.rawValue
        self.threeActStageRaw = threeActStage?.rawValue
        // Use provided order or derive from stage
        self.userOrder = userOrder ?? monomythStage?.order ?? campbellStage?.order ?? threeActStage?.order
    }
}
