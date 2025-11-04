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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Project.self,
            File.self,
            Folder.self,
            StyleSheet.self,
            TextStyleModel.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.appworks.writingshedpro")
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Initialize default stylesheets on first launch
            let context = container.mainContext
            StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
