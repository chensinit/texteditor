//
//  CodeEditorContainerView.swift
//  TextViewer
//
//  Created by Codex on 4/9/26.
//

import AppKit

final class CodeEditorContainerView: NSView {
    let scrollView: NSScrollView
    let textView: NSTextView
    let gutterView: CodeEditorGutterView

    var onTextChange: ((String, NSRange) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?

    override init(frame frameRect: NSRect) {
        scrollView = NSTextView.scrollableTextView()
        textView = scrollView.documentView as? NSTextView ?? NSTextView(frame: .zero)
        gutterView = CodeEditorGutterView(frame: .zero)

        super.init(frame: frameRect)

        configureScrollView()
        configureTextView()
        configureGutterView()
        installHierarchy()
        installObservers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layout() {
        super.layout()

        let gutterFrame = NSRect(x: 0, y: 0, width: CodeEditorMetrics.gutterWidth, height: bounds.height)
        let scrollFrame = NSRect(
            x: gutterFrame.maxX,
            y: 0,
            width: max(bounds.width - gutterFrame.width, 0),
            height: bounds.height
        )

        gutterView.frame = gutterFrame
        scrollView.frame = scrollFrame
        syncGutterScrollOffset()
    }

    func update(text: String, selectedRange: NSRange, currentLineNumber: Int) {
        let isFocused = window?.firstResponder === textView
        let isComposing = textView.hasMarkedText()

        if textView.string != text && !isFocused && !isComposing {
            textView.string = text
        }

        if
            selectedRange.location != NSNotFound,
            !NSEqualRanges(textView.selectedRange(), selectedRange),
            !isComposing
        {
            textView.setSelectedRange(selectedRange)
            textView.scrollRangeToVisible(selectedRange)
        }

        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )

        gutterView.currentLineNumber = currentLineNumber
        syncGutterScrollOffset()
        gutterView.needsDisplay = true
    }

    @objc
    private func textDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === textView else { return }
        onTextChange?(textView.string, textView.selectedRange())
        gutterView.needsDisplay = true
    }

    @objc
    private func selectionDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === textView else { return }
        onSelectionChange?(textView.selectedRange())
        gutterView.needsDisplay = true
    }

    @objc
    private func boundsDidChange(_ notification: Notification) {
        guard notification.object as? NSClipView === scrollView.contentView else { return }
        syncGutterScrollOffset()
        gutterView.needsDisplay = true
    }

    private func configureScrollView() {
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    private func configureTextView() {
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.drawsBackground = true
        textView.backgroundColor = CodeEditorMetrics.editorBackgroundColor
        textView.textColor = CodeEditorMetrics.textColor
        textView.insertionPointColor = .white
        textView.font = CodeEditorMetrics.textFont
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(
            width: CodeEditorMetrics.horizontalInset,
            height: CodeEditorMetrics.verticalInset
        )

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
            textContainer.lineFragmentPadding = 0
        }
    }

    private func configureGutterView() {
        gutterView.wantsLayer = true
        gutterView.textView = textView
    }

    private func installHierarchy() {
        addSubview(gutterView)
        addSubview(scrollView)
    }

    private func installObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    private func syncGutterScrollOffset() {
        let visibleBounds = scrollView.contentView.bounds
        gutterView.setBoundsOrigin(NSPoint(x: 0, y: visibleBounds.origin.y))
    }
}
