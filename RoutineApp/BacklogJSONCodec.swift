//
//  BacklogJSONCodec.swift
//  RoutineApp
//
//  Created by Codex on 06.04.2026.
//

import Foundation
import SwiftData

struct BacklogJSONCodec {
    @MainActor
    static func exportJSONString(from lists: [UserList], quickTasks: [QuickTask]) throws -> String {
        let encoder = makeJSONEncoder()
        let sortedLists = lists.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let sortedQuickTasks = quickTasks.sorted { $0.createdAt < $1.createdAt }

        var listPayloads: [BacklogListPayload] = []
        listPayloads.reserveCapacity(sortedLists.count)
        for list in sortedLists {
            listPayloads.append(BacklogListPayload(list: list))
        }

        var quickTaskPayloads: [BacklogQuickTaskPayload] = []
        quickTaskPayloads.reserveCapacity(sortedQuickTasks.count)
        for task in sortedQuickTasks {
            quickTaskPayloads.append(BacklogQuickTaskPayload(task: task))
        }

        let payload = BacklogPayload(
            lists: listPayloads,
            weekTasks: quickTaskPayloads
        )
        let data = try encoder.encode(payload)
        return String(decoding: data, as: UTF8.self)
    }

    @MainActor
    static func replaceLists(from jsonText: String, modelContext: ModelContext) throws {
        let decoder = JSONDecoder()
        let data = Data(jsonText.utf8)
        let payload = try decodePayload(from: data, using: decoder)

        let existingLists = try modelContext.fetch(FetchDescriptor<UserList>())
        for list in existingLists {
            modelContext.delete(list)
        }

        let existingQuickTasks = try modelContext.fetch(FetchDescriptor<QuickTask>())
        for task in existingQuickTasks {
            modelContext.delete(task)
        }
        try modelContext.save()

        for listPayload in payload.lists {
            let list = UserList(title: listPayload.list)
            modelContext.insert(list)

            for task in listPayload.tasks {
                let item = UserListItem(text: task.text, comment: task.comment, list: list)
                item.isImportant = task.isImportant ?? false
                modelContext.insert(item)
                list.items.append(item)
            }
        }

        for task in payload.weekTasks {
            modelContext.insert(
                QuickTask(
                    title: task.title,
                    comment: task.comment,
                    isChecked: task.isChecked,
                    isImportant: task.isImportant,
                    createdAt: task.createdAt
                )
            )
        }

        try modelContext.save()
    }

    private static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func decodePayload(from data: Data, using decoder: JSONDecoder) throws -> BacklogPayload {
        if let payload = try? decoder.decode(BacklogPayload.self, from: data) {
            return payload
        }

        let legacyLists = try decoder.decode([BacklogListPayload].self, from: data)
        return BacklogPayload(lists: legacyLists, weekTasks: [])
    }
}

struct BacklogPayload: Codable {
    let lists: [BacklogListPayload]
    let weekTasks: [BacklogQuickTaskPayload]
}

struct BacklogListPayload: Codable {
    let list: String
    let tasks: [BacklogTaskPayload]

    @MainActor
    init(list: UserList) {
        self.list = list.title
        let sortedItems = list.items.sorted { $0.createdAt < $1.createdAt }
        var tasks: [BacklogTaskPayload] = []
        tasks.reserveCapacity(sortedItems.count)
        for item in sortedItems {
            tasks.append(BacklogTaskPayload(item: item))
        }
        self.tasks = tasks
    }
}

struct BacklogTaskPayload: Codable {
    let text: String
    let comment: String?
    let isImportant: Bool?

    init(item: UserListItem) {
        self.text = item.text
        self.comment = item.comment
        self.isImportant = item.isImportant
    }

    init(from decoder: Decoder) throws {
        let singleValueContainer = try? decoder.singleValueContainer()
        if let text = try? singleValueContainer?.decode(String.self) {
            self.text = text
            self.comment = nil
            self.isImportant = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decode(String.self, forKey: .text)
        self.comment = try container.decodeIfPresent(String.self, forKey: .comment)
        self.isImportant = try container.decodeIfPresent(Bool.self, forKey: .isImportant)
    }
}

struct BacklogQuickTaskPayload: Codable {
    let title: String
    let comment: String?
    let isChecked: Bool
    let isImportant: Bool
    let createdAt: Date

    init(task: QuickTask) {
        self.title = task.title
        self.comment = task.comment
        self.isChecked = task.isChecked
        self.isImportant = task.isImportant
        self.createdAt = task.createdAt
    }
}
