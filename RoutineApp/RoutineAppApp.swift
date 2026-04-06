//
//  RoutineAppApp.swift
//  RoutineApp
//
//  Created by Анита Надвикова on 06.04.2026.
//

import SwiftUI
import SwiftData

@main
struct RoutineAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(
            for: [
                Item.self,
                TaskRule.self,
                TaskCompletion.self,
                UserList.self,
                UserListItem.self,
                QuickTask.self
            ]
        )
    }
}
