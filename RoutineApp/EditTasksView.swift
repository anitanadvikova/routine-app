//
//  EditTasksView.swift
//  RoutineApp
//
//  Created by Cursor on 06.04.2026.
//

import SwiftUI
import SwiftData

struct EditTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuickTask.createdAt, order: .forward) private var quickTasks: [QuickTask]

    @State private var isCreateTaskSheetPresented = false
    @State private var editingTask: QuickTask?
    @State private var newTaskTitle = ""
    @State private var newTaskComment = ""
    @State private var newTaskIsImportant = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(weekRangeText)
                        .foregroundStyle(.secondary)
                }

                if quickTasks.isEmpty {
                    Text("Пока нет задач")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(quickTasks, id: \.id) { task in
                        let comment = normalizedComment(task.comment)
                        HStack(spacing: 12) {
                            Image(systemName: task.isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isChecked ? .green : .secondary)
                                .frame(width: 22, height: 22)
                            if task.isImportant {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 8, height: 8)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .strikethrough(task.isChecked, color: .secondary)
                                    .foregroundStyle(task.isChecked ? .secondary : .primary)
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
                        .onTapGesture {
                            toggleChecked(task)
                        }
                        .onLongPressGesture {
                            startEditing(task)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteTask(task)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Неделя")
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newTaskTitle = ""
                        newTaskComment = ""
                        newTaskIsImportant = false
                        isCreateTaskSheetPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить задачу")
                }
            }
            .sheet(isPresented: $isCreateTaskSheetPresented) {
                NavigationStack {
                    Form {
                        Section("Название") {
                            TextField("Например: Выпить воду", text: $newTaskTitle)
                        }
                        Section("Комментарий") {
                            TextField("Опционально", text: $newTaskComment, axis: .vertical)
                                .lineLimit(2...4)
                        }
                        Section("Опции") {
                            Toggle("Важная задача", isOn: $newTaskIsImportant)
                                                }
                    }
                    .navigationTitle(editingTask == nil ? "Добавить" : "Редактировать")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Закрыть") {
                                isCreateTaskSheetPresented = false
                                editingTask = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Сохранить") {
                                saveTask()
                            }
                            .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
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

    private func saveTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        do {
            if let editingTask {
                editingTask.title = trimmedTitle
                editingTask.comment = normalizedComment(newTaskComment)
                editingTask.isImportant = newTaskIsImportant
            } else {
                let task = QuickTask(
                    title: trimmedTitle,
                    comment: normalizedComment(newTaskComment),
                    isChecked: false,
                    isImportant: newTaskIsImportant
                )
                modelContext.insert(task)
            }
            try modelContext.save()
            isCreateTaskSheetPresented = false
            editingTask = nil
        } catch {
            errorMessage = "Не удалось сохранить задачу: \(error.localizedDescription)"
        }
    }

    private func toggleChecked(_ task: QuickTask) {
        task.isChecked.toggle()
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Не удалось обновить задачу: \(error.localizedDescription)"
        }
    }

    private func deleteTask(_ task: QuickTask) {
        do {
            modelContext.delete(task)
            try modelContext.save()
        } catch {
            errorMessage = "Не удалось удалить задачу: \(error.localizedDescription)"
        }
    }

    private var weekRangeText: String {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return Date.now.formatted(.dateTime.day().month().year())
        }

        let endDate = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let startText = interval.start.formatted(.dateTime.day().month().year())
        let endText = endDate.formatted(.dateTime.day().month().year())
        return "\(startText) - \(endText)"
    }

    private func startEditing(_ task: QuickTask) {
        editingTask = task
        newTaskTitle = task.title
        newTaskComment = task.comment ?? ""
        newTaskIsImportant = task.isImportant
        isCreateTaskSheetPresented = true
    }

    private func normalizedComment(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

}

#Preview {
    EditTasksView()
}
