import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class FictionModelsTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self,
            StoryScene.self, Chapter.self, Character.self,
            Location.self, PlotElement.self, CustomAttribute.self,
            TextFileSectionLink.self, TextFileCollectionLink.self,
            SceneChapterLink.self, SceneActLink.self, SceneBookLink.self,
            ScenePlotElementLink.self, SceneCharacterLink.self,
            CharacterPlotElementLink.self, LocationPlotElementLink.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - FictionClass Tests
    
    func testFictionClassLocalizedNames() {
        XCTAssertFalse(FictionClass.novel.localizedName.isEmpty)
        XCTAssertFalse(FictionClass.shortFiction.localizedName.isEmpty)
        XCTAssertFalse(FictionClass.verseNovel.localizedName.isEmpty)
    }
    
    func testFictionClassRawValues() {
        XCTAssertEqual(FictionClass.novel.rawValue, "novel")
        XCTAssertEqual(FictionClass.shortFiction.rawValue, "shortFiction")
        XCTAssertEqual(FictionClass.verseNovel.rawValue, "verseNovel")
    }
    
    func testFictionClassCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for fictionClass in FictionClass.allCases {
            let data = try encoder.encode(fictionClass)
            let decoded = try decoder.decode(FictionClass.self, from: data)
            XCTAssertEqual(fictionClass, decoded)
        }
    }
    
    func testFictionClassUsesPoetryEditor() {
        XCTAssertFalse(FictionClass.novel.usesPoetryEditor)
        XCTAssertFalse(FictionClass.shortFiction.usesPoetryEditor)
        XCTAssertTrue(FictionClass.verseNovel.usesPoetryEditor)
    }
    
    func testFictionClassDisplayNames() {
        // Chapter display names
        XCTAssertFalse(FictionClass.novel.chapterDisplayName.isEmpty)
        XCTAssertFalse(FictionClass.shortFiction.chapterDisplayName.isEmpty)
        XCTAssertFalse(FictionClass.verseNovel.chapterDisplayName.isEmpty)
        
        // Scene display names
        XCTAssertFalse(FictionClass.novel.sceneDisplayName.isEmpty)
        XCTAssertFalse(FictionClass.shortFiction.sceneDisplayName.isEmpty)
        XCTAssertFalse(FictionClass.verseNovel.sceneDisplayName.isEmpty)
    }
    
    // MARK: - CharacterArchetype Tests

    func testThreeActCharacterRoleCount() {
        XCTAssertEqual(ThreeActCharacterRole.allCases.count, 6)
    }

    func testThreeActCharacterRoleRawValues() {
        XCTAssertEqual(ThreeActCharacterRole.protagonist.rawValue, "protagonist")
        XCTAssertEqual(ThreeActCharacterRole.antagonist.rawValue, "antagonist")
        XCTAssertEqual(ThreeActCharacterRole.ally.rawValue, "ally")
        XCTAssertEqual(ThreeActCharacterRole.mentor.rawValue, "mentor")
        XCTAssertEqual(ThreeActCharacterRole.skeptic.rawValue, "skeptic")
        XCTAssertEqual(ThreeActCharacterRole.trickster.rawValue, "trickster")
    }

    func testCharacterThreeActRoleParsesLegacyDisplayValue() {
        let project = Project(name: "Role Test", type: .fiction)
        project.storyStructure = .threeAct

        let character = Character(name: "Elena", role: "Protagonist")
        character.project = project

        XCTAssertEqual(character.threeActRole, .protagonist)
        XCTAssertEqual(character.roleDisplayName, ThreeActCharacterRole.protagonist.localizedName)
    }

    func testCharacterRoleDisplayNameUsesFreeformText() {
        let project = Project(name: "Freeform Role", type: .fiction)
        project.storyStructure = .freeform

        let character = Character(name: "Alex", role: "Lead Detective")
        character.project = project

        XCTAssertNil(character.threeActRole)
        XCTAssertEqual(character.roleDisplayName, "Lead Detective")
    }

    func testCharacterRoleDisplayNameUsesMonomythRoleOptions() {
        let project = Project(name: "Monomyth Role", type: .fiction)
        project.storyStructure = .monomythVogler

        let character = Character(name: "Guide", role: "mentor")
        character.project = project

        XCTAssertEqual(character.roleDisplayName, CharacterArchetype.mentor.localizedName)
    }
    
    func testCharacterArchetypeCount() {
        XCTAssertEqual(CharacterArchetype.allCases.count, 8)
    }
    
    func testCharacterArchetypeLocalizedNames() {
        for archetype in CharacterArchetype.allCases {
            XCTAssertFalse(archetype.localizedName.isEmpty, "\(archetype) should have localized name")
        }
    }
    
    func testCharacterArchetypeDescriptions() {
        for archetype in CharacterArchetype.allCases {
            XCTAssertFalse(archetype.description.isEmpty, "\(archetype) should have description")
        }
    }
    
    func testCharacterArchetypeRawValues() {
        XCTAssertEqual(CharacterArchetype.hero.rawValue, "hero")
        XCTAssertEqual(CharacterArchetype.mentor.rawValue, "mentor")
        XCTAssertEqual(CharacterArchetype.herald.rawValue, "herald")
        XCTAssertEqual(CharacterArchetype.thresholdGuardian.rawValue, "thresholdGuardian")
        XCTAssertEqual(CharacterArchetype.shapeshifter.rawValue, "shapeshifter")
        XCTAssertEqual(CharacterArchetype.shadow.rawValue, "shadow")
        XCTAssertEqual(CharacterArchetype.ally.rawValue, "ally")
        XCTAssertEqual(CharacterArchetype.trickster.rawValue, "trickster")
    }
    
    // MARK: - MonomythStage Tests
    
    func testMonomythStageCount() {
        XCTAssertEqual(MonomythStage.allCases.count, 12)
    }
    
    func testMonomythStageLocalizedNames() {
        for stage in MonomythStage.allCases {
            XCTAssertFalse(stage.localizedName.isEmpty, "\(stage) should have localized name")
        }
    }
    
    func testMonomythStageDescriptions() {
        for stage in MonomythStage.allCases {
            XCTAssertFalse(stage.description.isEmpty, "\(stage) should have description")
        }
    }
    
    func testMonomythStageOrdering() {
        XCTAssertEqual(MonomythStage.ordinaryWorld.order, 1)
        XCTAssertEqual(MonomythStage.callToAdventure.order, 2)
        XCTAssertEqual(MonomythStage.refusalOfTheCall.order, 3)
        XCTAssertEqual(MonomythStage.meetingTheMentor.order, 4)
        XCTAssertEqual(MonomythStage.crossingTheThreshold.order, 5)
        XCTAssertEqual(MonomythStage.testsAlliesEnemies.order, 6)
        XCTAssertEqual(MonomythStage.approachToTheInmostCave.order, 7)
        XCTAssertEqual(MonomythStage.ordeal.order, 8)
        XCTAssertEqual(MonomythStage.reward.order, 9)
        XCTAssertEqual(MonomythStage.theRoadBack.order, 10)
        XCTAssertEqual(MonomythStage.resurrection.order, 11)
        XCTAssertEqual(MonomythStage.returnWithTheElixir.order, 12)
    }
    
    func testMonomythStagesAreContiguous() {
        let orders = MonomythStage.allCases.map { $0.order }.sorted()
        XCTAssertEqual(orders, Array(1...12))
    }
    
    // MARK: - Scene Tests
    
    func testSceneCreation() {
        let scene = StoryScene(name: "Opening Scene", synopsis: "The hero wakes up", userOrder: 1)
        modelContext.insert(scene)
        
        XCTAssertNotNil(scene.id)
        XCTAssertEqual(scene.name, "Opening Scene")
        XCTAssertEqual(scene.synopsis, "The hero wakes up")
        XCTAssertEqual(scene.userOrder, 1)
        XCTAssertNil(scene.monomythStage)
    }
    
    func testSceneWithMonomythStage() {
        let scene = StoryScene(name: "Call Scene")
        scene.monomythStage = .callToAdventure
        modelContext.insert(scene)
        
        XCTAssertEqual(scene.monomythStage, .callToAdventure)
        XCTAssertEqual(scene.monomythStageRaw, "callToAdventure")
    }
    
    func testSceneMonomythStageRoundTrip() {
        for stage in MonomythStage.allCases {
            let scene = StoryScene()
            scene.monomythStage = stage
            XCTAssertEqual(scene.monomythStage, stage)
        }
    }
    
    func testSceneProjectRelationship() throws {
        let project = Project(name: "My Novel", type: .fiction)
        project.fictionClass = .novel
        modelContext.insert(project)
        
        let scene = StoryScene(name: "Scene 1")
        scene.project = project
        project.scenes?.append(scene)
        modelContext.insert(scene)
        
        try modelContext.save()
        
        XCTAssertEqual(scene.project?.id, project.id)
        XCTAssertEqual(project.scenes?.count, 1)
    }
    
    func testSceneChapterRelationship() throws {
        let chapter = Chapter(name: "Chapter 1")
        modelContext.insert(chapter)
        
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        scene.chapter = chapter
        
        try modelContext.save()
        
        XCTAssertEqual(scene.chapter?.id, chapter.id)
        XCTAssertEqual(chapter.scenes?.count, 1)
    }
    
    func testSceneTextFileRelationship() throws {
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        let textFile = TextFile(name: "Scene 1.txt", initialContent: "It was a dark and stormy night...")
        textFile.scene = scene
        scene.textFile = textFile
        modelContext.insert(textFile)
        
        try modelContext.save()
        
        XCTAssertEqual(scene.textFile?.id, textFile.id)
        XCTAssertEqual(textFile.scene?.id, scene.id)
    }
    
    func testSceneCharacterRelationship() throws {
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        let character = Character(name: "Hero")
        modelContext.insert(character)
        
        scene.characters = [character]
        
        try modelContext.save()
        
        XCTAssertEqual(scene.characters?.count, 1)
        XCTAssertEqual(scene.characters?.first?.name, "Hero")
        XCTAssertEqual(character.scenes?.count, 1)
    }
    
    func testSceneLocationRelationship() throws {
        let scene = StoryScene(name: "Scene 1")
        modelContext.insert(scene)
        
        let location = Location(name: "Castle", detail: "A medieval castle")
        modelContext.insert(location)
        
        scene.location = location
        location.scenes = [scene]
        
        try modelContext.save()
        
        XCTAssertEqual(scene.location?.id, location.id)
        XCTAssertEqual(location.scenes?.count, 1)
    }
    
    // MARK: - Chapter Tests
    
    func testChapterCreation() {
        let chapter = Chapter(name: "Chapter 1", synopsis: "The beginning", userOrder: 1)
        modelContext.insert(chapter)
        
        XCTAssertNotNil(chapter.id)
        XCTAssertEqual(chapter.name, "Chapter 1")
        XCTAssertEqual(chapter.synopsis, "The beginning")
        XCTAssertEqual(chapter.userOrder, 1)
    }
    
    func testChapterWithMultipleScenes() throws {
        let chapter = Chapter(name: "Chapter 1")
        modelContext.insert(chapter)
        
        let scene1 = StoryScene(name: "Scene 1", userOrder: 1)
        scene1.chapter = chapter
        modelContext.insert(scene1)
        
        let scene2 = StoryScene(name: "Scene 2", userOrder: 2)
        scene2.chapter = chapter
        modelContext.insert(scene2)
        
        try modelContext.save()
        
        XCTAssertEqual(chapter.scenes?.count, 2)
        
        let sortedScenes = chapter.scenes?.sorted(by: { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }) ?? []
        XCTAssertEqual(sortedScenes.first?.name, "Scene 1")
        XCTAssertEqual(sortedScenes.last?.name, "Scene 2")
    }
    
    func testChapterProjectRelationship() throws {
        let project = Project(name: "My Novel", type: .fiction)
        project.fictionClass = .novel
        modelContext.insert(project)
        
        let chapter = Chapter(name: "Chapter 1")
        chapter.project = project
        project.chapters?.append(chapter)
        modelContext.insert(chapter)
        
        try modelContext.save()
        
        XCTAssertEqual(chapter.project?.id, project.id)
        XCTAssertEqual(project.chapters?.count, 1)
    }
    
    // MARK: - Character Tests
    
    func testCharacterCreation() {
        let character = Character(name: "Frodo", role: "Protagonist", archetypes: [.hero], history: "Born in the Shire", looks: "Short with curly hair", traits: "Brave and loyal", work: "Ring bearer")
        modelContext.insert(character)
        
        XCTAssertNotNil(character.id)
        XCTAssertEqual(character.name, "Frodo")
        XCTAssertEqual(character.role, "Protagonist")
        XCTAssertEqual(character.archetype, .hero)
        XCTAssertEqual(character.archetypes, [.hero])
        XCTAssertEqual(character.history, "Born in the Shire")
        XCTAssertEqual(character.looks, "Short with curly hair")
        XCTAssertEqual(character.traits, "Brave and loyal")
        XCTAssertEqual(character.work, "Ring bearer")
    }
    
    func testCharacterMultipleArchetypes() {
        let character = Character(name: "Gandalf", archetypes: [.mentor, .hero, .shapeshifter])
        XCTAssertEqual(character.archetypes.count, 3)
        XCTAssertTrue(character.archetypes.contains(.mentor))
        XCTAssertTrue(character.archetypes.contains(.hero))
        XCTAssertTrue(character.archetypes.contains(.shapeshifter))
        // Backward compatible: archetype returns first
        XCTAssertEqual(character.archetype, .mentor)
        // Raw stored as comma-separated
        XCTAssertTrue(character.archetypeRaw?.contains(",") ?? false)
    }
    
    func testCharacterArchetypeRoundTrip() {
        for archetype in CharacterArchetype.allCases {
            let character = Character(name: "Test", archetypes: [archetype])
            XCTAssertEqual(character.archetype, archetype)
            XCTAssertEqual(character.archetypeRaw, archetype.rawValue)
        }
    }
    
    func testCharacterWithoutArchetype() {
        let character = Character(name: "Minor Character")
        modelContext.insert(character)
        
        XCTAssertNil(character.archetype)
        XCTAssertNil(character.archetypeRaw)
        XCTAssertTrue(character.archetypes.isEmpty)
    }
    
    func testCharacterProjectRelationship() throws {
        let project = Project(name: "My Novel", type: .fiction)
        modelContext.insert(project)
        
        let character = Character(name: "Hero")
        character.project = project
        project.characters?.append(character)
        modelContext.insert(character)
        
        try modelContext.save()
        
        XCTAssertEqual(character.project?.id, project.id)
        XCTAssertEqual(project.characters?.count, 1)
    }
    
    func testCharacterCustomAttributes() throws {
        let character = Character(name: "Hero")
        modelContext.insert(character)
        
        let attr1 = CustomAttribute(key: "Eye Color", value: "Blue", userOrder: 1)
        attr1.character = character
        modelContext.insert(attr1)
        
        let attr2 = CustomAttribute(key: "Height", value: "6 ft", userOrder: 2)
        attr2.character = character
        modelContext.insert(attr2)
        
        character.customAttributes = [attr1, attr2]
        
        try modelContext.save()
        
        XCTAssertEqual(character.customAttributes?.count, 2)
    }
    
    // MARK: - Location Tests
    
    func testLocationCreation() {
        let location = Location(name: "The Shire", detail: "A peaceful land of rolling hills", sights: "Green meadows", sounds: "Birds chirping", smells: "Fresh grass")
        modelContext.insert(location)
        
        XCTAssertNotNil(location.id)
        XCTAssertEqual(location.name, "The Shire")
        XCTAssertEqual(location.detail, "A peaceful land of rolling hills")
        XCTAssertEqual(location.sights, "Green meadows")
        XCTAssertEqual(location.sounds, "Birds chirping")
        XCTAssertEqual(location.smells, "Fresh grass")
    }
    
    func testLocationProjectRelationship() throws {
        let project = Project(name: "My Novel", type: .fiction)
        modelContext.insert(project)
        
        let location = Location(name: "Castle")
        location.project = project
        project.locations?.append(location)
        modelContext.insert(location)
        
        try modelContext.save()
        
        XCTAssertEqual(location.project?.id, project.id)
        XCTAssertEqual(project.locations?.count, 1)
    }
    
    func testLocationCustomAttributes() throws {
        let location = Location(name: "Castle")
        modelContext.insert(location)
        
        let attr = CustomAttribute(key: "Built", value: "1066 AD", userOrder: 1)
        attr.location = location
        modelContext.insert(attr)
        
        location.customAttributes = [attr]
        
        try modelContext.save()
        
        XCTAssertEqual(location.customAttributes?.count, 1)
        XCTAssertEqual(location.customAttributes?.first?.key, "Built")
    }
    
    func testLocationWithMultipleScenes() throws {
        let location = Location(name: "Castle")
        modelContext.insert(location)
        
        let scene1 = StoryScene(name: "Scene 1")
        scene1.location = location
        modelContext.insert(scene1)
        
        let scene2 = StoryScene(name: "Scene 2")
        scene2.location = location
        modelContext.insert(scene2)
        
        location.scenes = [scene1, scene2]
        
        try modelContext.save()
        
        XCTAssertEqual(location.scenes?.count, 2)
    }
    
    // MARK: - PlotElement Tests
    
    func testPlotElementCreation() {
        let element = PlotElement(name: "Inciting Incident", notes: "Hero receives the call", monomythStage: .callToAdventure, userOrder: 2)
        modelContext.insert(element)
        
        XCTAssertNotNil(element.id)
        XCTAssertEqual(element.name, "Inciting Incident")
        XCTAssertEqual(element.notes, "Hero receives the call")
        XCTAssertEqual(element.monomythStage, .callToAdventure)
        XCTAssertEqual(element.userOrder, 2)
    }
    
    func testPlotElementAutoNameFromMonomythStage() {
        let element = PlotElement(monomythStage: .ordinaryWorld)
        modelContext.insert(element)
        
        // Name should default to monomyth stage localized name
        XCTAssertEqual(element.name, MonomythStage.ordinaryWorld.localizedName)
        XCTAssertEqual(element.userOrder, 1) // ordinaryWorld.order
    }
    
    func testPlotElementMonomythStageRoundTrip() {
        for stage in MonomythStage.allCases {
            let element = PlotElement(monomythStage: stage)
            XCTAssertEqual(element.monomythStage, stage)
            XCTAssertEqual(element.monomythStageRaw, stage.rawValue)
        }
    }
    
    func testPlotElementProjectRelationship() throws {
        let project = Project(name: "My Novel", type: .fiction)
        project.useMonomyth = true
        modelContext.insert(project)
        
        let element = PlotElement(name: "Opening", monomythStage: .ordinaryWorld)
        element.project = project
        project.plotElements?.append(element)
        modelContext.insert(element)
        
        try modelContext.save()
        
        XCTAssertEqual(element.project?.id, project.id)
        XCTAssertEqual(project.plotElements?.count, 1)
    }
    
    func testPlotElementSceneRelationship() throws {
        let element = PlotElement(name: "Crossing")
        modelContext.insert(element)
        
        let scene1 = StoryScene(name: "Scene 1")
        modelContext.insert(scene1)
        
        let scene2 = StoryScene(name: "Scene 2")
        modelContext.insert(scene2)
        
        element.linkedScenes = [scene1, scene2]
        
        try modelContext.save()
        
        XCTAssertEqual(element.linkedScenes?.count, 2)
        XCTAssertEqual(scene1.plotElements?.count, 1)
        XCTAssertEqual(scene2.plotElements?.count, 1)
    }
    
    // MARK: - CustomAttribute Tests
    
    func testCustomAttributeCreation() {
        let attr = CustomAttribute(key: "Age", value: "35", userOrder: 1)
        modelContext.insert(attr)
        
        XCTAssertNotNil(attr.id)
        XCTAssertEqual(attr.key, "Age")
        XCTAssertEqual(attr.value, "35")
        XCTAssertEqual(attr.userOrder, 1)
    }
    
    func testCustomAttributeCharacterVsLocation() throws {
        let character = Character(name: "Hero")
        modelContext.insert(character)
        
        let location = Location(name: "Castle")
        modelContext.insert(location)
        
        let charAttr = CustomAttribute(key: "Age", value: "25")
        charAttr.character = character
        modelContext.insert(charAttr)
        
        let locAttr = CustomAttribute(key: "Built", value: "1066")
        locAttr.location = location
        modelContext.insert(locAttr)
        
        try modelContext.save()
        
        XCTAssertNotNil(charAttr.character)
        XCTAssertNil(charAttr.location)
        XCTAssertNotNil(locAttr.location)
        XCTAssertNil(locAttr.character)
    }
    
    // MARK: - Project Fiction Integration Tests
    
    func testProjectFictionClassProperty() {
        let project = Project(name: "My Novel", type: .fiction)
        project.fictionClass = .novel
        modelContext.insert(project)
        
        XCTAssertEqual(project.fictionClass, .novel)
        XCTAssertEqual(project.fictionClassRaw, "novel")
    }
    
    func testProjectUseMonomythProperty() {
        let project = Project(name: "My Novel", type: .fiction)
        project.useMonomyth = true
        modelContext.insert(project)
        
        XCTAssertTrue(project.useMonomyth)
    }
    
    func testNovelProjectHasChaptersAndScenes() throws {
        let project = Project(name: "My Novel", type: .fiction)
        project.fictionClass = .novel
        modelContext.insert(project)
        
        // Add chapter with scenes
        let chapter = Chapter(name: "Chapter 1", userOrder: 1)
        chapter.project = project
        modelContext.insert(chapter)
        
        let scene1 = StoryScene(name: "Scene 1", userOrder: 1)
        scene1.chapter = chapter
        scene1.project = project
        modelContext.insert(scene1)
        
        let scene2 = StoryScene(name: "Scene 2", userOrder: 2)
        scene2.chapter = chapter
        scene2.project = project
        modelContext.insert(scene2)
        
        // chapter.scenes derived from scene.chapter = chapter (set above)
        project.chapters = [chapter]
        project.scenes = [scene1, scene2]
        
        try modelContext.save()
        
        XCTAssertEqual(project.chapters?.count, 1)
        XCTAssertEqual(project.scenes?.count, 2)
        XCTAssertEqual(chapter.scenes?.count, 2)
    }
    
    func testShortFictionProjectHasScenesWithoutChapters() throws {
        let project = Project(name: "My Short Story", type: .fiction)
        project.fictionClass = .shortFiction
        modelContext.insert(project)
        
        // Add scenes directly (no chapters)
        let scene1 = StoryScene(name: "Scene 1", userOrder: 1)
        scene1.project = project
        modelContext.insert(scene1)
        
        let scene2 = StoryScene(name: "Scene 2", userOrder: 2)
        scene2.project = project
        modelContext.insert(scene2)
        
        project.scenes = [scene1, scene2]
        
        try modelContext.save()
        
        XCTAssertEqual(project.scenes?.count, 2)
        XCTAssertEqual(project.chapters?.count ?? 0, 0)
        XCTAssertNil(scene1.chapter)
        XCTAssertNil(scene2.chapter)
    }
    
    func testMonomythProjectHasPlotElements() throws {
        let project = Project(name: "Hero's Journey Novel", type: .fiction)
        project.fictionClass = .novel
        project.useMonomyth = true
        modelContext.insert(project)
        
        // Create plot elements for each monomyth stage
        for stage in MonomythStage.allCases {
            let element = PlotElement(monomythStage: stage)
            element.project = project
            modelContext.insert(element)
        }
        
        try modelContext.save()
        
        let elements = try modelContext.fetch(FetchDescriptor<PlotElement>())
        XCTAssertEqual(elements.count, 12)
        
        // Verify all stages are represented
        let stages = Set(elements.compactMap { $0.monomythStage })
        XCTAssertEqual(stages.count, 12)
    }
    
    // MARK: - Cascade Delete Tests
    
    func testDeletingProjectCascadesDeletesScenes() throws {
        let project = Project(name: "Test Project", type: .fiction)
        modelContext.insert(project)
        
        let scene = StoryScene(name: "Scene 1")
        scene.project = project
        project.scenes = [scene]
        modelContext.insert(scene)
        
        try modelContext.save()
        
        let scenesBefore = try modelContext.fetch(FetchDescriptor<StoryScene>())
        XCTAssertEqual(scenesBefore.count, 1)
        
        modelContext.delete(project)
        try modelContext.save()
        
        let scenesAfter = try modelContext.fetch(FetchDescriptor<StoryScene>())
        XCTAssertEqual(scenesAfter.count, 0)
    }
    
    func testDeletingProjectCascadesDeletesChapters() throws {
        let project = Project(name: "Test Project", type: .fiction)
        modelContext.insert(project)
        
        let chapter = Chapter(name: "Chapter 1")
        chapter.project = project
        project.chapters = [chapter]
        modelContext.insert(chapter)
        
        try modelContext.save()
        
        let chaptersBefore = try modelContext.fetch(FetchDescriptor<Chapter>())
        XCTAssertEqual(chaptersBefore.count, 1)
        
        modelContext.delete(project)
        try modelContext.save()
        
        let chaptersAfter = try modelContext.fetch(FetchDescriptor<Chapter>())
        XCTAssertEqual(chaptersAfter.count, 0)
    }
    
    func testDeletingProjectCascadesDeletesCharacters() throws {
        let project = Project(name: "Test Project", type: .fiction)
        modelContext.insert(project)
        
        let character = Character(name: "Hero")
        character.project = project
        project.characters = [character]
        modelContext.insert(character)
        
        try modelContext.save()
        
        modelContext.delete(project)
        try modelContext.save()
        
        let charactersAfter = try modelContext.fetch(FetchDescriptor<Character>())
        XCTAssertEqual(charactersAfter.count, 0)
    }
    
    func testDeletingProjectCascadesDeletesLocations() throws {
        let project = Project(name: "Test Project", type: .fiction)
        modelContext.insert(project)
        
        let location = Location(name: "Castle")
        location.project = project
        project.locations = [location]
        modelContext.insert(location)
        
        try modelContext.save()
        
        modelContext.delete(project)
        try modelContext.save()
        
        let locationsAfter = try modelContext.fetch(FetchDescriptor<Location>())
        XCTAssertEqual(locationsAfter.count, 0)
    }
    
    func testDeletingProjectCascadesDeletesPlotElements() throws {
        let project = Project(name: "Test Project", type: .fiction)
        modelContext.insert(project)
        
        let element = PlotElement(name: "Opening")
        element.project = project
        project.plotElements = [element]
        modelContext.insert(element)
        
        try modelContext.save()
        
        modelContext.delete(project)
        try modelContext.save()
        
        let elementsAfter = try modelContext.fetch(FetchDescriptor<PlotElement>())
        XCTAssertEqual(elementsAfter.count, 0)
    }
    
    func testDeletingCharacterCascadesDeletesCustomAttributes() throws {
        let character = Character(name: "Hero")
        modelContext.insert(character)
        
        let attr = CustomAttribute(key: "Age", value: "25")
        attr.character = character
        character.customAttributes = [attr]
        modelContext.insert(attr)
        
        try modelContext.save()
        
        let attrsBefore = try modelContext.fetch(FetchDescriptor<CustomAttribute>())
        XCTAssertEqual(attrsBefore.count, 1)
        
        modelContext.delete(character)
        try modelContext.save()
        
        let attrsAfter = try modelContext.fetch(FetchDescriptor<CustomAttribute>())
        XCTAssertEqual(attrsAfter.count, 0)
    }
    
    func testDeletingLocationCascadesDeletesCustomAttributes() throws {
        let location = Location(name: "Castle")
        modelContext.insert(location)
        
        let attr = CustomAttribute(key: "Built", value: "1066")
        attr.location = location
        location.customAttributes = [attr]
        modelContext.insert(attr)
        
        try modelContext.save()
        
        modelContext.delete(location)
        try modelContext.save()
        
        let attrsAfter = try modelContext.fetch(FetchDescriptor<CustomAttribute>())
        XCTAssertEqual(attrsAfter.count, 0)
    }
}
