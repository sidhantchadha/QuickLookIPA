//
//  QuickLookIPAApp.swift
//  QuickLookIPA
//
//  Created by Claude Code on 11/21/26.
//  Main application entry point with SwiftUI lifecycle and menu commands.
//

import SwiftUI

@main
struct QuickLookIPAApp: App {
    @StateObject private var inspector = IPAInspectorService.shared
    @StateObject private var history = HistoryManager.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(inspector)
                .environmentObject(history)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open IPA...") {
                    // File picker is triggered from MainView
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Toggle Debug Logging") {
                    inspector.debugLoggingEnabled.toggle()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Show History") {
                    // History panel is managed in MainView sidebar
                }
                .keyboardShortcut("h", modifiers: .command)
            }

            CommandMenu("Export") {
                Button("Export as JSON") {}
                .keyboardShortcut("e", modifiers: [.command])

                Button("Export as Markdown") {}
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Export as PDF") {}
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
        .defaultSize(width: 1200, height: 800)
    }
}
