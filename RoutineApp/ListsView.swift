//
//  ListsView.swift
//  RoutineApp
//
//  Created by Cursor on 06.04.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct ListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserList.title) private var lists: [UserList]
    @Query(sort: \QuickTask.createdAt, order: .forward) private var quickTasks: [QuickTask]

    @State private var isImportPresented = false
    @State private var importText = ""
    @State private var isExportPresented = false
    @State private var exportText = ""
    @State private var isCopyToastPresented = false
    @State private var listsByTitle: [String: UserList] = [:]
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(defaultCategories, id: \.self) { category in
                    if let list = listsByTitle[category] {
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
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 8)
            }
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
                refreshListsByTitle()
            }
            .onChange(of: lists.count) { _, _ in
                refreshListsByTitle()
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
                                importLists()
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
                            Section("JSON списков задач") {
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
                refreshListsByTitle()
            }
        } catch {
            errorMessage = "Не удалось создать категории: \(error.localizedDescription)"
        }
    }

    private func importLists() {
        do {
            try BacklogJSONCodec.replaceLists(from: importText, modelContext: modelContext)
            ensureDefaultLists()
            closeImportSheet()
        } catch {
            errorMessage = "Ошибка импорта JSON: \(error.localizedDescription)"
        }
    }

    private func exportLists() {
        do {
            exportText = try BacklogJSONCodec.exportJSONString(from: lists, quickTasks: quickTasks)
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

    private func refreshListsByTitle() {
        listsByTitle = Dictionary(uniqueKeysWithValues: lists.map { ($0.title, $0) })
    }

    private func closeImportSheet() {
        importText = ""
        isImportPresented = false
    }

    private func closeExportSheet() {
        exportText = ""
        isExportPresented = false
    }
}

private struct UserListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var userList: UserList

    @State private var isCreateItemSheetPresented = false
    @State private var editingItem: UserListItem?
    @State private var newItemText = ""
    @State private var newItemComment = ""
    @State private var newItemIsImportant = false
    @State private var sortedItems: [UserListItem] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if sortedItems.isEmpty {
                Text("Пока пусто")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedItems, id: \.id) { item in
                    let comment = normalizedComment(item.comment)
                    HStack(spacing: 12) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                            .frame(width: 22, height: 22)

                        if item.isImportant {
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text)
                                .strikethrough(item.isCompleted, color: .secondary)
                                .foregroundStyle(item.isCompleted ? .secondary : .primary)
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
                        toggleItem(item)
                    }
                    .onLongPressGesture {
                        startEditing(item)
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
        .navigationTitle(userList.title)
        .onAppear {
            refreshSortedItems()
        }
        .onChange(of: userList.items.count) { _, _ in
            refreshSortedItems()
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 8)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingItem = nil
                    newItemText = ""
                    newItemComment = ""
                    newItemIsImportant = false
                    isCreateItemSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить пункт")
            }
        }
        .sheet(isPresented: $isCreateItemSheetPresented) {
            NavigationStack {
                Form {
                    Section("Название") {
                        TextField("Например: Купить яблоки", text: $newItemText)
                    }
                    Section("Комментарий") {
                        TextField("Опционально", text: $newItemComment, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    Section("Опции") {
                        Toggle("Важная задача", isOn: $newItemIsImportant)
                    }
                }
                .navigationTitle(editingItem == nil ? "Добавить" : "Редактировать")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") {
                            isCreateItemSheetPresented = false
                            editingItem = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            addItem()
                        }
                        .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        do {
            if let editingItem {
                editingItem.text = text
                editingItem.comment = normalizedComment(newItemComment)
                editingItem.isImportant = newItemIsImportant
            } else {
                let item = UserListItem(
                    text: text,
                    comment: normalizedComment(newItemComment),
                    isImportant: newItemIsImportant,
                    list: userList
                )
                modelContext.insert(item)
                userList.items.append(item)
            }
            try modelContext.save()
            refreshSortedItems()
            newItemText = ""
            newItemComment = ""
            newItemIsImportant = false
            isCreateItemSheetPresented = false
            editingItem = nil
        } catch {
            errorMessage = "Не удалось добавить пункт: \(error.localizedDescription)"
        }
    }

    private func toggleItem(_ item: UserListItem) {
        do {
            item.isCompleted.toggle()
            try modelContext.save()
            refreshSortedItems()
        } catch {
            errorMessage = "Не удалось обновить пункт: \(error.localizedDescription)"
        }
    }

    private func deleteItem(_ item: UserListItem) {
        do {
            userList.items.removeAll { $0.id == item.id }
            modelContext.delete(item)
            try modelContext.save()
            refreshSortedItems()
        } catch {
            errorMessage = "Не удалось удалить пункт: \(error.localizedDescription)"
        }
    }

    private func startEditing(_ item: UserListItem) {
        editingItem = item
        newItemText = item.text
        newItemComment = item.comment ?? ""
        newItemIsImportant = item.isImportant
        isCreateItemSheetPresented = true
    }

    private func normalizedComment(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func refreshSortedItems() {
        sortedItems = userList.items.sorted { $0.createdAt < $1.createdAt }
    }
}

#Preview {
    ListsView()
}
