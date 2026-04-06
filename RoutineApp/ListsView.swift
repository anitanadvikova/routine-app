//
//  ListsView.swift
//  RoutineApp
//
//  Created by Cursor on 06.04.2026.
//

import SwiftUI
import SwiftData

struct ListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserList.title) private var lists: [UserList]

    @State private var isImportPresented = false
    @State private var importText = ""
    @State private var isExportPresented = false
    @State private var exportText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(defaultCategories, id: \.self) { category in
                    if let list = lists.first(where: { $0.title == category }) {
                        NavigationLink {
                            UserListDetailView(userList: list)
                        } label: {
                            Text(category)
                        }
                    } else {
                        Text(category)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Бэклог")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("JSON") {
                        Button("Загрузить JSON") {
                            importText = ""
                            isImportPresented = true
                        }
                        Button("Выгрузить JSON") {
                            exportLists()
                        }
                    }
                }
            }
            .onAppear {
                ensureDefaultLists()
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
                                importLists()
                            }
                            .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .sheet(isPresented: $isExportPresented) {
                NavigationStack {
                    Form {
                        Section("JSON списков задач") {
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
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Неизвестная ошибка")
            }
        }
    }

    private var defaultCategories: [String] {
        ["Покупки", "Фильмы", "Книги", "Творчество", "Дела"]
    }

    private func ensureDefaultLists() {
        do {
            let existingTitles = Set(lists.map(\.title))
            var inserted = false

            for category in defaultCategories where !existingTitles.contains(category) {
                modelContext.insert(UserList(title: category))
                inserted = true
            }

            if inserted {
                try modelContext.save()
            }
        } catch {
            errorMessage = "Не удалось создать категории: \(error.localizedDescription)"
        }
    }

    private func importLists() {
        do {
            try BacklogJSONCodec.replaceLists(from: importText, modelContext: modelContext)
            ensureDefaultLists()
            isImportPresented = false
        } catch {
            errorMessage = "Ошибка импорта JSON: \(error.localizedDescription)"
        }
    }

    private func exportLists() {
        do {
            exportText = try BacklogJSONCodec.exportJSONString(from: lists)
            isExportPresented = true
        } catch {
            errorMessage = "Ошибка выгрузки JSON: \(error.localizedDescription)"
        }
    }
}

private struct UserListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var userList: UserList

    @State private var newItemText = ""
    @State private var errorMessage: String?

    private var sortedItems: [UserListItem] {
        userList.items.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            Section("Новый пункт") {
                HStack {
                    TextField("Добавить задачу", text: $newItemText)
                    Button("Добавить") {
                        addItem()
                    }
                    .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Пункты") {
                if sortedItems.isEmpty {
                    Text("Пока пусто")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedItems, id: \.id) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isCompleted ? .green : .secondary)

                            Text(item.text)
                                .strikethrough(item.isCompleted, color: .secondary)
                                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleItem(item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(userList.title)
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        }
    }

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            let item = UserListItem(text: text, list: userList)
            modelContext.insert(item)
            userList.items.append(item)
            try modelContext.save()
            newItemText = ""
        } catch {
            errorMessage = "Не удалось добавить пункт: \(error.localizedDescription)"
        }
    }

    private func toggleItem(_ item: UserListItem) {
        do {
            item.isCompleted.toggle()
            try modelContext.save()
        } catch {
            errorMessage = "Не удалось обновить пункт: \(error.localizedDescription)"
        }
    }

    private func deleteItem(_ item: UserListItem) {
        do {
            userList.items.removeAll { $0.id == item.id }
            modelContext.delete(item)
            try modelContext.save()
        } catch {
            errorMessage = "Не удалось удалить пункт: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ListsView()
}
