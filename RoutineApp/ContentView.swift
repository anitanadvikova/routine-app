//
//  ContentView.swift
//  RoutineApp
//
//  Created by Анита Надвикова on 06.04.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Сегодня", systemImage: "sun.max")
                }

            EditTasksView()
                .tabItem {
                    Label("Неделя", systemImage: "checklist")
                }

            ListsView()
                .tabItem {
                    Label("Бэклог", systemImage: "list.bullet")
                }
        }
    }
}

#Preview {
    ContentView()
}
