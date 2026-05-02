//
//  CodeEditorView.swift
//  TextViewer
//
//  Created by Codex on 4/9/26.
//

import AppKit
import SwiftUI

struct CodeEditorView: NSViewRepresentable {
    let documentID: UUID
    let currentLineNumber: Int
    let fontSize: CGFloat
    let wrapsLines: Bool
    let highlightsCurrentLine: Bool
    let showsInvisibleCharacters: Bool
    let searchRanges: [NSRange]
    let selectedSearchRange: NSRange?
    let onOpenDroppedURL: (URL) -> Void
    let onViewportChange: (Int, Int, Int) -> Void
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange)
    }

    func makeNSView(context: Context) -> CodeEditorContainerView {
        let view = CodeEditorContainerView(frame: .zero)
        view.onTextChange = { updatedText, updatedRange in
            context.coordinator.handleTextChange(text: updatedText, selectedRange: updatedRange)
        }
        view.onSelectionChange = { updatedRange in
            context.coordinator.handleSelectionChange(updatedRange)
        }
        view.onViewportChange = onViewportChange
        view.onOpenDroppedURL = onOpenDroppedURL
        view.update(
            text: text,
            selectedRange: selectedRange,
            currentLineNumber: currentLineNumber,
            fontSize: fontSize,
            wrapsLines: wrapsLines,
            highlightsCurrentLine: highlightsCurrentLine,
            showsInvisibleCharacters: showsInvisibleCharacters,
            searchRanges: searchRanges,
            selectedSearchRange: selectedSearchRange
        )
        return view
    }

    func updateNSView(_ nsView: CodeEditorContainerView, context: Context) {
        nsView.onTextChange = { updatedText, updatedRange in
            context.coordinator.handleTextChange(text: updatedText, selectedRange: updatedRange)
        }
        nsView.onSelectionChange = { updatedRange in
            context.coordinator.handleSelectionChange(updatedRange)
        }
        nsView.onViewportChange = onViewportChange
        nsView.onOpenDroppedURL = onOpenDroppedURL
        nsView.update(
            text: text,
            selectedRange: selectedRange,
            currentLineNumber: currentLineNumber,
            fontSize: fontSize,
            wrapsLines: wrapsLines,
            highlightsCurrentLine: highlightsCurrentLine,
            showsInvisibleCharacters: showsInvisibleCharacters,
            searchRanges: searchRanges,
            selectedSearchRange: selectedSearchRange
        )
    }

    final class Coordinator: NSObject {
        @Binding private var text: String
        @Binding private var selectedRange: NSRange

        init(text: Binding<String>, selectedRange: Binding<NSRange>) {
            self._text = text
            self._selectedRange = selectedRange
        }

        func handleTextChange(text: String, selectedRange: NSRange) {
            self.text = text
            self.selectedRange = selectedRange
        }

        func handleSelectionChange(_ selectedRange: NSRange) {
            self.selectedRange = selectedRange
        }
    }
}
