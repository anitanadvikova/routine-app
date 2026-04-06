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
    var createdAt: Date

    init(id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id
        self.createdAt = createdAt
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

    init(id: UUID = UUID(), title: String = "") {
        self.id = id
        self.title = title
    }
}

@Model
final class UserListItem {
    var id: UUID
    var title: String

    init(id: UUID = UUID(), title: String = "") {
        self.id = id
        self.title = title
    }
}

@Model
final class QuickTask {
    var id: UUID
    var title: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String = "", createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}
