//
//  JoinModels.swift
//  Writing Shed Pro
//
//  CloudKit does not support many-to-many relationships.
//  Each join model below converts a many-to-many into two one-to-many
//  relationships, which CloudKit can sync.
//
//  Pattern:  SideA  1──*  JoinRecord  *──1  SideB
//

import Foundation
import SwiftData

// MARK: - TextFile ↔ ProseSection

/// Join record linking a TextFile to a ProseSection.
@Model
final class TextFileSectionLink {
    var id: UUID = UUID()
    var textFile: TextFile?
    var section: ProseSection?
    var userOrder: Int?

    init(textFile: TextFile? = nil, section: ProseSection? = nil, userOrder: Int? = nil) {
        self.textFile = textFile
        self.section = section
        self.userOrder = userOrder
    }
}

// MARK: - TextFile ↔ PoetryCollection

/// Join record linking a TextFile to a PoetryCollection.
@Model
final class TextFileCollectionLink {
    var id: UUID = UUID()
    var textFile: TextFile?
    var poetryCollection: PoetryCollection?
    var userOrder: Int?

    init(textFile: TextFile? = nil, poetryCollection: PoetryCollection? = nil, userOrder: Int? = nil) {
        self.textFile = textFile
        self.poetryCollection = poetryCollection
        self.userOrder = userOrder
    }
}

// MARK: - StoryScene ↔ Chapter

/// Join record linking a StoryScene to a Chapter.
@Model
final class SceneChapterLink {
    var id: UUID = UUID()
    var scene: StoryScene?
    var chapter: Chapter?

    init(scene: StoryScene? = nil, chapter: Chapter? = nil) {
        self.scene = scene
        self.chapter = chapter
    }
}

// MARK: - StoryScene ↔ Act

/// Join record linking a StoryScene to an Act.
@Model
final class SceneActLink {
    var id: UUID = UUID()
    var scene: StoryScene?
    var act: Act?

    init(scene: StoryScene? = nil, act: Act? = nil) {
        self.scene = scene
        self.act = act
    }
}

// MARK: - StoryScene ↔ Book

/// Join record linking a StoryScene to a Book.
@Model
final class SceneBookLink {
    var id: UUID = UUID()
    var scene: StoryScene?
    var book: Book?

    init(scene: StoryScene? = nil, book: Book? = nil) {
        self.scene = scene
        self.book = book
    }
}

// MARK: - StoryScene ↔ PlotElement

/// Join record linking a StoryScene to a PlotElement.
@Model
final class ScenePlotElementLink {
    var id: UUID = UUID()
    var scene: StoryScene?
    var plotElement: PlotElement?

    init(scene: StoryScene? = nil, plotElement: PlotElement? = nil) {
        self.scene = scene
        self.plotElement = plotElement
    }
}

// MARK: - StoryScene ↔ Character

/// Join record linking a StoryScene to a Character.
@Model
final class SceneCharacterLink {
    var id: UUID = UUID()
    var scene: StoryScene?
    var character: Character?

    init(scene: StoryScene? = nil, character: Character? = nil) {
        self.scene = scene
        self.character = character
    }
}

// MARK: - Character ↔ PlotElement

/// Join record linking a Character to a PlotElement.
@Model
final class CharacterPlotElementLink {
    var id: UUID = UUID()
    var character: Character?
    var plotElement: PlotElement?

    init(character: Character? = nil, plotElement: PlotElement? = nil) {
        self.character = character
        self.plotElement = plotElement
    }
}

// MARK: - Location ↔ PlotElement

/// Join record linking a Location to a PlotElement.
@Model
final class LocationPlotElementLink {
    var id: UUID = UUID()
    var location: Location?
    var plotElement: PlotElement?

    init(location: Location? = nil, plotElement: PlotElement? = nil) {
        self.location = location
        self.plotElement = plotElement
    }
}
