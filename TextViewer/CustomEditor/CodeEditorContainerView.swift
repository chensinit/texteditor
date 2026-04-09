//
//  CodeEditorContainerView.swift
//  TextViewer
//
//  Created by Codex on 4/9/26.
//

import AppKit

final class CodeEditorContainerView: NSView {
    let scrollView: NSScrollView
    let textView: CodeEditorTextView
    let gutterView: CodeEditorGutterView

    var onTextChange: ((String, NSRange) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?
    private var pendingSelectionRange: NSRange?

    override init(frame frameRect: NSRect) {
        scrollView = NSTextView.scrollableTextView()
        textView = CodeEditorTextView(frame: .zero)
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
        applyPendingSelectionIfNeeded()
    }

    func update(text: String, selectedRange: NSRange, currentLineNumber: Int) {
        let isFocused = window?.firstResponder === textView
        let isComposing = textView.hasMarkedText()
        let shouldRestoreSelection = !isFocused && !isComposing

        if textView.string != text && !isFocused && !isComposing {
            textView.string = text
            textView.needsDisplay = true
        }

        if
            shouldRestoreSelection,
            selectedRange.location != NSNotFound,
            !NSEqualRanges(textView.selectedRange(), selectedRange),
            selectedRange.location <= (textView.string as NSString).length
        {
            pendingSelectionRange = selectedRange
            applyPendingSelectionIfNeeded()
        }

        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        updateTextViewDocumentSize()
        clampScrollOriginToDocumentBounds()

        gutterView.currentLineNumber = currentLineNumber
        syncGutterScrollOffset()
        textView.needsDisplay = true
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
        textView.needsDisplay = true
        textView.onNeedsCurrentLineRefresh?()
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
        scrollView.documentView = textView
    }

    private func configureTextView() {
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
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
            textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textContainer.lineFragmentPadding = 0
        }

        textView.onNeedsCurrentLineRefresh = { [weak self] in
            self?.gutterView.needsDisplay = true
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

    private func updateTextViewDocumentSize() {
        guard
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else {
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let contentHeight = ceil(usedRect.maxY + (textView.textContainerInset.height * 2))
        let targetHeight = max(contentHeight, scrollView.contentSize.height)
        textView.frame = NSRect(
            x: 0,
            y: 0,
            width: scrollView.contentSize.width,
            height: targetHeight
        )
    }

    private func clampScrollOriginToDocumentBounds() {
        let clipView = scrollView.contentView
        let maxOffsetY = max(textView.frame.height - clipView.bounds.height, 0)
        let clampedY = min(max(clipView.bounds.origin.y, 0), maxOffsetY)

        guard clampedY != clipView.bounds.origin.y else { return }
        clipView.scroll(to: NSPoint(x: 0, y: clampedY))
        scrollView.reflectScrolledClipView(clipView)
    }

    private func applyPendingSelectionIfNeeded() {
        guard let pendingSelectionRange else { return }
        guard scrollView.contentSize.width > 0, scrollView.contentSize.height > 0 else { return }

        textView.setSelectedRange(pendingSelectionRange)
        textView.needsDisplay = true
        self.pendingSelectionRange = nil
    }
}

final class CodeEditorTextView: NSTextView {
    var onNeedsCurrentLineRefresh: (() -> Void)?

    override func drawBackground(in rect: NSRect) {
        CodeEditorMetrics.editorBackgroundColor.setFill()
        rect.fill()

        drawCurrentLineHighlight()
    }

    override func insertTab(_ sender: Any?) {
        indentSelection()
    }

    override func insertBacktab(_ sender: Any?) {
        outdentSelection()
    }

    private func drawCurrentLineHighlight() {
        guard let layoutManager else { return }

        let selectedRange = selectedRange()
        guard selectedRange.location != NSNotFound else { return }

        let text = string as NSString
        let lineRange = text.lineRange(for: NSRange(location: min(selectedRange.location, text.length), length: 0))
        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
            let highlightRect = NSRect(
                x: 0,
                y: usedRect.minY + self.textContainerInset.height,
                width: self.bounds.width,
                height: usedRect.height
            )

            CodeEditorMetrics.currentLineFillColor.setFill()
            NSBezierPath(roundedRect: highlightRect, xRadius: 4, yRadius: 4).fill()
        }
    }

    private func indentSelection() {
        let originalRange = selectedRange()
        let text = string as NSString
        let affectedRange = selectedLineRange(for: originalRange, in: text)
        let selectedText = text.substring(with: affectedRange)
        let lines = selectedText.components(separatedBy: "\n")
        let indentedText = lines.map { CodeEditorMetrics.indentUnit + $0 }.joined(separator: "\n")

        applyReplacement(in: affectedRange, with: indentedText)

        let insertedIndentCount = lines.count * CodeEditorMetrics.indentUnit.count
        let updatedRange = NSRange(
            location: affectedRange.location == originalRange.location
                ? originalRange.location + CodeEditorMetrics.indentUnit.count
                : originalRange.location,
            length: originalRange.length + insertedIndentCount
        )
        setSelectedRange(updatedRange)
    }

    private func outdentSelection() {
        let originalRange = selectedRange()
        let text = string as NSString
        let affectedRange = selectedLineRange(for: originalRange, in: text)
        let selectedText = text.substring(with: affectedRange)
        let lines = selectedText.components(separatedBy: "\n")

        var removedLeadingCount = 0
        let outdentedLines = lines.enumerated().map { index, line -> String in
            if line.hasPrefix(CodeEditorMetrics.indentUnit) {
                if index == 0 {
                    removedLeadingCount = CodeEditorMetrics.indentUnit.count
                }
                return String(line.dropFirst(CodeEditorMetrics.indentUnit.count))
            }

            if line.hasPrefix("\t") {
                if index == 0 {
                    removedLeadingCount = 1
                }
                return String(line.dropFirst())
            }

            let removableSpaces = min(line.prefix { $0 == " " }.count, CodeEditorMetrics.indentUnit.count)
            if index == 0 {
                removedLeadingCount = removableSpaces
            }
            return String(line.dropFirst(removableSpaces))
        }

        let removedTotalCount = zip(lines, outdentedLines).reduce(into: 0) { count, pair in
            count += pair.0.count - pair.1.count
        }

        let outdentedText = outdentedLines.joined(separator: "\n")
        applyReplacement(in: affectedRange, with: outdentedText)

        let updatedLocation = max(originalRange.location - removedLeadingCount, affectedRange.location)
        let updatedLength = max(originalRange.length - removedTotalCount + removedLeadingCount, 0)
        setSelectedRange(NSRange(location: updatedLocation, length: updatedLength))
    }

    private func applyReplacement(in range: NSRange, with replacement: String) {
        guard let textStorage else { return }

        shouldChangeText(in: range, replacementString: replacement)
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: replacement)
        textStorage.endEditing()
        didChangeText()
        needsDisplay = true
        onNeedsCurrentLineRefresh?()
    }

    private func selectedLineRange(for selectedRange: NSRange, in text: NSString) -> NSRange {
        guard text.length > 0 else {
            return NSRange(location: 0, length: 0)
        }

        let startLocation = min(max(selectedRange.location, 0), text.length - 1)
        let startLineRange = text.lineRange(for: NSRange(location: startLocation, length: 0))

        let endLocation: Int
        if selectedRange.length == 0 {
            endLocation = startLocation
        } else {
            endLocation = min(max(NSMaxRange(selectedRange) - 1, 0), text.length - 1)
        }

        let endLineRange = text.lineRange(for: NSRange(location: endLocation, length: 0))
        let rangeEnd = NSMaxRange(endLineRange)
        return NSRange(location: startLineRange.location, length: rangeEnd - startLineRange.location)
    }
}
