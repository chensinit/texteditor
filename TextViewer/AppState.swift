//
//  AppState.swift
//  TextViewer
//
//  Created by Codex on 4/8/26.
//

import Foundation
import Combine
import SwiftUI

func logicalLines(in text: String) -> [String] {
    let nsText = text as NSString
    let fullRange = NSRange(location: 0, length: nsText.length)
    var lines: [String] = []

    nsText.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, substringRange, _, _ in
        lines.append(nsText.substring(with: substringRange))
    }

    if lines.isEmpty {
        return [""]
    }

    if text.hasSuffix("\n") || text.hasSuffix("\r") {
        lines.append("")
    }

    return lines
}

private func linePosition(in text: String, selectedRange: NSRange) -> (line: Int, column: Int) {
    let nsText = text as NSString
    let clampedLocation = min(max(selectedRange.location, 0), nsText.length)

    guard selectedRange.location != NSNotFound else {
        return (1, 1)
    }
    let prefix = nsText.substring(to: clampedLocation)
    let lines = logicalLines(in: prefix)
    let line = max(lines.count, 1)
    let column = (lines.last?.count ?? 0) + 1
    return (line, column)
}

enum PaneKind: String, CaseIterable, Identifiable, Codable {
    case text = "Text"
    case chat = "LLM Chat"
    case terminal = "Simple Terminal"

    var id: String { rawValue }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case explorer = "Explorer"
    case search = "Search"

    var id: String { rawValue }
}

enum LayoutPreset: String, CaseIterable, Identifiable, Codable {
    case single
    case twoColumns
    case threeColumns
    case quad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: "1 Pane"
        case .twoColumns: "2 Panes"
        case .threeColumns: "3 Panes"
        case .quad: "4 Panes"
        }
    }

    var paneCount: Int {
        switch self {
        case .single: 1
        case .twoColumns: 2
        case .threeColumns: 3
        case .quad: 4
        }
    }
}

struct DocumentState: Identifiable, Hashable {
    let id: UUID
    var title: String
    var filePath: String?
    var text: String
    var isDirty: Bool

    init(
        id: UUID = UUID(),
        title: String,
        filePath: String? = nil,
        text: String = "",
        isDirty: Bool = false
    ) {
        self.id = id
        self.title = title
        self.filePath = filePath
        self.text = text
        self.isDirty = isDirty
    }
}

struct TabState: Identifiable, Hashable {
    let id: UUID
    var title: String
    var documentID: UUID?
    var kind: PaneKind

    init(id: UUID = UUID(), title: String, documentID: UUID? = nil, kind: PaneKind) {
        self.id = id
        self.title = title
        self.documentID = documentID
        self.kind = kind
    }
}

struct PaneState: Identifiable, Hashable {
    let id: UUID
    var kind: PaneKind
    var tabs: [TabState]
    var selectedTabID: UUID?

    init(id: UUID = UUID(), kind: PaneKind, tabs: [TabState]) {
        self.id = id
        self.kind = kind
        self.tabs = tabs
        self.selectedTabID = tabs.first?.id
    }

    var selectedTab: TabState? {
        tabs.first(where: { $0.id == selectedTabID }) ?? tabs.first
    }
}

struct SidebarState {
    var isVisible: Bool = true
    var selectedSection: SidebarSection = .explorer
}

struct FileItem: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileItem]?

    init(url: URL, isDirectory: Bool, children: [FileItem]? = nil) {
        self.id = url.path
        self.name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }
}

struct SearchResult: Identifiable, Hashable {
    let id: UUID
    let lineNumber: Int
    let lineText: String
    let range: NSRange

    init(lineNumber: Int, lineText: String, range: NSRange) {
        self.id = UUID()
        self.lineNumber = lineNumber
        self.lineText = lineText
        self.range = range
    }
}

struct SearchState {
    var query: String = ""
    var results: [SearchResult] = []
    var selectedResultID: UUID?
}

