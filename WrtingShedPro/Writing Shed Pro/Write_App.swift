//
//  Write_App.swift
//  Write!
//
//  Created by Keith Lander on 21/10/2025.
//

import SwiftUI
import SwiftData

@main
struct Write_App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Project.self,
            File.self,
            Folder.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // Remove File menu items
            CommandGroup(replacing: .newItem) { }
            
            // Remove Edit menu items
            CommandGroup(replacing: .undoRedo) { }
            CommandGroup(replacing: .pasteboard) { }
            CommandGroup(replacing: .textEditing) { }
            
            // Remove View menu items
            CommandGroup(replacing: .toolbar) { }
            CommandGroup(replacing: .sidebar) { }
            
            // Remove Window menu items
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .windowArrangement) { }
            
            // Remove Help menu
            CommandGroup(replacing: .help) { }
        }
    }
}
