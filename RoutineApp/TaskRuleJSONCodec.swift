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
    case invalidTimeFormat(String)
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
        case .invalidTimeFormat(let value):
            return "Неверный формат времени: \(value). Нужен HH:mm"
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

        for dto in payload.tasks {
            let rule = try dto.toTaskRule()
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
    let title: String
    let scheduleType: String
    let weeklyDays: [String]
    let intervalDays: Int?
    let startDate: String?
    let startTime: String?
    let isImportant: Bool
    let notes: String?
    let isActive: Bool

    init(rule: TaskRule) {
        self.id = rule.id
        self.title = rule.title
        self.scheduleType = rule.scheduleType.rawValue
        self.weeklyDays = rule.weeklyDays.map(\.jsonKey)
        self.intervalDays = rule.intervalDays
        self.startDate = Self.dateFormatter.stringOrNil(from: rule.startDate)
        self.startTime = Self.timeString(hour: rule.startTimeHour, minute: rule.startTimeMinute)
        self.isImportant = rule.isImportant
        self.notes = rule.notes
        self.isActive = rule.isActive
    }

    func toTaskRule() throws -> TaskRule {
        guard let resolvedSchedule = TaskScheduleType(rawValue: scheduleType) else {
            throw TaskRuleJSONCodecError.invalidScheduleType(scheduleType)
        }

        let resolvedWeekly = try weeklyDays.map { value in
            guard let day = Weekday(jsonKey: value) else {
                throw TaskRuleJSONCodecError.invalidWeekday(value)
            }
            return day
        }

        let resolvedStartDate: Date?
        if let startDate {
            guard let date = Self.dateFormatter.date(from: startDate) else {
                throw TaskRuleJSONCodecError.invalidDateFormat(startDate)
            }
            resolvedStartDate = date
        } else {
            resolvedStartDate = nil
        }

        let (hour, minute) = try Self.parseTime(startTime)

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
            title: title,
            scheduleType: resolvedSchedule,
            weeklyDays: resolvedWeekly,
            intervalDays: intervalDays,
            startDate: resolvedStartDate,
            startTimeHour: hour,
            startTimeMinute: minute,
            isImportant: isImportant,
            notes: notes,
            isActive: isActive
        )
    }

    private static func parseTime(_ value: String?) throws -> (Int?, Int?) {
        guard let value, !value.isEmpty else { return (nil, nil) }
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            throw TaskRuleJSONCodecError.invalidTimeFormat(value)
        }
        return (hour, minute)
    }

    private static func timeString(hour: Int?, minute: Int?) -> String? {
        guard let hour, let minute else { return nil }
        return String(format: "%02d:%02d", hour, minute)
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

