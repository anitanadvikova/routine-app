//
//  SimpleRoutineWidget.swift
//  RoutineAppWidget
//
//  Created by Codex on 06.04.2026.
//

import SwiftUI
import WidgetKit

struct SimpleRoutineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SimpleRoutineWidget", provider: Provider()) { entry in
            SimpleRoutineWidgetView(entry: entry)
        }
        .configurationDisplayName("Сегодня")
        .description("Показывает незакрытые задачи со вкладки Сегодня.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: loadSnapshot() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [Entry(date: now, snapshot: loadSnapshot())], policy: .after(nextUpdate)))
    }

    private func loadSnapshot() -> WidgetTodaySnapshot? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.Liza-Barboskina.RoutineApp")?
            .appendingPathComponent("TodayWidgetSnapshot.json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetTodaySnapshot.self, from: data)
    }
}

private struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetTodaySnapshot?
}

private struct SimpleRoutineWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Сегодня")
                .font(.headline.weight(.semibold))

            Text(entry.date, format: .dateTime.weekday(.wide).day().month())
                .font(.caption)
                .foregroundStyle(.secondary)

            if let snapshot = entry.snapshot {
                if snapshot.tasks.isEmpty {
                    Text("Все задачи на сегодня закрыты")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(snapshot.tasks.prefix(taskLimit).enumerated()), id: \.offset) { _, task in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• \(task.title)")
                                    .font(.subheadline)
                                    .lineLimit(2)
                                if let timeText = task.timeText {
                                    Text(timeText)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                Text("Откройте приложение, чтобы загрузить задачи для виджета")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }

    private var taskLimit: Int {
        family == .systemLarge ? 12 : 4
    }
}

private struct WidgetTodaySnapshot: Codable {
    let generatedAt: Date
    let tasks: [WidgetTodayTaskSnapshot]

    static let placeholder = WidgetTodaySnapshot(
        generatedAt: .now,
        tasks: [
            WidgetTodayTaskSnapshot(title: "Выпить воду", timeText: "08:00"),
            WidgetTodayTaskSnapshot(title: "Сделать зарядку", timeText: nil),
            WidgetTodayTaskSnapshot(title: "Прочитать 10 страниц", timeText: "21:00")
        ]
    )
}

private struct WidgetTodayTaskSnapshot: Codable {
    let title: String
    let timeText: String?
}
