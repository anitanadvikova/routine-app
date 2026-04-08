//
//  TodayWidgetSnapshotStore.swift
//  RoutineApp
//
//  Created by Codex on 06.04.2026.
//

import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

struct TodayWidgetSnapshot: Codable {
    let generatedAt: Date
    let tasks: [TodayWidgetTaskSnapshot]
}

struct TodayWidgetTaskSnapshot: Codable {
    let title: String
}

@MainActor
enum TodayWidgetSnapshotStore {
    static func refresh(using modelContainer: ModelContainer) {
        refresh(using: modelContainer.mainContext)
    }

    static func refresh(using modelContext: ModelContext) {
        guard let snapshotURL = AppGroupConfig.todayWidgetSnapshotURL else {
            return
        }

        do {
            let rules = try modelContext.fetch(FetchDescriptor<TaskRule>())
            let completions = try modelContext.fetch(FetchDescriptor<TaskCompletion>())
            let snapshot = makeSnapshot(rules: rules, completions: completions)
            let data = try JSONEncoder().encode(snapshot)

            try FileManager.default.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: snapshotURL, options: .atomic)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            assertionFailure("Failed to refresh widget snapshot: \(error)")
        }
    }

    private static func makeSnapshot(rules: [TaskRule], completions: [TaskCompletion]) -> TodayWidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let completedTaskIDsInPast = Set(
            completions
                .filter { $0.isCompleted && calendar.startOfDay(for: $0.date) < today }
                .map(\.taskId)
        )
        let completedTaskIDsToday = Set(
            completions
                .filter { $0.isCompleted && calendar.isDate($0.date, inSameDayAs: today) }
                .map(\.taskId)
        )

        let tasks = rules
            .filter(\.isActive)
            .filter { rule in
                switch rule.scheduleType {
                case .weekly:
                    return rule.weeklyDaysRaw.contains(weekday)
                case .interval:
                    guard let interval = rule.intervalDays,
                          interval > 0,
                          let startDate = rule.startDate else {
                        return false
                    }

                    let start = calendar.startOfDay(for: startDate)
                    guard start <= today else { return false }
                    let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
                    return days % interval == 0
                case .floating:
                    return !completedTaskIDsInPast.contains(rule.id) || completedTaskIDsToday.contains(rule.id)
                }
            }
            .filter { !completedTaskIDsToday.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .map { rule in
                TodayWidgetTaskSnapshot(
                    title: rule.title
                )
            }

        return TodayWidgetSnapshot(generatedAt: today, tasks: tasks)
    }
}
