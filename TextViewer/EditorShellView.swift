//
//  EditorShellView.swift
//  TextViewer
//
//  Created by Codex on 4/8/26.
//

import AppKit
import SwiftUI

struct EditorShellView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    var body: some View {
        VStack(spacing: 0) {
            TopToolbarView()
            Divider().overlay(Color.white.opacity(0.06))

            HStack(spacing: 0) {
                if workspace.sidebar.isVisible {
                    SidebarContainerView()
                        .frame(width: 304)
                    Divider().overlay(Color.white.opacity(0.06))
                }

                VStack(spacing: 0) {
                    WorkspaceTabStripView()
                    Divider().overlay(Color.white.opacity(0.06))
                    WorkspaceAreaView()
                }
            }

            Divider().overlay(Color.white.opacity(0.06))
            StatusBarView()
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.08),
                    Color(red: 0.035, green: 0.04, blue: 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(.dark)
        .alert(
            "Close Without Saving?",
            isPresented: pendingCloseBinding,
            presenting: workspace.pendingCloseConfirmation
        ) { _ in
            Button("Cancel", role: .cancel) {
                workspace.cancelClosePendingTab()
            }
            Button("Close", role: .destructive) {
                workspace.confirmClosePendingTab()
            }
        } message: { pending in
            Text("\(pending.documentTitle) has unsaved changes.")
        }
        .sheet(isPresented: $workspace.isShowingGoToLine) {
            GoToLineSheet()
                .environmentObject(workspace)
        }
    }

    private var pendingCloseBinding: Binding<Bool> {
        Binding(
            get: { workspace.pendingCloseConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    workspace.cancelClosePendingTab()
                }
            }
        )
    }
}