private struct SessionSnapshot: Codable {
    var layoutPreset: LayoutPreset
    var workspaceRootPath: String?
    var sidebarVisible: Bool
    var sidebarSection: SidebarSectionSnapshot
    var panes: [PaneSnapshot]
    var activePaneID: UUID?
}

private enum SidebarSectionSnapshot: String, Codable {
    case explorer
    case search
}

private struct PaneSnapshot: Codable {
    var id: UUID
    var kind: PaneKind
    var tabs: [TabSnapshot]
    var selectedTabID: UUID?
}

private struct TabSnapshot: Codable {
    var id: UUID
    var title: String
    var documentPath: String?
    var draftDocumentID: UUID?
    var draftText: String?
    var kind: PaneKind
}

@MainActor
final class WorkspaceState: ObservableObject {
    private static let sessionDefaultsKey = "workspace.session.snapshot"
    @Published var layoutPreset: LayoutPreset = .single
    @Published var sidebar = SidebarState()
    @Published var panes: [PaneState]
    @Published var activePaneID: UUID?
    @Published var documents: [DocumentState]
    @Published var workspaceRootURL: URL?
    @Published var fileTree: [FileItem] = []
    @Published var selectedFileURL: URL?
    @Published var fileSystemError: String?
    @Published var pendingCloseConfirmation: PendingCloseState?
    @Published var search = SearchState()
    @Published var activeSelectionRange = NSRange(location: NSNotFound, length: 0)
    @Published var isShowingGoToLine = false

    init() {
        let welcomeDocument = DocumentState(
            title: "Welcome",
            text: """
            Text Viewer / Editor

            Phase 1 shell is active.
            - Sidebar and pane system are structured.
            - Layout preset switching is available.
            - Text, chat, and terminal panes are modeled separately.
            """
        )

        let welcomeTab = TabState(title: welcomeDocument.title, documentID: welcomeDocument.id, kind: .text)
        let textPane = PaneState(kind: .text, tabs: [welcomeTab])

        let chatTab = TabState(title: "Assistant", kind: .chat)
        let chatPane = PaneState(kind: .chat, tabs: [chatTab])

        let terminalTab = TabState(title: "Terminal", kind: .terminal)
        let terminalPane = PaneState(kind: .terminal, tabs: [terminalTab])

        let notesDocument = DocumentState(
            title: "Scratch",
            text: """
            Untitled draft space.

            This will become the base for autosaved temporary tabs in a later phase.
            """
        )
        let notesTab = TabState(title: notesDocument.title, documentID: notesDocument.id, kind: .text)
        let scratchPane = PaneState(kind: .text, tabs: [notesTab])

        self.documents = [welcomeDocument, notesDocument]
        self.panes = [textPane, chatPane, terminalPane, scratchPane]
        self.activePaneID = textPane.id
        applyLayout(.single)
    }

    func restoreSessionIfPossible() {
        guard let data = UserDefaults.standard.data(forKey: Self.sessionDefaultsKey) else {
            return
        }

        do {
            let snapshot = try JSONDecoder().decode(SessionSnapshot.self, from: data)
            restore(from: snapshot)
        } catch {
            fileSystemError = "Failed to restore previous session."
        }
    }

