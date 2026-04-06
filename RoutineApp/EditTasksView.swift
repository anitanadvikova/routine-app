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
    @State private var newTaskTitle = ""
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
                        HStack(spacing: 12) {
                            Image(systemName: task.isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isChecked ? .green : .secondary)
                            if task.isImportant {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 8, height: 8)
                            }

                            Text(task.title)
                                .strikethrough(task.isChecked, color: .secondary)
                                .foregroundStyle(task.isChecked ? .secondary : .primary)
                        }
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            toggleChecked(task)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newTaskTitle = ""
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
                        Section("Опции") {
                            Toggle("Важная задача", isOn: $newTaskIsImportant)
                                                }
                    }
                    .navigationTitle("Добавить")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Закрыть") {
                                isCreateTaskSheetPresented = false
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

        let task = QuickTask(
                    title: trimmedTitle,
                    isChecked: false,
                    isImportant: newTaskIsImportant
                )

        do {
            modelContext.insert(task)
            try modelContext.save()
            isCreateTaskSheetPresented = false
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

}

#Preview {
    EditTasksView()
}
