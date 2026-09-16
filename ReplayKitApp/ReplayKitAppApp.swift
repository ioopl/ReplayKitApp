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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PersistenceRecoveryView {
                ContentView()
            }
            .onAppear {
                DrawingCanvasManager.shared.updateHostAppBackgroundState(false)
            }
            .onChange(of: scenePhase) { _, phase in
                // During an app switch iOS may report .inactive before it
                // reports .background. The broadcast extension must be
                // enabled for both states because the host UI is no longer
                // the active display surface in either case.
                DrawingCanvasManager.shared.updateHostAppBackgroundState(phase != .active)
            }
        }
        .modelContainer(for: [RecordingDocumentEntity.self, FrameEntity.self])
    }
}
