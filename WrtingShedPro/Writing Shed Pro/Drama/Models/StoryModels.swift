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
    
    var localizedName: String {
        switch self {
        case .freeform:
            return NSLocalizedString("storyStructure.freeform", comment: "Freeform")
        case .threeAct:
            return NSLocalizedString("storyStructure.threeAct", comment: "3-Act Structure")
        case .monomythVogler:
            return NSLocalizedString("storyStructure.monomythVogler", comment: "Hero's Journey (Vogler)")
        }
    }

    /// User-facing structures exposed in project creation/editing.
    static var userFacingCases: [StoryStructure] {
        [.freeform, .threeAct, .monomythVogler]
    }
    
    var description: String {
        switch self {
        case .freeform:
            return NSLocalizedString("storyStructure.freeform.description", comment: "No predefined structure - organize your story freely")
        case .threeAct:
            return NSLocalizedString("storyStructure.threeAct.description", comment: "Classic 3-act structure: Setup, Confrontation, Resolution")
        case .monomythVogler:
            return NSLocalizedString("storyStructure.monomythVogler.description", comment: "12 stages from The Writer's Journey by Christopher Vogler")
        }
    }
    
    /// Whether this structure uses monomyth stages
    var usesMonomyth: Bool {
        switch self {
        case .monomythVogler:
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
    var campbellStageRaw: String?  // Legacy field retained for old imports
    var threeActStageRaw: String?  // Three-act structure
    var pearsonStageRaw: String?   // Legacy field retained for old imports
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Feature 036: Body Matter tracking (used for Short Fiction)
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
    
    /// Soft delete support - when true, scene is in trash
    var isTrashed: Bool = false
    var trashedDate: Date?
    
    // Relationships (via join tables for CloudKit compatibility)
    @Relationship(deleteRule: .nullify, inverse: \SceneChapterLink.scene)
    var chapterLinks: [SceneChapterLink]? = []
    
    @Relationship(deleteRule: .nullify, inverse: \SceneActLink.scene)
    var actLinks: [SceneActLink]? = []
    
    @Relationship(deleteRule: .nullify, inverse: \SceneBookLink.scene)
    var bookLinks: [SceneBookLink]? = []
    
    @Relationship(deleteRule: .nullify, inverse: \ScenePlotElementLink.scene)
    var plotElementLinks: [ScenePlotElementLink]? = []
    
    @Relationship(deleteRule: .nullify, inverse: \SceneCharacterLink.scene)
    var characterLinks: [SceneCharacterLink]? = []
    
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \TextFile.scene)
    var textFile: TextFile?  // Contains the actual scene content
    
    // Legacy single-location relationship (kept for backward compat; data read via `locations`)
    @Relationship(inverse: \Location.scenes)
    var location: Location?
    
    // Many-to-many locations via join table (CloudKit compatible)
    @Relationship(deleteRule: .nullify, inverse: \SceneLocationLink.scene)
    var locationLinks: [SceneLocationLink]? = []
    
    // MARK: - Many-to-Many Computed Properties (via join tables)
    
    var chapters: [Chapter]? {
        get { chapterLinks?.compactMap(\.chapter) }
        set {
            for link in chapterLinks ?? [] { modelContext?.delete(link) }
            chapterLinks = []
            for chapter in newValue ?? [] {
                let link = SceneChapterLink(scene: self, chapter: chapter)
                modelContext?.insert(link)
                if chapterLinks == nil { chapterLinks = [] }
                chapterLinks?.append(link)
            }
        }
    }
    
    var acts: [Act]? {
        get { actLinks?.compactMap(\.act) }
        set {
            for link in actLinks ?? [] { modelContext?.delete(link) }
            actLinks = []
            for act in newValue ?? [] {
                let link = SceneActLink(scene: self, act: act)
                modelContext?.insert(link)
                if actLinks == nil { actLinks = [] }
                actLinks?.append(link)
            }
        }
    }
    
    var books: [Book]? {
        get { bookLinks?.compactMap(\.book) }
        set {
            for link in bookLinks ?? [] { modelContext?.delete(link) }
            bookLinks = []
            for book in newValue ?? [] {
                let link = SceneBookLink(scene: self, book: book)
                modelContext?.insert(link)
                if bookLinks == nil { bookLinks = [] }
                bookLinks?.append(link)
            }
        }
    }
    
    var plotElements: [PlotElement]? {
        get { plotElementLinks?.compactMap(\.plotElement) }
        set {
            for link in plotElementLinks ?? [] { modelContext?.delete(link) }
            plotElementLinks = []
            for element in newValue ?? [] {
                let link = ScenePlotElementLink(scene: self, plotElement: element)
                modelContext?.insert(link)
                if plotElementLinks == nil { plotElementLinks = [] }
                plotElementLinks?.append(link)
                // Explicitly update the other side so @Observable fires on PlotElement
                if element.sceneLinks == nil { element.sceneLinks = [] }
                element.sceneLinks?.append(link)
            }
        }
    }
    
    var characters: [Character]? {
        get { characterLinks?.compactMap(\.character) }
        set {
            for link in characterLinks ?? [] { modelContext?.delete(link) }
            characterLinks = []
            for character in newValue ?? [] {
                let link = SceneCharacterLink(scene: self, character: character)
                modelContext?.insert(link)
                if characterLinks == nil { characterLinks = [] }
                characterLinks?.append(link)
                // Explicitly update the other side so @Observable fires on Character
                if character.sceneLinks == nil { character.sceneLinks = [] }
                character.sceneLinks?.append(link)
            }
        }
    }
    
    /// All locations for this scene. Reads from the join table; also surfaces the legacy
    /// single `location` field for any scenes that predate the multi-location model.
    var locations: [Location]? {
        get {
            var result = locationLinks?.compactMap(\.location) ?? []
            if let single = location, !result.contains(where: { $0.id == single.id }) {
                result.insert(single, at: 0)
            }
            return result.isEmpty ? nil : result
        }
        set {
            for link in locationLinks ?? [] { modelContext?.delete(link) }
            locationLinks = []
            for loc in newValue ?? [] {
                let link = SceneLocationLink(scene: self, location: loc)
                modelContext?.insert(link)
                if locationLinks == nil { locationLinks = [] }
                locationLinks?.append(link)
                if loc.sceneLinks == nil { loc.sceneLinks = [] }
                loc.sceneLinks?.append(link)
            }
            // Keep legacy field in sync with first location for any code that still reads it
            location = newValue?.first
        }
    }
    
    var monomythStage: MonomythStage? {
        get { 
            guard let raw = monomythStageRaw else { return nil }
            return MonomythStage(rawValue: raw) 
        }
        set { monomythStageRaw = newValue?.rawValue }
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
        if let stage = threeActStage { return stage.order }
        return nil
    }
    
    /// Returns the localized stage name based on whichever stage type is set
    var stageLocalizedName: String? {
        if let stage = monomythStage { return stage.localizedName }
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
    
    // Feature 036: Body Matter tracking
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .nullify, inverse: \SceneChapterLink.chapter)
    var sceneLinks: [SceneChapterLink]? = []
    
    /// Scenes in this chapter (derived from join table)
    var scenes: [StoryScene]? {
        get { sceneLinks?.compactMap(\.scene) }
        set {
            for link in sceneLinks ?? [] { modelContext?.delete(link) }
            sceneLinks = []
            for scene in newValue ?? [] {
                let link = SceneChapterLink(scene: scene, chapter: self)
                modelContext?.insert(link)
                if sceneLinks == nil { sceneLinks = [] }
                sceneLinks?.append(link)
            }
        }
    }
    
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
    
    // Feature 036: Body Matter tracking
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .nullify, inverse: \SceneActLink.act)
    var sceneLinks: [SceneActLink]? = []
    
    /// Scenes in this act (derived from join table)
    var scenes: [StoryScene]? {
        get { sceneLinks?.compactMap(\.scene) }
        set {
            for link in sceneLinks ?? [] { modelContext?.delete(link) }
            sceneLinks = []
            for scene in newValue ?? [] {
                let link = SceneActLink(scene: scene, act: self)
                modelContext?.insert(link)
                if sceneLinks == nil { sceneLinks = [] }
                sceneLinks?.append(link)
            }
        }
    }
    
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
    
    // Feature 036: Body Matter tracking
    var bodyMatterOrder: Int?
    var isInBodyMatter: Bool = false
    
    // Relationships
    var project: Project?
    
    @Relationship(deleteRule: .nullify, inverse: \TextFileSectionLink.section)
    var textFileLinks: [TextFileSectionLink]? = []
    
    /// Text files in this section (derived from join table)
    var textFiles: [TextFile]? {
        get { textFileLinks?.compactMap(\.textFile) }
        set {
            for link in textFileLinks ?? [] { modelContext?.delete(link) }
            textFileLinks = []
            for file in newValue ?? [] {
                let link = TextFileSectionLink(textFile: file, section: self)
                modelContext?.insert(link)
                if textFileLinks == nil { textFileLinks = [] }
                textFileLinks?.append(link)
            }
        }
    }
    
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
    var archetypeRaw: String?  // Only used when monomyth enabled (Vogler archetypes)
    var pearsonArchetypeRaw: String?  // Legacy field retained for old imports
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
    
    // Scenes this character appears in (via join table for CloudKit)
    @Relationship(deleteRule: .nullify, inverse: \SceneCharacterLink.character)
    var sceneLinks: [SceneCharacterLink]? = []
    
    // Plot elements this character is planned for (via join table for CloudKit)
    @Relationship(deleteRule: .nullify, inverse: \CharacterPlotElementLink.character)
    var plotElementLinks: [CharacterPlotElementLink]? = []
    
    /// Scenes this character appears in (derived from join table)
    var scenes: [StoryScene]? {
        get { sceneLinks?.compactMap(\.scene) }
        set {
            for link in sceneLinks ?? [] { modelContext?.delete(link) }
            sceneLinks = []
            for scene in newValue ?? [] {
                let link = SceneCharacterLink(scene: scene, character: self)
                modelContext?.insert(link)
                if sceneLinks == nil { sceneLinks = [] }
                sceneLinks?.append(link)
                // Explicitly update the other side so @Observable fires on StoryScene
                if scene.characterLinks == nil { scene.characterLinks = [] }
                scene.characterLinks?.append(link)
            }
        }
    }
    
    /// Plot elements this character is planned for (derived from join table)
    var plotElements: [PlotElement]? {
        get { plotElementLinks?.compactMap(\.plotElement) }
        set {
            for link in plotElementLinks ?? [] { modelContext?.delete(link) }
            plotElementLinks = []
            for element in newValue ?? [] {
                let link = CharacterPlotElementLink(character: self, plotElement: element)
                modelContext?.insert(link)
                if plotElementLinks == nil { plotElementLinks = [] }
                plotElementLinks?.append(link)
                // Explicitly update the other side so @Observable fires on PlotElement
                if element.characterLinks == nil { element.characterLinks = [] }
                element.characterLinks?.append(link)
            }
        }
    }
    
    /// Primary archetype (first selected, for backward compatibility)
    var archetype: CharacterArchetype? {
        get { archetypes.first }
        set {
            if let value = newValue {
                archetypes = [value]
            } else {
                archetypes = []
            }
        }
    }
    
    /// All selected Vogler archetypes (stored as comma-separated in archetypeRaw)
    var archetypes: [CharacterArchetype] {
        get {
            guard let raw = archetypeRaw, !raw.isEmpty else { return [] }
            return raw.split(separator: ",").compactMap { CharacterArchetype(rawValue: String($0)) }
        }
        set {
            archetypeRaw = newValue.isEmpty ? nil : newValue.map(\.rawValue).joined(separator: ",")
        }
    }
    
    init(name: String? = nil, role: String? = nil, archetypes: [CharacterArchetype] = [], history: String? = nil, looks: String? = nil, traits: String? = nil, work: String? = nil) {
        self.name = name
        self.role = role
        self.archetypeRaw = archetypes.isEmpty ? nil : archetypes.map(\.rawValue).joined(separator: ",")
        self.pearsonArchetypeRaw = nil
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
    
    // Scenes that take place at this location (legacy one-to-many; kept for existing data)
    var scenes: [StoryScene]?
    
    // Many-to-many scenes via join table
    @Relationship(deleteRule: .nullify, inverse: \SceneLocationLink.location)
    var sceneLinks: [SceneLocationLink]? = []
    
    // Plot elements this location is planned for (via join table for CloudKit)
    @Relationship(deleteRule: .nullify, inverse: \LocationPlotElementLink.location)
    var plotElementLinks: [LocationPlotElementLink]? = []
    
    /// Plot elements for this location (derived from join table)
    var plotElements: [PlotElement]? {
        get { plotElementLinks?.compactMap(\.plotElement) }
        set {
            for link in plotElementLinks ?? [] { modelContext?.delete(link) }
            plotElementLinks = []
            for element in newValue ?? [] {
                let link = LocationPlotElementLink(location: self, plotElement: element)
                modelContext?.insert(link)
                if plotElementLinks == nil { plotElementLinks = [] }
                plotElementLinks?.append(link)
            }
        }
    }
    
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
    var campbellStageRaw: String?  // Legacy field retained for old imports
    var threeActStageRaw: String?  // Three-act structure
    var pearsonStageRaw: String?   // Legacy field retained for old imports
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // Relationships
    var project: Project?
    
    // Many-to-many with Scene (via join table for CloudKit)
    @Relationship(deleteRule: .nullify, inverse: \ScenePlotElementLink.plotElement)
    var sceneLinks: [ScenePlotElementLink]? = []
    
    // Characters involved in this plot beat (via join table for CloudKit)
    @Relationship(deleteRule: .nullify, inverse: \CharacterPlotElementLink.plotElement)
    var characterLinks: [CharacterPlotElementLink]? = []
    
    // Locations for this plot beat (via join table for CloudKit)
    @Relationship(deleteRule: .nullify, inverse: \LocationPlotElementLink.plotElement)
    var locationLinks: [LocationPlotElementLink]? = []
    
    /// Linked scenes (derived from join table)
    var linkedScenes: [StoryScene]? {
        get { sceneLinks?.compactMap(\.scene) }
        set {
            for link in sceneLinks ?? [] { modelContext?.delete(link) }
            sceneLinks = []
            for scene in newValue ?? [] {
                let link = ScenePlotElementLink(scene: scene, plotElement: self)
                modelContext?.insert(link)
                if sceneLinks == nil { sceneLinks = [] }
                sceneLinks?.append(link)
                // Explicitly update the other side so @Observable fires on StoryScene
                if scene.plotElementLinks == nil { scene.plotElementLinks = [] }
                scene.plotElementLinks?.append(link)
            }
        }
    }
    
    /// Characters in this plot beat — derived as the union of all linked scenes' characters.
    var characters: [Character]? {
        get {
            let fromScenes = (linkedScenes ?? []).flatMap { $0.characters ?? [] }
            var seen = Set<PersistentIdentifier>()
            return fromScenes.filter { seen.insert($0.persistentModelID).inserted }
        }
        // Setter retained for import compatibility; data is ignored by the getter.
        set {
            for link in characterLinks ?? [] { modelContext?.delete(link) }
            characterLinks = []
            for character in newValue ?? [] {
                let link = CharacterPlotElementLink(character: character, plotElement: self)
                modelContext?.insert(link)
                if characterLinks == nil { characterLinks = [] }
                characterLinks?.append(link)
                if character.plotElementLinks == nil { character.plotElementLinks = [] }
                character.plotElementLinks?.append(link)
            }
        }
    }
    
    /// Locations in this plot beat — derived as the union of all linked scenes' locations.
    var locations: [Location]? {
        get {
            let fromScenes = (linkedScenes ?? []).flatMap { $0.locations ?? [] }
            var seen = Set<PersistentIdentifier>()
            return fromScenes.filter { seen.insert($0.persistentModelID).inserted }
        }
        // Setter retained for import compatibility; data is ignored by the getter.
        set {
            for link in locationLinks ?? [] { modelContext?.delete(link) }
            locationLinks = []
            for location in newValue ?? [] {
                let link = LocationPlotElementLink(location: location, plotElement: self)
                modelContext?.insert(link)
                if locationLinks == nil { locationLinks = [] }
                locationLinks?.append(link)
                if location.plotElementLinks == nil { location.plotElementLinks = [] }
                location.plotElementLinks?.append(link)
            }
        }
    }
    
    var monomythStage: MonomythStage? {
        get { 
            guard let raw = monomythStageRaw else { return nil }
            return MonomythStage(rawValue: raw) 
        }
        set { monomythStageRaw = newValue?.rawValue }
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
        if let stage = threeActStage { return stage.order }
        return nil
    }
    
    /// Returns the localized stage name based on whichever stage type is set
    var stageLocalizedName: String? {
        if let stage = monomythStage { return stage.localizedName }
        if let stage = threeActStage { return stage.localizedName }
        return nil
    }
    
    init(name: String? = nil, notes: String? = nil, monomythStage: MonomythStage? = nil, threeActStage: ThreeActStage? = nil, userOrder: Int? = nil) {
        // Set name from provided name or from stage
        self.name = name ?? monomythStage?.localizedName ?? threeActStage?.localizedName
        self.notes = notes
        self.monomythStageRaw = monomythStage?.rawValue
        self.campbellStageRaw = nil
        self.threeActStageRaw = threeActStage?.rawValue
        self.pearsonStageRaw = nil
        // Use provided order or derive from stage
        self.userOrder = userOrder ?? monomythStage?.order ?? threeActStage?.order
    }
}
