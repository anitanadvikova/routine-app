//
//  TodayView.swift
//  RoutineApp
//
//  Created by Cursor on 06.04.2026.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [TaskRule]
    private let hiddenRuleIDsDefaultsKeyPrefix = "TodayView.hiddenRuleIDs"
    @Binding var selectedDate: Date
    @State private var weeklyCompletions: [TaskCompletion] = []
    @State private var completedTaskIDsForSelectedDate: Set<UUID> = []
    @State private var visibleRules: [TaskRule] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("День недели", selection: $selectedDate) {
                        ForEach(currentWeekDates, id: \.self) { date in
                            Text(weekdayText(for: date))
                                .tag(date)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("Дата")
                        Spacer()
                        Text(selectedDate, format: .dateTime.day().month().year())
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Рутинные задачи на сегодня") {
                    if visibleRules.isEmpty {
                        Text("На сегодня нет рутинных задач")
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(visibleRules, id: \.id) { rule in
                            let completionState = isCompletedToday(rule)
                            let comment = normalizedComment(rule.notes)

                            HStack(spacing: 10) {
                                Image(systemName: completionState ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(completionState ? .green : .secondary)
                                    .frame(width: 22, height: 22)

                                if rule.isImportant {
                                    Circle()
                                        .fill(.orange)
                                        .frame(width: 8, height: 8)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.title)
                                        .strikethrough(completionState, color: .secondary)
                                        .foregroundStyle(completionState ? .secondary : .primary)
                                    if let comment {
                                        Text(comment)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: 38, alignment: comment == nil ? .center : .top)

                            }
                            .contentShape(Rectangle())
                            .listRowSeparator(.hidden)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(rule.markerColor.pastelBackgroundColor)
                                    .padding(.vertical, 4)
                            )
                            .onTapGesture {
                                toggleCompletion(for: rule)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    hideRule(rule)
                                } label: {
                                    Label("Скрыть", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("Управление") {
                    NavigationLink {
                        RoutineRulesView()
                    } label: {
                        Label("Редактировать правила рутины", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .navigationTitle("Сегодня")
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 8)
            }
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Неизвестная ошибка")
            }
            .task {
                refreshWeeklyCompletions()
                refreshVisibleRules()
            }
            .onChange(of: selectedDate) { _, _ in
                updateCompletedTaskIDsForSelectedDate()
                refreshVisibleRules()
            }
            .onChange(of: rules.count) { _, _ in
                refreshVisibleRules()
            }
        }
    }

    private func rulesForSelectedDate(from rules: [TaskRule]) -> [TaskRule] {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)
        let weekday = calendar.component(.weekday, from: targetDate)
        let hiddenRuleIDs = hiddenRuleIDs(for: targetDate)

        return rules
            .filter(\.isActive)
            .filter { rule in
                switch rule.scheduleType {
                case .weekly:
                    return rule.weeklyDaysRaw.contains(weekday)
                case .interval:
                    guard let interval = rule.intervalDays, interval > 0,
                          let startDate = rule.startDate else {
                        return false
                    }
                    let start = calendar.startOfDay(for: startDate)
                    guard start <= targetDate else { return false }
                    let days = calendar.dateComponents([.day], from: start, to: targetDate).day ?? 0
                    return days % interval == 0
                case .floating:
                    return true
                }
            }
            .filter { !hiddenRuleIDs.contains($0.id.uuidString) }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    private func isCompletedToday(_ rule: TaskRule) -> Bool {
        completedTaskIDsForSelectedDate.contains(rule.id)
    }

    private func toggleCompletion(for rule: TaskRule) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: selectedDate)

        if let existing = weeklyCompletions.first(where: { $0.taskId == rule.id && calendar.isDate($0.date, inSameDayAs: today) }) {
            existing.isCompleted.toggle()
            existing.completedAt = existing.isCompleted ? Date() : nil
        } else {
            let completion = TaskCompletion(
                taskId: rule.id,
                date: today,
                isCompleted: true,
                completedAt: Date()
            )
            modelContext.insert(completion)
            weeklyCompletions.append(completion)
        }

        do {
            try modelContext.save()
            updateCompletedTaskIDsForSelectedDate()
            unhideRule(rule, on: today)
            refreshVisibleRules()
        } catch {
            errorMessage = "Не удалось обновить выполнение: \(error.localizedDescription)"
        }
    }

    private func hideRule(_ rule: TaskRule) {
        let targetDate = Calendar.current.startOfDay(for: selectedDate)
        var hiddenRuleIDs = hiddenRuleIDs(for: targetDate)
        hiddenRuleIDs.insert(rule.id.uuidString)
        saveHiddenRuleIDs(hiddenRuleIDs, for: targetDate)
        refreshVisibleRules()
    }

    private func hiddenRuleIDs(for date: Date) -> Set<String> {
        let storedValues = UserDefaults.standard.stringArray(forKey: hiddenRuleIDsStorageKey(for: date)) ?? []
        return Set(storedValues)
    }

    private func unhideRule(_ rule: TaskRule, on date: Date) {
        var hiddenRuleIDs = hiddenRuleIDs(for: date)
        guard hiddenRuleIDs.remove(rule.id.uuidString) != nil else {
            return
        }

        saveHiddenRuleIDs(hiddenRuleIDs, for: date)
    }

    private func saveHiddenRuleIDs(_ hiddenRuleIDs: Set<String>, for date: Date) {
        let storageKey = hiddenRuleIDsStorageKey(for: date)
        if hiddenRuleIDs.isEmpty {
            UserDefaults.standard.removeObject(forKey: storageKey)
        } else {
            UserDefaults.standard.set(Array(hiddenRuleIDs).sorted(), forKey: storageKey)
        }
    }

    private func hiddenRuleIDsStorageKey(for date: Date) -> String {
        let dateText = date.formatted(.iso8601.year().month().day())
        return "\(hiddenRuleIDsDefaultsKeyPrefix).\(dateText)"
    }

    private var currentWeekDates: [Date] {
        return (0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: currentWeekInterval.start).map {
                Calendar.current.startOfDay(for: $0)
            }
        }
    }

    private var currentWeekInterval: DateInterval {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            let today = calendar.startOfDay(for: Date())
            let end = calendar.date(byAdding: .day, value: 7, to: today) ?? today
            return DateInterval(start: today, end: end)
        }
        return interval
    }

    private func refreshWeeklyCompletions() {
        do {
            let interval = currentWeekInterval
            let descriptor = FetchDescriptor<TaskCompletion>(
                predicate: #Predicate<TaskCompletion> { completion in
                    completion.date >= interval.start && completion.date < interval.end
                }
            )
            weeklyCompletions = try modelContext.fetch(descriptor)
            updateCompletedTaskIDsForSelectedDate()
        } catch {
            errorMessage = "Не удалось загрузить историю выполнения: \(error.localizedDescription)"
        }
    }

    private func updateCompletedTaskIDsForSelectedDate() {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)
        completedTaskIDsForSelectedDate = Set(
            weeklyCompletions
                .filter { $0.isCompleted && calendar.isDate($0.date, inSameDayAs: targetDate) }
                .map(\.taskId)
        )
    }

    private func refreshVisibleRules() {
        visibleRules = rulesForSelectedDate(from: rules)
    }

    private func weekdayText(for date: Date) -> String {
        Self.weekdayFormatter.string(from: date).capitalized(with: Self.weekdayFormatter.locale)
    }

    private func normalizedComment(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}

#Preview {
    TodayView(selectedDate: .constant(Calendar.current.startOfDay(for: Date())))
}
