//
//  TaskRuleJSONCodec.swift
//  RoutineApp
//
//  Created by Cursor on 06.04.2026.
//

import Foundation
import SwiftData

enum TaskRuleJSONCodecError: LocalizedError {
    case invalidScheduleType(String)
    case invalidWeekday(String)
    case invalidDateFormat(String)
    case invalidWeeklyDays
    case invalidIntervalDays
    case missingIntervalStartDate

    var errorDescription: String? {
        switch self {
        case .invalidScheduleType(let value):
            return "Неизвестный scheduleType: \(value)"
        case .invalidWeekday(let value):
            return "Неизвестный день недели: \(value)"
        case .invalidDateFormat(let value):
            return "Неверный формат даты: \(value). Нужен yyyy-MM-dd"
        case .invalidWeeklyDays:
            return "Для weekly нужно выбрать хотя бы один weekday"
        case .invalidIntervalDays:
            return "Для interval intervalDays должен быть >= 1"
        case .missingIntervalStartDate:
            return "Для interval обязательна startDate"
        }
    }
}

struct TaskRuleJSONCodec {
    @MainActor
    static func exportJSONString(from rules: [TaskRule]) throws -> String {
        let payload = RoutineRulesPayload(
            version: 1,
            tasks: rules.map(RoutineTaskDTO.init(rule:))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        return String(decoding: data, as: UTF8.self)
    }

    static func replaceRules(from jsonText: String, modelContext: ModelContext) throws {
        let decoder = JSONDecoder()
        let data = Data(jsonText.utf8)
        let payload = try decoder.decode(RoutineRulesPayload.self, from: data)

        let existing = try modelContext.fetch(FetchDescriptor<TaskRule>())
        for rule in existing {
            modelContext.delete(rule)
        }

        for (index, dto) in payload.tasks.enumerated() {
            let rule = try dto.toTaskRule(defaultSortOrder: index)
            modelContext.insert(rule)
        }

        try modelContext.save()
    }
}

struct RoutineRulesPayload: Codable {
    let version: Int
    let tasks: [RoutineTaskDTO]
}

struct RoutineTaskDTO: Codable {
    let id: UUID
    let sortOrder: Int?
    let title: String
    let scheduleType: String
    let weeklyDays: [String]
    let intervalDays: Int?
    let startDate: String?
    let isImportant: Bool
    let markerColor: String?
    let notes: String?
    let isActive: Bool

    @MainActor
    init(rule: TaskRule) {
        self.id = rule.id
        self.sortOrder = rule.sortOrder
        self.title = rule.title
        self.scheduleType = rule.scheduleType.rawValue
        self.weeklyDays = rule.weeklyDays.map(\.jsonKey)
        self.intervalDays = rule.intervalDays
        self.startDate = Self.dateFormatter.stringOrNil(from: rule.startDate)
        self.isImportant = rule.isImportant
        self.markerColor = rule.markerColor.rawValue
        self.notes = rule.notes
        self.isActive = rule.isActive
    }

    func toTaskRule(defaultSortOrder: Int) throws -> TaskRule {
        guard let resolvedSchedule = TaskScheduleType(rawValue: scheduleType) else {
            throw TaskRuleJSONCodecError.invalidScheduleType(scheduleType)
        }

        let resolvedWeekly = try weeklyDays.map { value in
            guard let day = Weekday(jsonKey: value) else {
                throw TaskRuleJSONCodecError.invalidWeekday(value)
            }
            return day
        }
        let resolvedMarkerColor = TaskMarkerColor(rawValue: markerColor ?? "") ?? .white

        let resolvedStartDate: Date?
        if let startDate {
            guard let date = Self.dateFormatter.date(from: startDate) else {
                throw TaskRuleJSONCodecError.invalidDateFormat(startDate)
            }
            resolvedStartDate = date
        } else {
            resolvedStartDate = nil
        }

        if resolvedSchedule == .weekly, resolvedWeekly.isEmpty {
            throw TaskRuleJSONCodecError.invalidWeeklyDays
        }
        if resolvedSchedule == .interval {
            guard let intervalDays, intervalDays >= 1 else {
                throw TaskRuleJSONCodecError.invalidIntervalDays
            }
            guard resolvedStartDate != nil else {
                throw TaskRuleJSONCodecError.missingIntervalStartDate
            }
        }

        return TaskRule(
            id: id,
            sortOrder: sortOrder ?? defaultSortOrder,
            title: title,
            scheduleType: resolvedSchedule,
            weeklyDays: resolvedWeekly,
            intervalDays: intervalDays,
            startDate: resolvedStartDate,
            isImportant: isImportant,
            markerColor: resolvedMarkerColor,
            notes: notes,
            isActive: isActive
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension DateFormatter {
    func stringOrNil(from date: Date?) -> String? {
        guard let date else { return nil }
        return string(from: date)
    }
}

private extension Weekday {
    var jsonKey: String {
        switch self {
        case .monday: return "monday"
        case .tuesday: return "tuesday"
        case .wednesday: return "wednesday"
        case .thursday: return "thursday"
        case .friday: return "friday"
        case .saturday: return "saturday"
        case .sunday: return "sunday"
        }
    }

    init?(jsonKey: String) {
        switch jsonKey.lowercased() {
        case "monday": self = .monday
        case "tuesday": self = .tuesday
        case "wednesday": self = .wednesday
        case "thursday": self = .thursday
        case "friday": self = .friday
        case "saturday": self = .saturday
        case "sunday": self = .sunday
        default: return nil
        }
    }
}//
//  TaskRuleJSONCodec.swift
//  RoutineApp
//
//  Created by Анита Надвикова on 06.04.2026.
//
