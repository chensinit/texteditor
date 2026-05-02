//
//  TextViewerApp.swift
//  TextViewer
//
//  Created by shoonee on 4/7/26.
//

import SwiftUI

@main
struct TextViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            EditorCommandMenu()
        }
    }
}

private struct EditorCommandMenu: Commands {
    @FocusedObject private var workspace: WorkspaceState?

    var body: some Commands {
        CommandMenu("Find") {
            Button("Find") {
                workspace?.presentSearch()
            }
            .keyboardShortcut("f", modifiers: [.command])
            .disabled(workspace?.activeDocument == nil)

            Button("Find Next") {
                workspace?.selectNextSearchResult()
            }
            .keyboardShortcut("g", modifiers: [.command])
            .disabled(!(workspace?.canNavigateSearchResults ?? false))

            Button("Find Previous") {
                workspace?.selectPreviousSearchResult()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(!(workspace?.canNavigateSearchResults ?? false))
        }

        CommandMenu("Navigate") {
            Button("Go To Line") {
                workspace?.presentGoToLine()
            }
            .keyboardShortcut("l", modifiers: [.command])
            .disabled(workspace?.activeDocument == nil)
        }

        CommandMenu("Recent Files") {
            if let workspace, !workspace.recentFiles.isEmpty {
                ForEach(workspace.recentFiles, id: \.path) { url in
                    Button(url.lastPathComponent) {
                        workspace.openRecentFile(url)
                    }
                }

                Divider()

                Button("Clear Recent Files") {
                    workspace.clearRecentFiles()
                }
            } else {
                Button("No Recent Files") {}
                    .disabled(true)
            }
        }
    }
}
