//
//  EditorTextView.swift
//  TextViewer
//
//  Created by Codex on 4/8/26.
//

import AppKit
import SwiftUI

typealias EditorLayoutMetrics = CodeEditorMetrics

struct EditorTextView: NSViewRepresentable {
    let documentID: UUID
    @Binding var text: String
    @Binding var selectedRange: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.textContainerInset = NSSize(
            width: EditorLayoutMetrics.horizontalInset,
            height: EditorLayoutMetrics.verticalInset
        )
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1)
        textView.textColor = NSColor(calibratedWhite: 0.95, alpha: 1)
        textView.insertionPointColor = .white
        textView.font = EditorLayoutMetrics.textFont
        textView.allowsUndo = true

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
            textContainer.lineFragmentPadding = 0
        }

        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let isFocused = textView.window?.firstResponder === textView
        let isComposing = textView.hasMarkedText()

        if textView.string != text && !isFocused && !isComposing {
            context.coordinator.isProgrammaticUpdate = true
            textView.string = text
            context.coordinator.isProgrammaticUpdate = false
        }

        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )

        let currentRange = textView.selectedRange()
        if selectedRange.location != NSNotFound && !NSEqualRanges(currentRange, selectedRange) && !isComposing {
            textView.setSelectedRange(selectedRange)
            textView.scrollRangeToVisible(selectedRange)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var selectedRange: NSRange
        var isProgrammaticUpdate = false

        init(text: Binding<String>, selectedRange: Binding<NSRange>) {
            self._text = text
            self._selectedRange = selectedRange
        }

        func textDidChange(_ notification: Notification) {
            if isProgrammaticUpdate {
                return
            }
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            selectedRange = textView.selectedRange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            selectedRange = textView.selectedRange()
        }
    }
}
