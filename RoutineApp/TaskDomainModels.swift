//
//  TaskDomainModels.swift
//  RoutineApp
//
//  Created by Codex on 06.04.2026.
//

import Foundation
import SwiftData

@Model
final class TaskRule {
    var id: UUID
    var rule: String
    var isEnabled: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        rule: String = "",
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.rule = rule
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    convenience init(rule: String) {
        self.init(rule: rule, isEnabled: true)
    }
}

@Model
final class TaskCompletion {
    var id: UUID
    var createdAt: Date

    init(id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id
        self.createdAt = createdAt
    }
}

@Model
final class UserList {
    var id: UUID
    var title: String
    @Relationship(deleteRule: .cascade, inverse: \UserListItem.list)
    var items: [UserListItem]

    init(id: UUID = UUID(), title: String = "", items: [UserListItem] = []) {
        self.id = id
        self.title = title
        self.items = items
    }
}

@Model
final class UserListItem {
    var id: UUID
    var title: String
    var text: String
    var isCompleted: Bool
    var createdAt: Date
    var list: UserList?

    init(
        id: UUID = UUID(),
        title: String = "",
        text: String = "",
        isCompleted: Bool = false,
        createdAt: Date = .now,
        list: UserList? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.list = list
    }

    convenience init(text: String, isCompleted: Bool, list: UserList) {
        self.init(
            title: text,
            text: text,
            isCompleted: isCompleted,
            createdAt: .now,
            list: list
        )
    }
}

@Model
final class QuickTask {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        isCompleted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
