//
//  RoutineRulesView.swift
//  RoutineApp
//
//  Created by Cursor on 06.04.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct RoutineRulesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [TaskRule]

    @State private var isCreateEditorPresented = false
    @State private var editingRule: TaskRule?

    @State private var isImportPresented = false
    @State private var importText = ""

    @State private var isExportPresented = false
    @State private var exportText = ""
    @State private var isCopyToastPresented = false

    @State private var sortedRules: [TaskRule] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if sortedRules.isEmpty {
                Text("Пока нет рутинных правил")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedRules, id: \.id) { rule in
                    Button {
                        editingRule = rule
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
                .onMove(perform: moveRules)
                .onDelete(perform: deleteRules)
            }
        }
        .navigationTitle("Правила рутины")
        .onAppear {
            refreshSortedRules()
            normalizeSortOrderIfNeeded()
        }
        .onChange(of: rules.count) { _, _ in
            refreshSortedRules()
        }
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button {
                    editingRule = nil
                    isCreateEditorPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить правило")
            }
        }
        .sheet(item: $editingRule) { rule in
            RoutineRuleEditorSheet(rule: rule) { input in
                saveRule(input)
            }
        }
        .sheet(isPresented: $isCreateEditorPresented) {
            RoutineRuleEditorSheet(rule: nil) { input in
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
                        Button("Закрыть") { closeImportSheet() }
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
            ZStack {
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
                            Button("Закрыть") { closeExportSheet() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Скопировать") {
                                copyExportJSON()
                            }
                        }
                    }
                }

                if isCopyToastPresented {
                    Text("Скопировано")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isCopyToastPresented)
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
                targetRule = TaskRule(
                    sortOrder: nextSortOrder(),
                    title: input.title,
                    scheduleType: input.scheduleType
                )
                modelContext.insert(targetRule)
            }

            targetRule.title = input.title
            targetRule.scheduleType = input.scheduleType
            targetRule.weeklyDays = input.weeklyDays
            targetRule.intervalDays = input.intervalDays
            targetRule.startDate = input.startDate
            targetRule.isImportant = input.isImportant
            targetRule.markerColor = input.markerColor
            targetRule.notes = input.notes.isEmpty ? nil : input.notes
            targetRule.isActive = input.isActive

            try validateRule(targetRule)
            try modelContext.save()
            refreshSortedRules()
            editingRule = nil
            isCreateEditorPresented = false
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
            let rulesToDelete = offsets.map { sortedRules[$0] }
            for rule in rulesToDelete {
                modelContext.delete(rule)
            }
            resequenceRules(sortedRules.filter { rule in
                !rulesToDelete.contains(where: { $0.id == rule.id })
            })
            try modelContext.save()
            refreshSortedRules()
        } catch {
            errorMessage = "Не удалось удалить правило: \(error.localizedDescription)"
        }
    }

    private func moveRules(from offsets: IndexSet, to destination: Int) {
        var reorderedRules = sortedRules
        reorderedRules.move(fromOffsets: offsets, toOffset: destination)

        do {
            resequenceRules(reorderedRules)
            try modelContext.save()
            refreshSortedRules()
        } catch {
            errorMessage = "Не удалось сохранить порядок: \(error.localizedDescription)"
        }
    }

    private func nextSortOrder() -> Int {
        (rules.map(\.sortOrder).max() ?? -1) + 1
    }

    private func normalizeSortOrderIfNeeded() {
        let currentRules = sortedRules
        let needsNormalization = currentRules.enumerated().contains { index, rule in
            rule.sortOrder != index
        }

        guard needsNormalization else { return }

        do {
            resequenceRules(currentRules)
            try modelContext.save()
            refreshSortedRules()
        } catch {
            errorMessage = "Не удалось обновить порядок: \(error.localizedDescription)"
        }
    }

    private func resequenceRules(_ rules: [TaskRule]) {
        for (index, rule) in rules.enumerated() {
            rule.sortOrder = index
        }
    }

    private func refreshSortedRules() {
        sortedRules = rules.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private func importRules() {
        do {
            try TaskRuleJSONCodec.replaceRules(from: importText, modelContext: modelContext)
            closeImportSheet()
        } catch {
            errorMessage = "Ошибка импорта JSON: \(error.localizedDescription)"
        }
    }

    private func exportRules() {
        do {
            exportText = try TaskRuleJSONCodec.exportJSONString(from: sortedRules)
            isExportPresented = true
        } catch {
            errorMessage = "Ошибка выгрузки JSON: \(error.localizedDescription)"
        }
    }

    private func copyExportJSON() {
        UIPasteboard.general.string = exportText
        isCopyToastPresented = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                isCopyToastPresented = false
            }
        }
    }

    private func closeImportSheet() {
        importText = ""
        isImportPresented = false
    }

    private func closeExportSheet() {
        exportText = ""
        isExportPresented = false
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
                    Picker("Цвет пункта", selection: $input.markerColor) {
                        ForEach(TaskMarkerColor.allCases) { color in
                            Label {
                                Text(color.title)
                            } icon: {
                                Circle()
                                    .fill(color.swiftUIColor)
                            }
                            .tag(color)
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
    var isImportant: Bool
    var markerColor: TaskMarkerColor
    var notes: String
    var isActive: Bool

    var startDate: Date? {
        scheduleType == .interval ? Calendar.current.startOfDay(for: intervalStartDate) : nil
    }

    init(rule: TaskRule?) {
        let now = Date()
        self.title = rule?.title ?? ""
        self.scheduleType = rule?.scheduleType ?? .floating
        self.weeklyDays = rule?.weeklyDays ?? []
        self.intervalDays = max(1, rule?.intervalDays ?? 1)
        self.intervalStartDate = rule?.startDate ?? now
        self.isImportant = rule?.isImportant ?? false
        self.markerColor = rule?.markerColor ?? .white
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
