//
//  ModelContainerFactory.swift
//  RoutineApp
//
//  Created by Cursor on 06.04.2026.
//

import Foundation
import SwiftData

enum AppGroupConfig {
    // Replace with your own Team ID based identifier.
    static let identifier = "group.com.example.routineapp"

    static var todayWidgetSnapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)?
            .appendingPathComponent("TodayWidgetSnapshot.json")
    }

    static var sharedStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)?
            .appendingPathComponent("Routine.sqlite")
    }
}

enum ModelContainerFactory {
    static func makeSharedContainer() -> ModelContainer {
        let schema = Schema([
            TaskRule.self,
            TaskCompletion.self,
            UserList.self,
            UserListItem.self,
            QuickTask.self
        ])

        do {
            if let sharedURL = AppGroupConfig.sharedStoreURL {
                let configuration = ModelConfiguration(schema: schema, url: sharedURL)
                return try ModelContainer(for: schema, configurations: [configuration])
            } else {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [fallback])
            }
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }
}

enum TaskCompletionHistoryCleaner {
    @MainActor
    static func removeEntriesOlderThanCurrentWeek(from container: ModelContainer) throws {
        let context = container.mainContext
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        let descriptor = FetchDescriptor<TaskCompletion>(
            predicate: #Predicate<TaskCompletion> { completion in
                completion.date < weekStart
            }
        )
        let outdatedCompletions = try context.fetch(descriptor)

        guard !outdatedCompletions.isEmpty else {
            return
        }

        for completion in outdatedCompletions {
            context.delete(completion)
        }

        try context.save()
    }
}