    func persistSession() {
        do {
            let snapshot = makeSessionSnapshot()
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: Self.sessionDefaultsKey)
        } catch {
            fileSystemError = "Failed to save session state."
        }
    }

    var activePane: PaneState? {
        guard let activePaneID else { return panes.first }
        return panes.first(where: { $0.id == activePaneID }) ?? panes.first
    }

    func applyLayout(_ preset: LayoutPreset) {
        layoutPreset = preset
        let requiredCount = preset.paneCount

        if panes.count < requiredCount {
            while panes.count < requiredCount {
                panes.append(Self.makePlaceholderPane(index: panes.count))
            }
        } else if panes.count > requiredCount {
            panes = Array(panes.prefix(requiredCount))
        }

        if let activePaneID, panes.contains(where: { $0.id == activePaneID }) {
            return
        }

        activePaneID = panes.first?.id
    }

    func setActivePane(_ paneID: UUID) {
        activePaneID = paneID
        refreshSearchResults()
    }

    func cycleSidebarSection() {
        let allSections = SidebarSection.allCases
        guard let currentIndex = allSections.firstIndex(of: sidebar.selectedSection) else { return }
        let nextIndex = allSections.index(after: currentIndex)
        sidebar.selectedSection = allSections[nextIndex == allSections.endIndex ? allSections.startIndex : nextIndex]
    }

    func setSidebarSection(_ section: SidebarSection) {
        sidebar.selectedSection = section
    }

    func toggleSidebar() {
        sidebar.isVisible.toggle()
    }

    func setPaneKind(_ kind: PaneKind, for paneID: UUID) {
        guard let paneIndex = panes.firstIndex(where: { $0.id == paneID }) else { return }

        panes[paneIndex].kind = kind

        if panes[paneIndex].tabs.isEmpty || panes[paneIndex].selectedTab?.kind != kind {
            let title: String
            switch kind {
            case .text:
                title = "Untitled"
            case .chat:
                title = "Assistant"
            case .terminal:
                title = "Terminal"
            }

            let tab = TabState(title: title, kind: kind)
            panes[paneIndex].tabs = [tab]
            panes[paneIndex].selectedTabID = tab.id
        }
    }

    func createNewDocument() {
        let title = nextUntitledName()
        let document = DocumentState(title: title, text: "", isDirty: false)
        documents.append(document)
        attachDocumentToTextPane(document)
    }

    func selectTab(_ tabID: UUID, in paneID: UUID) {
        guard let paneIndex = panes.firstIndex(where: { $0.id == paneID }) else { return }
        panes[paneIndex].selectedTabID = tabID
        activePaneID = paneID
        refreshSearchResults()
    }

    func requestCloseTab(_ tabID: UUID, in paneID: UUID) {
        guard let paneIndex = panes.firstIndex(where: { $0.id == paneID }) else { return }
        guard let tab = panes[paneIndex].tabs.first(where: { $0.id == tabID }) else { return }

        if let document = document(for: tab), document.isDirty {
            pendingCloseConfirmation = PendingCloseState(
                paneID: paneID,
                tabID: tabID,
                documentTitle: document.title
            )
            return
        }

        closeTab(tabID, in: paneID)
    }

    func confirmClosePendingTab() {
        guard let pendingCloseConfirmation else { return }
        closeTab(pendingCloseConfirmation.tabID, in: pendingCloseConfirmation.paneID)
        self.pendingCloseConfirmation = nil
    }

    func cancelClosePendingTab() {
        pendingCloseConfirmation = nil
    }

    func document(for tab: TabState?) -> DocumentState? {
        guard let documentID = tab?.documentID else { return nil }
        return documents.first(where: { $0.id == documentID })
    }

    func bindingForDocument(_ documentID: UUID) -> Binding<String> {
        Binding(
            get: {
                self.documents.first(where: { $0.id == documentID })?.text ?? ""
            },
            set: { newValue in
                self.updateDocumentText(documentID: documentID, text: newValue)
            }
        )
    }

    func updateSearchQuery(_ query: String) {
        search.query = query
        refreshSearchResults()
    }

    func selectSearchResult(_ resultID: UUID) {
        guard let result = search.results.first(where: { $0.id == resultID }) else { return }
        search.selectedResultID = resultID
        activeSelectionRange = result.range
    }

    func goToLine(_ lineNumber: Int) {
        guard let document = activeDocument else { return }

        let clampedLine = max(lineNumber, 1)
        let nsText = document.text as NSString
        let lines = logicalLines(in: document.text)

        guard !lines.isEmpty else {
            activeSelectionRange = NSRange(location: 0, length: 0)
            return
        }

        let targetIndex = min(clampedLine - 1, lines.count - 1)
        var location = 0

        for index in 0..<targetIndex {
            location += (lines[index] as NSString).length
            let lineRange = nsText.lineRange(for: NSRange(location: min(location, nsText.length), length: 0))
            let consumedLength = lineRange.length - (lines[index] as NSString).length
            location += max(consumedLength, 0)
        }

        let safeLocation = min(location, nsText.length)
        activeSelectionRange = NSRange(location: safeLocation, length: 0)
    }

    func presentGoToLine() {
        isShowingGoToLine = true
    }

    func selectNextSearchResult() {
        guard !search.results.isEmpty else { return }

        if let selectedResultID = search.selectedResultID,
           let currentIndex = search.results.firstIndex(where: { $0.id == selectedResultID }) {
            let nextIndex = (currentIndex + 1) % search.results.count
            selectSearchResult(search.results[nextIndex].id)
            return
        }

        selectSearchResult(search.results[0].id)
    }

    func selectPreviousSearchResult() {
        guard !search.results.isEmpty else { return }

        if let selectedResultID = search.selectedResultID,
           let currentIndex = search.results.firstIndex(where: { $0.id == selectedResultID }) {
            let previousIndex = (currentIndex - 1 + search.results.count) % search.results.count
            selectSearchResult(search.results[previousIndex].id)
            return
        }

        selectSearchResult(search.results[0].id)
    }

    func openWorkspace(at url: URL) {
        workspaceRootURL = url
        sidebar.selectedSection = .explorer
        selectedFileURL = nil

        do {
            fileTree = try Self.loadDirectoryItems(at: url)
            fileSystemError = nil
        } catch {
            fileTree = []
            fileSystemError = error.localizedDescription
        }
    }

    func selectFile(_ url: URL) {
        selectedFileURL = url
    }

    func openFile(_ url: URL) {
        selectedFileURL = url

        guard !isDirectory(url) else { return }

        if let existingDocument = documents.first(where: { $0.filePath == url.path }) {
            revealDocument(existingDocument.id)
            return
        }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let document = DocumentState(
                title: url.lastPathComponent,
                filePath: url.path,
                text: text,
                isDirty: false
            )
            documents.append(document)
            attachDocumentToTextPane(document)
            fileSystemError = nil
            refreshSearchResults()
        } catch {
            fileSystemError = "Failed to open file: \(url.lastPathComponent)"
        }
    }

    var workspaceTitle: String {
        workspaceRootURL?.lastPathComponent ?? "No Folder"
    }

    var workspacePath: String? {
        workspaceRootURL?.path
    }

    var activeDocument: DocumentState? {
        document(for: activePane?.selectedTab)
    }

    var currentLineNumber: Int {
        position.line
    }

    var currentColumnNumber: Int {
        position.column
    }

    var selectedSearchResultIndex: Int? {
        guard let selectedResultID = search.selectedResultID,
              let index = search.results.firstIndex(where: { $0.id == selectedResultID }) else {
            return nil
        }
        return index + 1
    }

    func saveActiveDocument() throws {
        guard let document = activeDocument else { return }
        guard let filePath = document.filePath else { return }
        try saveDocument(documentID: document.id, to: URL(fileURLWithPath: filePath))
    }

    func saveActiveDocument(as url: URL) throws {
        guard let document = activeDocument else { return }
        try saveDocument(documentID: document.id, to: url)
    }

    func setFileSystemError(_ message: String?) {
        fileSystemError = message
    }

    private static func loadDirectoryItems(at rootURL: URL) throws -> [FileItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey, .isRegularFileKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        return try urls
            .sorted(by: sortFileURLs)
            .map { try loadFileItem(at: $0) }
    }

    private static func loadFileItem(at url: URL) throws -> FileItem {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = values.isDirectory ?? false

        if !isDirectory {
            return FileItem(url: url, isDirectory: false)
        }

        let children = try loadDirectoryItems(at: url)
        return FileItem(url: url, isDirectory: true, children: children)
    }

    private static func sortFileURLs(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsValues = try? lhs.resourceValues(forKeys: [.isDirectoryKey])
        let rhsValues = try? rhs.resourceValues(forKeys: [.isDirectoryKey])
        let lhsIsDirectory = lhsValues?.isDirectory ?? false
        let rhsIsDirectory = rhsValues?.isDirectory ?? false

        if lhsIsDirectory != rhsIsDirectory {
            return lhsIsDirectory && !rhsIsDirectory
        }

        return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
    }

    private func updateDocumentText(documentID: UUID, text: String) {
        guard let documentIndex = documents.firstIndex(where: { $0.id == documentID }) else { return }

        documents[documentIndex].text = text
        documents[documentIndex].isDirty = true

        let title = documents[documentIndex].title
        for paneIndex in panes.indices {
            for tabIndex in panes[paneIndex].tabs.indices where panes[paneIndex].tabs[tabIndex].documentID == documentID {
                panes[paneIndex].tabs[tabIndex].title = title
            }
        }

        if activeDocument?.id == documentID {
            refreshSearchResults()
        }
    }

    private func closeTab(_ tabID: UUID, in paneID: UUID) {
        guard let paneIndex = panes.firstIndex(where: { $0.id == paneID }) else { return }
        guard let tabIndex = panes[paneIndex].tabs.firstIndex(where: { $0.id == tabID }) else { return }

        let tab = panes[paneIndex].tabs[tabIndex]
        panes[paneIndex].tabs.remove(at: tabIndex)

        if panes[paneIndex].tabs.isEmpty {
            let replacementTab = defaultTab(for: panes[paneIndex].kind)
            panes[paneIndex].tabs = [replacementTab]
            panes[paneIndex].selectedTabID = replacementTab.id
        } else {
            panes[paneIndex].selectedTabID = panes[paneIndex].tabs.last?.id
        }

        if let documentID = tab.documentID {
            let isDocumentStillOpen = panes.contains { pane in
                pane.tabs.contains(where: { $0.documentID == documentID })
            }

            if !isDocumentStillOpen {
                documents.removeAll(where: { $0.id == documentID && $0.filePath == nil })
            }
        }

        if activePaneID == paneID {
            activePaneID = panes[paneIndex].id
        }
    }

    private func defaultTab(for kind: PaneKind) -> TabState {
        let title: String
        switch kind {
        case .text:
            title = "Untitled"
        case .chat:
            title = "Assistant"
        case .terminal:
            title = "Terminal"
        }

        return TabState(title: title, kind: kind)
    }

    private func nextUntitledName() -> String {
        let untitledDocuments = documents
            .map(\.title)
            .filter { $0 == "Untitled" || $0.hasPrefix("Untitled ") }

        if !untitledDocuments.contains("Untitled") {
            return "Untitled"
        }

        var number = 2
        while untitledDocuments.contains("Untitled \(number)") {
            number += 1
        }
        return "Untitled \(number)"
    }

    private func saveDocument(documentID: UUID, to url: URL) throws {
        guard let documentIndex = documents.firstIndex(where: { $0.id == documentID }) else { return }

        try documents[documentIndex].text.write(to: url, atomically: true, encoding: .utf8)

        documents[documentIndex].filePath = url.path
        documents[documentIndex].title = url.lastPathComponent
        documents[documentIndex].isDirty = false
        selectedFileURL = url

        for paneIndex in panes.indices {
            for tabIndex in panes[paneIndex].tabs.indices where panes[paneIndex].tabs[tabIndex].documentID == documentID {
                panes[paneIndex].tabs[tabIndex].title = url.lastPathComponent
            }
        }
    }

    private func makeSessionSnapshot() -> SessionSnapshot {
        SessionSnapshot(
            layoutPreset: layoutPreset,
            workspaceRootPath: workspaceRootURL?.path,
            sidebarVisible: sidebar.isVisible,
            sidebarSection: sidebar.selectedSection == .explorer ? .explorer : .search,
            panes: panes.map { pane in
                PaneSnapshot(
                    id: pane.id,
                    kind: pane.kind,
                    tabs: pane.tabs.map { tab in
                        let document = document(for: tab)
                        return TabSnapshot(
                            id: tab.id,
                            title: tab.title,
                            documentPath: document?.filePath,
                            draftDocumentID: document?.filePath == nil ? document?.id : nil,
                            draftText: document?.filePath == nil ? document?.text : nil,
                            kind: tab.kind
                        )
                    },
                    selectedTabID: pane.selectedTabID
                )
            },
            activePaneID: activePaneID
        )
    }

    private func restore(from snapshot: SessionSnapshot) {
        layoutPreset = snapshot.layoutPreset
        sidebar.isVisible = snapshot.sidebarVisible
        sidebar.selectedSection = snapshot.sidebarSection == .explorer ? .explorer : .search

        if let workspaceRootPath = snapshot.workspaceRootPath {
            let workspaceURL = URL(fileURLWithPath: workspaceRootPath)
            if FileManager.default.fileExists(atPath: workspaceURL.path) {
                openWorkspace(at: workspaceURL)
            }
        }

        let restoredPanes = snapshot.panes.map { paneSnapshot in
            restorePane(from: paneSnapshot)
        }

        let validPanes = restoredPanes.isEmpty ? panes : restoredPanes
        panes = Array(validPanes.prefix(snapshot.layoutPreset.paneCount))

        if panes.count < snapshot.layoutPreset.paneCount {
            while panes.count < snapshot.layoutPreset.paneCount {
                panes.append(Self.makePlaceholderPane(index: panes.count))
            }
        }

        if let activePaneID = snapshot.activePaneID,
           panes.contains(where: { $0.id == activePaneID }) {
            self.activePaneID = activePaneID
        } else {
            self.activePaneID = panes.first?.id
        }

        refreshSearchResults()
    }

    private func restorePane(from snapshot: PaneSnapshot) -> PaneState {
        var restoredTabs: [TabState] = []

        for tabSnapshot in snapshot.tabs {
            var documentID: UUID?

            if let documentPath = tabSnapshot.documentPath {
                let url = URL(fileURLWithPath: documentPath)
                if let existingDocument = documents.first(where: { $0.filePath == documentPath }) {
                    documentID = existingDocument.id
                } else if FileManager.default.fileExists(atPath: documentPath),
                          let text = try? String(contentsOf: url, encoding: .utf8) {
                    let document = DocumentState(
                        title: url.lastPathComponent,
                        filePath: documentPath,
                        text: text,
                        isDirty: false
                    )
                    documents.append(document)
                    documentID = document.id
                }
            } else if let draftDocumentID = tabSnapshot.draftDocumentID {
                if let existingDocument = documents.first(where: { $0.id == draftDocumentID }) {
                    documentID = existingDocument.id
                } else {
                    let document = DocumentState(
                        id: draftDocumentID,
                        title: tabSnapshot.title,
                        filePath: nil,
                        text: tabSnapshot.draftText ?? "",
                        isDirty: !(tabSnapshot.draftText ?? "").isEmpty
                    )
                    documents.append(document)
                    documentID = document.id
                }
            }

            if tabSnapshot.kind != .text || documentID != nil {
                restoredTabs.append(
                    TabState(
                        id: tabSnapshot.id,
                        title: tabSnapshot.title,
                        documentID: documentID,
                        kind: tabSnapshot.kind
                    )
                )
            }
        }

        if restoredTabs.isEmpty {
            restoredTabs = [defaultTab(for: snapshot.kind)]
        }

        var pane = PaneState(id: snapshot.id, kind: snapshot.kind, tabs: restoredTabs)
        pane.selectedTabID = restoredTabs.contains(where: { $0.id == snapshot.selectedTabID }) ? snapshot.selectedTabID : restoredTabs.first?.id
        return pane
    }

    private func refreshSearchResults() {
        guard let document = activeDocument else {
            search.results = []
            search.selectedResultID = nil
            activeSelectionRange = NSRange(location: NSNotFound, length: 0)
            return
        }

        let query = search.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            search.results = []
            search.selectedResultID = nil
            activeSelectionRange = NSRange(location: NSNotFound, length: 0)
            return
        }

        let text = document.text
        let nsText = text as NSString
        let fullLength = nsText.length
        let queryLength = (query as NSString).length
        guard fullLength > 0, queryLength > 0 else {
            search.results = []
            search.selectedResultID = nil
            activeSelectionRange = NSRange(location: NSNotFound, length: 0)
            return
        }

        var foundResults: [SearchResult] = []
        var searchRange = NSRange(location: 0, length: fullLength)

        while true {
            let foundRange = nsText.range(of: query, options: [.caseInsensitive], range: searchRange)
            if foundRange.location == NSNotFound {
                break
            }

            let prefixText = nsText.substring(to: foundRange.location)
            let lineNumber = logicalLines(in: prefixText).count
            let lineRange = nsText.lineRange(for: foundRange)
            let rawLine = nsText.substring(with: lineRange)
            let lineText = rawLine.trimmingCharacters(in: .newlines)
            foundResults.append(SearchResult(lineNumber: lineNumber, lineText: lineText, range: foundRange))

            let nextLocation = foundRange.location + max(foundRange.length, 1)
            if nextLocation >= fullLength {
                break
            }
            searchRange = NSRange(location: nextLocation, length: fullLength - nextLocation)
        }

        search.results = foundResults

        if let selectedResultID = search.selectedResultID,
           let selectedResult = foundResults.first(where: { $0.id == selectedResultID }) {
            activeSelectionRange = selectedResult.range
        } else if let firstResult = foundResults.first {
            search.selectedResultID = firstResult.id
            activeSelectionRange = firstResult.range
        } else {
            search.selectedResultID = nil
            activeSelectionRange = NSRange(location: NSNotFound, length: 0)
        }
    }

    private var position: (line: Int, column: Int) {
        guard let document = activeDocument else { return (1, 1) }
        guard activeSelectionRange.location != NSNotFound else { return (1, 1) }
        return linePosition(in: document.text, selectedRange: activeSelectionRange)
    }

    private func revealDocument(_ documentID: UUID) {
        for index in panes.indices {
            if let tab = panes[index].tabs.first(where: { $0.documentID == documentID }) {
                panes[index].selectedTabID = tab.id
                activePaneID = panes[index].id
                refreshSearchResults()
                return
            }
        }

        guard let document = documents.first(where: { $0.id == documentID }) else { return }
        attachDocumentToTextPane(document)
    }

    private func attachDocumentToTextPane(_ document: DocumentState) {
        guard let targetPaneIndex = targetTextPaneIndex else { return }

        let tab = TabState(title: document.title, documentID: document.id, kind: .text)
        panes[targetPaneIndex].kind = .text
        panes[targetPaneIndex].tabs.append(tab)
        panes[targetPaneIndex].selectedTabID = tab.id
        activePaneID = panes[targetPaneIndex].id
        activeSelectionRange = NSRange(location: NSNotFound, length: 0)
        refreshSearchResults()
    }

    private var targetTextPaneIndex: Int? {
        if let activePaneID,
           let activeIndex = panes.firstIndex(where: { $0.id == activePaneID && $0.kind == .text }) {
            return activeIndex
        }

        return panes.firstIndex(where: { $0.kind == .text })
    }

    private func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory ?? false
    }

    private static func makePlaceholderPane(index: Int) -> PaneState {
        let kind: PaneKind
        switch index % 3 {
        case 0: kind = .text
        case 1: kind = .chat
        default: kind = .terminal
        }

        let title: String
        switch kind {
        case .text:
            title = "Untitled \(index + 1)"
        case .chat:
            title = "Assistant \(index + 1)"
        case .terminal:
            title = "Terminal \(index + 1)"
        }

        let tab = TabState(title: title, kind: kind)
        return PaneState(kind: kind, tabs: [tab])
    }
}

struct PendingCloseState: Identifiable {
    let id = UUID()
    let paneID: UUID
    let tabID: UUID
    let documentTitle: String
}
