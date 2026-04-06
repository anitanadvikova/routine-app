//
//  RoutineRulesView.swift
//  RoutineApp
//
//  Created by Cursor on 06.04.2026.
//

import SwiftUI
import SwiftData

struct RoutineRulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskRule.title) private var rules: [TaskRule]

    @State private var isEditorPresented = false
    @State private var editingRule: TaskRule?

    @State private var isImportPresented = false
    @State private var importText = ""

    @State private var isExportPresented = false
    @State private var exportText = ""

    @State private var errorMessage: String?

    var body: some View {
        List {
            if rules.isEmpty {
                Text("Пока нет рутинных правил")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rules, id: \.id) { rule in
                    Button {
                        editingRule = rule
                        isEditorPresented = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.title)
                                .foregroundStyle(.primary)
                            if let scheduleDescription = scheduleDescription(for: rule) {
                                Text(scheduleDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteRules)
            }
        }
        .navigationTitle("Правила рутины")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu("JSON") {
                    Button("Загрузить JSON") {
                        importText = ""
                        isImportPresented = true
                    }
                    Button("Выгрузить JSON") {
                        exportRules()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingRule = nil
                    isEditorPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить правило")
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            RoutineRuleEditorSheet(rule: editingRule) { input in
                saveRule(input)
            }
        }
        .sheet(isPresented: $isImportPresented) {
            NavigationStack {
                Form {
                    Section("Вставьте JSON текстом") {
                        TextEditor(text: $importText)
                            .frame(minHeight: 220)
                    }
                }
                .navigationTitle("Загрузить JSON")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") { isImportPresented = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Импортировать") {
                            importRules()
                        }
                        .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $isExportPresented) {
            NavigationStack {
                Form {
                    Section("JSON правил рутины") {
                        TextEditor(text: $exportText)
                            .frame(minHeight: 260)
                            .font(.system(.footnote, design: .monospaced))
                    }
                }
                .navigationTitle("Выгрузить JSON")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") { isExportPresented = false }
                    }
                }
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        }
    }

    private func saveRule(_ input: RoutineRuleInput) {
        do {
            let targetRule: TaskRule
            if let editingRule {
                targetRule = editingRule
            } else {
                targetRule = TaskRule(title: input.title, scheduleType: input.scheduleType)
                modelContext.insert(targetRule)
            }

            targetRule.title = input.title
            targetRule.scheduleType = input.scheduleType
            targetRule.weeklyDays = input.weeklyDays
            targetRule.intervalDays = input.intervalDays
            targetRule.startDate = input.startDate
            targetRule.startTimeHour = input.startTimeEnabled ? input.startTimeHour : nil
            targetRule.startTimeMinute = input.startTimeEnabled ? input.startTimeMinute : nil
            targetRule.isImportant = input.isImportant
            targetRule.notes = input.notes.isEmpty ? nil : input.notes
            targetRule.isActive = input.isActive

            try validateRule(targetRule)
            try modelContext.save()
            isEditorPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateRule(_ rule: TaskRule) throws {
        if rule.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError("Название не может быть пустым")
        }
        if rule.scheduleType == .weekly, rule.weeklyDays.isEmpty {
            throw ValidationError("Для weekly выберите хотя бы 1 день")
        }
        if rule.scheduleType == .interval {
            guard let interval = rule.intervalDays, interval >= 1 else {
                throw ValidationError("Для interval укажите intervalDays >= 1")
            }
            if rule.startDate == nil {
                throw ValidationError("Для interval укажите startDate")
            }
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        do {
            for index in offsets {
                modelContext.delete(rules[index])
            }
            try modelContext.save()
        } catch {
            errorMessage = "Не удалось удалить правило: \(error.localizedDescription)"
        }
    }

    private func importRules() {
        do {
            try TaskRuleJSONCodec.replaceRules(from: importText, modelContext: modelContext)
            isImportPresented = false
        } catch {
            errorMessage = "Ошибка импорта JSON: \(error.localizedDescription)"
        }
    }

    private func exportRules() {
        do {
            exportText = try TaskRuleJSONCodec.exportJSONString(from: rules)
            isExportPresented = true
        } catch {
            errorMessage = "Ошибка выгрузки JSON: \(error.localizedDescription)"
        }
    }

    private func scheduleDescription(for rule: TaskRule) -> String? {
        switch rule.scheduleType {
        case .weekly:
            let days = rule.weeklyDays.map(weekdayLabel).joined(separator: ", ")
            return days.isEmpty ? nil : days
        case .interval:
            guard let interval = rule.intervalDays else { return nil }
            return "Каждые \(interval) дн."
        case .floating:
            return nil
        }
    }
}

private struct RoutineRuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let rule: TaskRule?
    let onSave: (RoutineRuleInput) -> Void

    @State private var input: RoutineRuleInput

    init(rule: TaskRule?, onSave: @escaping (RoutineRuleInput) -> Void) {
        self.rule = rule
        self.onSave = onSave
        _input = State(initialValue: RoutineRuleInput(rule: rule))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Основное") {
                    TextField("Название", text: $input.title)
                    Picker("Тип", selection: $input.scheduleType) {
                        ForEach(TaskScheduleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    Toggle("Важно", isOn: $input.isImportant)
                    Toggle("Активна", isOn: $input.isActive)
                }

                if input.scheduleType == .weekly {
                    Section("Дни недели") {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            Toggle(dayLabel(day), isOn: bindingForWeekday(day))
                        }
                    }
                }

                if input.scheduleType == .interval {
                    Section("Интервал") {
                        Stepper("Каждые \(input.intervalDays) дн.", value: $input.intervalDays, in: 1...365)
                        DatePicker("Стартовая дата", selection: $input.intervalStartDate, displayedComponents: .date)
                    }
                }

                Section("Время") {
                    Toggle("Указать время", isOn: $input.startTimeEnabled)
                    if input.startTimeEnabled {
                        DatePicker("Время", selection: $input.startTimeDate, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Заметки") {
                    TextField("Опционально", text: $input.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(rule == nil ? "Новое правило" : "Редактирование")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(input.normalized())
                    }
                }
            }
        }
    }

    private func bindingForWeekday(_ day: Weekday) -> Binding<Bool> {
        Binding(
            get: { input.weeklyDays.contains(day) },
            set: { isOn in
                if isOn {
                    input.weeklyDays.append(day)
                    input.weeklyDays = Array(Set(input.weeklyDays)).sorted { $0.rawValue < $1.rawValue }
                } else {
                    input.weeklyDays.removeAll { $0 == day }
                }
            }
        )
    }

    private func dayLabel(_ day: Weekday) -> String {
        weekdayLabel(day)
    }
}

private struct RoutineRuleInput {
    var title: String
    var scheduleType: TaskScheduleType
    var weeklyDays: [Weekday]
    var intervalDays: Int
    var intervalStartDate: Date
    var startTimeEnabled: Bool
    var startTimeDate: Date
    var isImportant: Bool
    var notes: String
    var isActive: Bool

    var startDate: Date? {
        scheduleType == .interval ? Calendar.current.startOfDay(for: intervalStartDate) : nil
    }

    var startTimeHour: Int? {
        guard startTimeEnabled else { return nil }
        return Calendar.current.component(.hour, from: startTimeDate)
    }

    var startTimeMinute: Int? {
        guard startTimeEnabled else { return nil }
        return Calendar.current.component(.minute, from: startTimeDate)
    }

    init(rule: TaskRule?) {
        let now = Date()
        self.title = rule?.title ?? ""
        self.scheduleType = rule?.scheduleType ?? .floating
        self.weeklyDays = rule?.weeklyDays ?? []
        self.intervalDays = max(1, rule?.intervalDays ?? 1)
        self.intervalStartDate = rule?.startDate ?? now
        self.startTimeEnabled = (rule?.startTimeHour != nil && rule?.startTimeMinute != nil)
        self.startTimeDate = RoutineRuleInput.makeTimeDate(
            hour: rule?.startTimeHour,
            minute: rule?.startTimeMinute
        ) ?? now
        self.isImportant = rule?.isImportant ?? false
        self.notes = rule?.notes ?? ""
        self.isActive = rule?.isActive ?? true
    }

    func normalized() -> RoutineRuleInput {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if scheduleType != .weekly {
            copy.weeklyDays = []
        }
        if scheduleType != .interval {
            copy.intervalDays = 1
        }
        return copy
    }

    private static func makeTimeDate(hour: Int?, minute: Int?) -> Date? {
        guard let hour, let minute else { return nil }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)
    }
}

private struct ValidationError: LocalizedError {
    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private func weekdayLabel(_ day: Weekday) -> String {
    switch day {
    case .monday: return "Понедельник"
    case .tuesday: return "Вторник"
    case .wednesday: return "Среда"
    case .thursday: return "Четверг"
    case .friday: return "Пятница"
    case .saturday: return "Суббота"
    case .sunday: return "Воскресенье"
    }
}

#Preview {
    NavigationStack {
        RoutineRulesView()
    }
}//
//  RoutineRulesView.swift
//  RoutineApp
//
//  Created by Анита Надвикова on 06.04.2026.
//
