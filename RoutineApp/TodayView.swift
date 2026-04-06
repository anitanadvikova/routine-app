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
    @Query(sort: \TaskRule.title) private var rules: [TaskRule]
    @Query private var completions: [TaskCompletion]
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month().year())
                        .foregroundStyle(.secondary)
                }

                Section("Рутинные задачи на сегодня") {
                    let todayRules = rulesForToday(from: rules)
                    if todayRules.isEmpty {
                        Text("На сегодня нет рутинных задач")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(todayRules, id: \.id) { rule in
                            HStack(spacing: 10) {
                                Image(systemName: isCompletedToday(rule) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isCompletedToday(rule) ? .green : .secondary)

                                if rule.isImportant {
                                    Circle()
                                        .fill(.orange)
                                        .frame(width: 8, height: 8)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.title)
                                        .strikethrough(isCompletedToday(rule), color: .secondary)
                                        .foregroundStyle(isCompletedToday(rule) ? .secondary : .primary)
                                    if let time = timeText(for: rule) {
                                        Text(time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    deleteRule(rule)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Удалить рутинную задачу")
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleCompletion(for: rule)
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
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Неизвестная ошибка")
            }
        }
    }

    private func rulesForToday(from rules: [TaskRule]) -> [TaskRule] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let completedTaskIDsInPast = Set(
            completions
                .filter { $0.isCompleted && Calendar.current.startOfDay(for: $0.date) < today }
                .map(\.taskId)
        )
        let completedTaskIDsToday = Set(
            completions
                .filter { $0.isCompleted && Calendar.current.isDate($0.date, inSameDayAs: today) }
                .map(\.taskId)
        )

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
                    guard start <= today else { return false }
                    let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
                    return days % interval == 0
                case .floating:
                    return !completedTaskIDsInPast.contains(rule.id) || completedTaskIDsToday.contains(rule.id)
                }
            }
            .sorted { lhs, rhs in
                sortKey(for: lhs) < sortKey(for: rhs)
            }
    }

    private func sortKey(for rule: TaskRule) -> (Int, Int, Int, String) {
        if let hour = rule.startTimeHour, let minute = rule.startTimeMinute {
            return (0, hour, minute, rule.title.lowercased())
        }
        return (1, 0, 0, rule.title.lowercased())
    }

    private func timeText(for rule: TaskRule) -> String? {
        guard let hour = rule.startTimeHour, let minute = rule.startTimeMinute else {
            return nil
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func isCompletedToday(_ rule: TaskRule) -> Bool {
        completions.contains {
            $0.taskId == rule.id && $0.isCompleted && Calendar.current.isDateInToday($0.date)
        }
    }

    private func toggleCompletion(for rule: TaskRule) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let existing = completions.first(where: { $0.taskId == rule.id && calendar.isDate($0.date, inSameDayAs: today) }) {
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
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = "Не удалось обновить выполнение: \(error.localizedDescription)"
        }
    }

    private func deleteRule(_ rule: TaskRule) {
        do {
            let related = completions.filter { $0.taskId == rule.id }
            for completion in related {
                modelContext.delete(completion)
            }
            modelContext.delete(rule)
            try modelContext.save()
        } catch {
            errorMessage = "Не удалось удалить рутинную задачу: \(error.localizedDescription)"
        }
    }
}

#Preview {
    TodayView()
}
