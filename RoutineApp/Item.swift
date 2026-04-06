//
//  Item.swift
//  RoutineApp
//
//  Created by Анита Надвикова on 06.04.2026.
//

import Foundation
import SwiftData

enum TaskScheduleType: String, Codable, CaseIterable {
    case weekly
    case interval
    case floating
}

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }
}

@Model
final class TaskRule {
    var id: UUID
    var title: String
    var scheduleTypeRaw: String
    var weeklyDaysRaw: [Int]
    var intervalDays: Int?
    var startDate: Date?
    var startTimeHour: Int?
    var startTimeMinute: Int?
    var isImportant: Bool
    var notes: String?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        title: String,
        scheduleType: TaskScheduleType,
        weeklyDays: [Weekday] = [],
        intervalDays: Int? = nil,
        startDate: Date? = nil,
        startTimeHour: Int? = nil,
        startTimeMinute: Int? = nil,
        isImportant: Bool = false,
        notes: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title
        self.scheduleTypeRaw = scheduleType.rawValue
        self.weeklyDaysRaw = weeklyDays.map(\.rawValue)
        self.intervalDays = intervalDays
        self.startDate = startDate
        self.startTimeHour = startTimeHour
        self.startTimeMinute = startTimeMinute
        self.isImportant = isImportant
        self.notes = notes
        self.isActive = isActive
    }
}

extension TaskRule {
    var scheduleType: TaskScheduleType {
        get { TaskScheduleType(rawValue: scheduleTypeRaw) ?? .floating }
        set { scheduleTypeRaw = newValue.rawValue }
    }

    var weeklyDays: [Weekday] {
        get { weeklyDaysRaw.compactMap(Weekday.init(rawValue:)).sorted { $0.rawValue < $1.rawValue } }
        set { weeklyDaysRaw = newValue.map(\.rawValue) }
    }
}

@Model
final class TaskCompletion {
    var id: UUID
    var taskId: UUID
    var date: Date
    var isCompleted: Bool
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        taskId: UUID,
        date: Date,
        isCompleted: Bool,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.date = Calendar.current.startOfDay(for: date)
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

@Model
final class UserList {
    var id: UUID
    var title: String

    @Relationship(deleteRule: .cascade, inverse: \UserListItem.list)
    var items: [UserListItem]

    init(id: UUID = UUID(), title: String, items: [UserListItem] = []) {
        self.id = id
        self.title = title
        self.items = items
    }
}

@Model
final class UserListItem {
    var id: UUID
    var text: String
    var isCompleted: Bool
    var createdAt: Date

    var list: UserList?

    init(
        id: UUID = UUID(),
        text: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        list: UserList? = nil
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.list = list
    }
}

@Model
final class QuickTask {
    var id: UUID
    var title: String
    var isChecked: Bool
    var isImportant: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isChecked: Bool = false,
        isImportant: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isChecked = isChecked
        self.isImportant = isImportant
        self.createdAt = createdAt
    }
}
