//
//  RoutineAppApp.swift
//  RoutineApp
//
//  Created by Анита Надвикова on 06.04.2026.
//

import SwiftUI
import SwiftData

@main
struct RoutineAppApp: App {
    private let sharedModelContainer: ModelContainer

    @MainActor
    init() {
        let container = ModelContainerFactory.makeSharedContainer()
        try? TaskCompletionHistoryCleaner.removeEntriesOlderThanCurrentWeek(from: container)
        sharedModelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
