//
//  ReplayKitAppApp.swift
//  ReplayKitApp
//
//  Created by Umair Hasan on 26/07/2026.
//

import SwiftUI
import SwiftData

@main
struct ReplayKitAppApp: App {
    var body: some Scene {
        WindowGroup {
            PersistenceRecoveryView {
                ContentView()
            }
        }
        .modelContainer(for: [RecordingDocumentEntity.self, FrameEntity.self])
    }
}
