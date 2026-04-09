//
//  ContentView.swift
//  RoutineApp
//
//  Created by Анита Надвикова on 06.04.2026.
//

import SwiftUI

struct ContentView: View {
    @SceneStorage("selectedTab") private var selectedTabRawValue = AppTab.today.rawValue
    @SceneStorage("todaySelectedDate") private var todaySelectedDateTimestamp = Date().timeIntervalSinceReferenceDate

    private var selectedTab: AppTab {
        get { AppTab(rawValue: selectedTabRawValue) ?? .today }
        nonmutating set { selectedTabRawValue = newValue.rawValue }
    }

    private var todaySelectedDate: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: todaySelectedDateTimestamp) },
            set: { todaySelectedDateTimestamp = Calendar.current.startOfDay(for: $0).timeIntervalSinceReferenceDate }
        )
    }

    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )) {
            tabContent(for: .today)
                .tabItem {
                    Label("Сегодня", systemImage: "sun.max")
                }
                .tag(AppTab.today)

            tabContent(for: .week)
                .tabItem {
                    Label("Неделя", systemImage: "checklist")
                }
                .tag(AppTab.week)

            tabContent(for: .backlog)
                .tabItem {
                    Label("Бэклог", systemImage: "list.bullet")
                }
                .tag(AppTab.backlog)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        if selectedTab == tab {
            switch tab {
            case .today:
                TodayView(selectedDate: todaySelectedDate)
            case .week:
                EditTasksView()
            case .backlog:
                ListsView()
            }
        } else {
            Color.clear
        }
    }
}

private enum AppTab: String, Hashable {
    case today
    case week
    case backlog
}

#Preview {
    ContentView()
}
