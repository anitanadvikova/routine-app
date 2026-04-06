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
    static func exportJSONString(from lists: [UserList]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = lists
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map(BacklogListPayload.init(list:))
        let data = try encoder.encode(payload)
        return String(decoding: data, as: UTF8.self)
    }

    @MainActor
    static func replaceLists(from jsonText: String, modelContext: ModelContext) throws {
        let decoder = JSONDecoder()
        let data = Data(jsonText.utf8)
        let payload = try decoder.decode([BacklogListPayload].self, from: data)

        let existingLists = try modelContext.fetch(FetchDescriptor<UserList>())
        for list in existingLists {
            modelContext.delete(list)
        }

        for listPayload in payload {
            let list = UserList(title: listPayload.list)
            modelContext.insert(list)

            for task in listPayload.tasks {
                let item = UserListItem(text: task, list: list)
                modelContext.insert(item)
                list.items.append(item)
            }
        }

        try modelContext.save()
    }
}

struct BacklogListPayload: Codable {
    let list: String
    let tasks: [String]

    @MainActor
    init(list: UserList) {
        self.list = list.title
        self.tasks = list.items
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.text)
    }
}
