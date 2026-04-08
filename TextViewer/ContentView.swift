//
//  ContentView.swift
//  TextViewer
//
//  Created by Codex on 4/8/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var workspace = WorkspaceState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        EditorShellView()
            .environmentObject(workspace)
            .frame(minWidth: 1100, minHeight: 720)
            .task {
                workspace.restoreSessionIfPossible()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    workspace.persistSession()
                }
            }
    }
}

#Preview {
    ContentView()
}