private struct TopToolbarView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    var body: some View {
        HStack(spacing: 14) {
            Button {
                workspace.createNewDocument()
            } label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(.borderless)

            Button {
                openWorkspaceFolder()
            } label: {
                Label("Open Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderless)

            Button {
                openDocumentFile()
            } label: {
                Label("Open File", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderless)

            Button {
                saveDocument()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)
            .disabled(workspace.activeDocument == nil)

            Button {
                saveDocumentAs()
            } label: {
                Label("Save As", systemImage: "square.and.arrow.down.on.square")
            }
            .buttonStyle(.borderless)
            .disabled(workspace.activeDocument == nil)

            Button {
                workspace.toggleSidebar()
            } label: {
                Label("Sidebar", systemImage: "sidebar.left")
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 20)

            Button {
                sendAction(#selector(UndoManager.undo))
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)

            Button {
                sendAction(#selector(UndoManager.redo))
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .buttonStyle(.borderless)

            Button {
                sendAction(#selector(NSText.cut(_:)))
            } label: {
                Label("Cut", systemImage: "scissors")
            }
            .buttonStyle(.borderless)

            Button {
                sendAction(#selector(NSText.copy(_:)))
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderless)

            Button {
                sendAction(#selector(NSText.paste(_:)))
            } label: {
                Label("Paste", systemImage: "clipboard")
            }
            .buttonStyle(.borderless)

            Button {
                workspace.presentGoToLine()
            } label: {
                Label("Go To Line", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            .buttonStyle(.borderless)
            .disabled(workspace.activeDocument == nil)

            Divider().frame(height: 20)

            Picker("Layout", selection: Binding(
                get: { workspace.layoutPreset },
                set: { workspace.applyLayout($0) }
            )) {
                ForEach(LayoutPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)

            Spacer()

            if let activePane = workspace.activePane {
                Picker("Pane Type", selection: Binding(
                    get: { activePane.kind },
                    set: { workspace.setPaneKind($0, for: activePane.id) }
                )) {
                    ForEach(PaneKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Color.black.opacity(0.32))
    }

    private func openWorkspaceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a workspace folder."

        if panel.runModal() == .OK, let url = panel.url {
            workspace.openWorkspace(at: url)
        }
    }

    private func saveDocument() {
        guard let document = workspace.activeDocument else { return }

        if document.filePath == nil {
            saveDocumentAs()
            return
        }

        do {
            try workspace.saveActiveDocument()
        } catch {
            workspace.setFileSystemError("Failed to save file: \(document.title) (\(error.localizedDescription))")
        }
    }

    private func saveDocumentAs() {
        guard let document = workspace.activeDocument else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = document.title

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try workspace.saveActiveDocument(as: url)
            } catch {
                workspace.setFileSystemError("Failed to save file: \(document.title) (\(error.localizedDescription))")
            }
        }
    }

    private func openDocumentFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a text file."

        if panel.runModal() == .OK, let url = panel.url {
            workspace.openFile(url)
        }
    }

    private func sendAction(_ selector: Selector) {
        NSApp.sendAction(selector, to: nil, from: nil)
    }
}

private struct SidebarContainerView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(SidebarSection.allCases) { section in
                    Button {
                        workspace.setSidebarSection(section)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: iconName(for: section))
                                .font(.system(size: 16, weight: .semibold))
                            Text(section.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(workspace.sidebar.selectedSection == section ? Color.white.opacity(0.12) : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(workspace.sidebar.selectedSection == section ? .white : .secondary)
                }

                Spacer()
            }
            .padding(10)
            .frame(width: 64)
            .background(Color.black.opacity(0.18))

            Group {
                switch workspace.sidebar.selectedSection {
                case .explorer:
                    SidebarExplorerPlaceholderView()
                case .search:
                    SidebarSearchPlaceholderView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.075, green: 0.08, blue: 0.11))
        }
    }

    private func iconName(for section: SidebarSection) -> String {
        switch section {
        case .explorer: "folder"
        case .search: "magnifyingglass"
        }
    }
}

private struct SidebarExplorerPlaceholderView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explorer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(workspace.workspaceTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button("Open") {
                    openWorkspaceFolder()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.bottom, 2)

            if let path = workspace.workspacePath {
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let error = workspace.fileSystemError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.9))
            }

            if workspace.fileTree.isEmpty {
                emptyExplorerState
            } else {
                List {
                    ForEach(workspace.fileTree) { item in
                        FileTreeRow(item: item)
                            .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
        .padding(16)
    }

    private var emptyExplorerState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No folder opened")
                .foregroundStyle(.white)
            Text("Open a workspace folder to populate the file explorer.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func openWorkspaceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a workspace folder."

        if panel.runModal() == .OK, let url = panel.url {
            workspace.openWorkspace(at: url)
        }
    }
}

private struct SidebarSearchPlaceholderView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            TextField(
                "Search current document",
                text: Binding(
                    get: { workspace.search.query },
                    set: { workspace.updateSearchQuery($0) }
                )
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )

            HStack {
                Text(workspace.activeDocument?.title ?? "No active document")
                Spacer()
                Text(searchStatusText)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    workspace.selectPreviousSearchResult()
                } label: {
                    Label("Previous", systemImage: "chevron.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(workspace.search.results.isEmpty)

                Button {
                    workspace.selectNextSearchResult()
                } label: {
                    Label("Next", systemImage: "chevron.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(workspace.search.results.isEmpty)
            }

            if workspace.search.query.isEmpty {
                Text("Type a query to search the active text tab.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } else if workspace.search.results.isEmpty {
                Text("No matches found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } else {
                List {
                    ForEach(workspace.search.results) { result in
                        Button {
                            workspace.selectSearchResult(result.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Line \(result.lineNumber)")
                                        .font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                }
                                Text(result.lineText.isEmpty ? " " : result.lineText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(workspace.search.selectedResultID == result.id ? Color.accentColor.opacity(0.18) : Color.clear)
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var searchStatusText: String {
        if let current = workspace.selectedSearchResultIndex {
            return "\(current) / \(workspace.search.results.count)"
        }
        return "\(workspace.search.results.count) results"
    }
}

private struct FileTreeRow: View {
    @EnvironmentObject private var workspace: WorkspaceState

    let item: FileItem

    var body: some View {
        Group {
            if item.isDirectory {
                DisclosureGroup {
                    if let children = item.children {
                        ForEach(children) { child in
                            FileTreeRow(item: child)
                        }
                    }
                } label: {
                    rowLabel(systemImage: "folder.fill", tint: Color.yellow.opacity(0.9))
                }
            } else {
                Button {
                    workspace.openFile(item.url)
                } label: {
                    rowLabel(systemImage: "doc.text", tint: Color.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func rowLabel(systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 14)

            Text(item.name)
                .lineLimit(1)
                .foregroundStyle(textColor)

            Spacer(minLength: 8)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.clear)
        )
    }

    private var isSelected: Bool {
        workspace.selectedFileURL == item.url
    }

    private var textColor: Color {
        isSelected ? .white : .secondary
    }
}

private struct WorkspaceTabStripView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    var body: some View {
        let pane = workspace.activePane

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let pane {
                    ForEach(pane.tabs) { tab in
                        let document = workspace.document(for: tab)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(indicatorColor(for: tab.kind, isDirty: document?.isDirty == true))
                                .frame(width: 7, height: 7)

                            Text(documentTitle(for: tab, document: document))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(tab.id == pane.selectedTabID ? 0.96 : 0.7))

                            if pane.tabs.count > 1 || document != nil {
                                Button {
                                    workspace.requestCloseTab(tab.id, in: pane.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(tab.id == pane.selectedTabID ? Color.white.opacity(0.09) : Color.white.opacity(0.02))
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            workspace.selectTab(tab.id, in: pane.id)
                        }
                    }
                }

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.18))
    }

    private func documentTitle(for tab: TabState, document: DocumentState?) -> String {
        guard let document else { return tab.title }
        return document.isDirty ? "\(document.title) •" : document.title
    }

    private func indicatorColor(for kind: PaneKind, isDirty: Bool) -> Color {
        if isDirty {
            return Color.orange.opacity(0.95)
        }

        switch kind {
        case .text:
            return Color.green.opacity(0.9)
        case .chat, .terminal:
            return Color.orange.opacity(0.9)
        }
    }
}

private struct WorkspaceAreaView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    private let singleColumn = [GridItem(.flexible())]
    private let twoColumns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.06, blue: 0.085),
                    Color(red: 0.045, green: 0.05, blue: 0.075)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(workspace.panes) { pane in
                        PaneContainerView(pane: pane)
                            .frame(minHeight: paneHeight)
                            .onTapGesture {
                                workspace.setActivePane(pane.id)
                            }
                    }
                }
                .padding(12)
            }
        }
    }

    private var columns: [GridItem] {
        switch workspace.layoutPreset {
        case .single:
            singleColumn
        case .twoColumns, .threeColumns, .quad:
            twoColumns
        }
    }

    private var paneHeight: CGFloat {
        switch workspace.layoutPreset {
        case .single, .twoColumns:
            580
        case .threeColumns, .quad:
            280
        }
    }
}

private struct PaneContainerView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    let pane: PaneState

    var body: some View {
        VStack(spacing: 0) {
            PaneHeaderView(pane: pane)
            Divider().overlay(Color.white.opacity(0.04))
            PaneBodyView(pane: pane)
        }
        .background(Color(red: 0.085, green: 0.09, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, y: 6)
    }

    private var borderColor: Color {
        workspace.activePaneID == pane.id ? Color.accentColor.opacity(0.65) : Color.white.opacity(0.08)
    }
}

private struct PaneHeaderView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    let pane: PaneState

    var body: some View {
        HStack(spacing: 10) {
            Text(pane.kind.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if workspace.activePaneID == pane.id, let selectedTab = pane.selectedTab {
                Text(selectedTab.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
    }
}

private struct PaneBodyView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    let pane: PaneState

    var body: some View {
        let selectedTab = pane.selectedTab

        Group {
            switch pane.kind {
            case .text:
                TextPaneView(
                    document: workspace.document(for: selectedTab),
                    textBinding: selectedTab?.documentID.map { workspace.bindingForDocument($0) }
                )
            case .chat:
                ChatPanePlaceholderView()
            case .terminal:
                TerminalPanePlaceholderView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TextPaneView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    let document: DocumentState?
    let textBinding: Binding<String>?

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let textBinding, let document {
                    CodeEditorView(
                        documentID: document.id,
                        currentLineNumber: workspace.currentLineNumber,
                        text: textBinding,
                        selectedRange: $workspace.activeSelectionRange
                    )
                    .id(document.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                } else {
                    Text("Open a file from Explorer")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(18)
                }
            }
            .background(Color(red: 0.07, green: 0.08, blue: 0.1))

            Divider().overlay(Color.white.opacity(0.05))

            TextInspectorView(document: document)
                .frame(width: 176)
                .background(Color.black.opacity(0.08))
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.1))
    }
}

private struct GoToLineSheet: View {
    @EnvironmentObject private var workspace: WorkspaceState
    @Environment(\.dismiss) private var dismiss
    @State private var lineText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Go To Line")
                .font(.title3.weight(.semibold))

            Text("Current line: \(workspace.currentLineNumber)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField("Line number", text: $lineText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    submit()
                }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Go") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(Int(lineText.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            lineText = "\(workspace.currentLineNumber)"
        }
    }

    private func submit() {
        guard let line = Int(lineText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        workspace.goToLine(line)
        dismiss()
    }
}

private struct TextInspectorView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    let document: DocumentState?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Overview")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(document?.title ?? "No Document")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 8) {
                inspectorRow("Lines", value: "\(lineCount)")
                inspectorRow("Words", value: "\(wordCount)")
                inspectorRow("Chars", value: "\(characterCount)")
                inspectorRow("Cursor", value: "Ln \(workspace.currentLineNumber)")
                inspectorRow("State", value: document?.isDirty == true ? "Unsaved" : "Saved")
                inspectorRow("Type", value: document?.metadata.kindName ?? "-")
                inspectorRow("Encoding", value: document?.metadata.encodingName ?? "-")
                inspectorRow("Line End", value: document?.metadata.lineEnding.rawValue ?? "-")
                inspectorRow("Access", value: document?.metadata.isReadOnly == true ? "Read Only" : "Writable")
            }

            Divider().overlay(Color.white.opacity(0.05))

            VStack(alignment: .leading, spacing: 8) {
                Text("Minimap")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(minimapLines.indices, id: \.self) { index in
                            Button {
                                workspace.goToLine(index + 1)
                            } label: {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(minimapColor(for: index + 1))
                                    .frame(width: minimapWidth(for: minimapLines[index]), height: 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
        .padding(12)
    }

    private func inspectorRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.white.opacity(0.88))
        }
        .font(.system(size: 11, weight: .medium))
    }

    private var text: String {
        document?.text ?? ""
    }

    private var lineCount: Int {
        max(logicalLines(in: text).count, 1)
    }

    private var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var characterCount: Int {
        text.count
    }

    private var minimapLines: [String] {
        let rawLines = logicalLines(in: text)
        if rawLines.isEmpty {
            return [""]
        }
        return Array(rawLines.prefix(220))
    }

    private func minimapWidth(for line: String) -> CGFloat {
        let clamped = min(max(line.count, 2), 42)
        return CGFloat(clamped) * 2.6
    }

    private func minimapColor(for lineNumber: Int) -> Color {
        if lineNumber == workspace.currentLineNumber {
            return Color.accentColor.opacity(0.9)
        }
        return lineNumber == 1 ? Color.white.opacity(0.32) : Color.white.opacity(0.16)
    }
}

private struct ChatPanePlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LLM Chat")
                .font(.title3.weight(.semibold))
            Text("Pane session state will be separated from document state.")
                .foregroundStyle(.secondary)
            Spacer()
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .frame(height: 64)
                .overlay(alignment: .leading) {
                    Text("Ask about the current file, summarize text, or rewrite a selection.")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                }
        }
        .padding(18)
    }
}

private struct TerminalPanePlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Simple Terminal")
                .font(.title3.weight(.semibold))
            Text("$ pwd")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.green.opacity(0.9))
            Text("/workspace")
                .font(.system(size: 13, design: .monospaced))
            Text("Restricted command execution will attach here in a later phase.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(18)
    }
}

private struct StatusBarView: View {
    @EnvironmentObject private var workspace: WorkspaceState

    var body: some View {
        HStack(spacing: 18) {
            Text(workspace.activePane?.selectedTab?.title ?? "No Tab")
            Text(workspace.activePane?.kind.rawValue ?? "No Pane")
            Text(workspace.layoutPreset.title)
            Text(workspace.workspaceTitle)
            Spacer()
            Text(workspace.activeDocument?.title ?? "No File")
            Text(workspace.activeDocument?.isDirty == true ? "Unsaved" : "Saved")
            if let document = workspace.activeDocument {
                Text(document.metadata.kindName)
                Text(document.metadata.encodingName)
            }
            Text("Ln \(workspace.currentLineNumber), Col \(workspace.currentColumnNumber)")
            if !workspace.search.query.isEmpty {
                Text(searchSummary)
            }
            Text("\(workspace.activePane?.tabs.count ?? 0) Tabs")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.22))
    }

    private var searchSummary: String {
        if let current = workspace.selectedSearchResultIndex {
            return "Find \(current)/\(workspace.search.results.count)"
        }
        return "Find 0/\(workspace.search.results.count)"
    }
}
