//
//  CodeEditorGutterView.swift
//  TextViewer
//
//  Created by Codex on 4/9/26.
//

import AppKit

final class CodeEditorGutterView: NSView {
    var fontSize: CGFloat = CodeEditorMetrics.defaultTextFontSize {
        didSet {
            if oldValue != fontSize {
                needsDisplay = true
            }
        }
    }

    weak var textView: NSTextView? {
        didSet {
            needsDisplay = true
        }
    }

    var currentLineNumber: Int = 1 {
        didSet {
            if oldValue != currentLineNumber {
                needsDisplay = true
            }
        }
    }

    var highlightsCurrentLine: Bool = true {
        didSet {
            if oldValue != highlightsCurrentLine {
                needsDisplay = true
            }
        }
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        CodeEditorMetrics.gutterBackgroundColor.setFill()
        dirtyRect.fill()

        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else {
            return
        }

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let text = textView.string as NSString

        guard glyphRange.length > 0 || text.length == 0 else {
            return
        }

        let startCharacterIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        let endGlyphIndex = max(glyphRange.location + glyphRange.length - 1, glyphRange.location)
        let endCharacterIndex = min(
            layoutManager.characterIndexForGlyph(at: endGlyphIndex),
            max(text.length - 1, 0)
        )

        let startLineNumber = lineNumber(at: startCharacterIndex, in: text)
        let endLineNumber = max(startLineNumber, lineNumber(at: endCharacterIndex, in: text))

        for lineNumber in startLineNumber...endLineNumber {
            let characterRange = characterRange(forLineNumber: lineNumber, in: text)
            guard characterRange.location != NSNotFound else { continue }

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterRange.location)
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange,
                withoutAdditionalLayout: true
            )

            if lineRect.isEmpty || !lineRect.intersects(visibleRect) {
                continue
            }

            let drawRect = NSRect(
                x: 0,
                y: lineRect.minY + textView.textContainerInset.height,
                width: bounds.width - CodeEditorMetrics.horizontalInset,
                height: lineRect.height
            )

            if highlightsCurrentLine && lineNumber == currentLineNumber {
                let highlightRect = NSRect(
                    x: 8,
                    y: drawRect.minY,
                    width: bounds.width - 16,
                    height: drawRect.height
                )
                let path = NSBezierPath(roundedRect: highlightRect, xRadius: 6, yRadius: 6)
                CodeEditorMetrics.currentLineHighlightColor.setFill()
                path.fill()
            }

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right

            let attributes: [NSAttributedString.Key: Any] = [
                .font: CodeEditorMetrics.lineNumberFont(size: fontSize),
                .foregroundColor: highlightsCurrentLine && lineNumber == currentLineNumber
                    ? CodeEditorMetrics.currentLineNumberColor
                    : CodeEditorMetrics.lineNumberColor,
                .paragraphStyle: paragraphStyle
            ]

            let attributedString = NSAttributedString(string: "\(lineNumber)", attributes: attributes)
            attributedString.draw(
                in: drawRect.offsetBy(dx: 0, dy: max((drawRect.height - CodeEditorMetrics.lineHeight(for: fontSize)) / 2, 0))
            )
        }
    }

    private func lineNumber(at characterIndex: Int, in text: NSString) -> Int {
        if text.length == 0 {
            return 1
        }

        let safeIndex = min(max(characterIndex, 0), max(text.length - 1, 0))
        var lineNumber = 1
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0

        while lineStart < text.length {
            text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))
            if safeIndex < lineEnd {
                return lineNumber
            }
            if lineEnd >= text.length {
                break
            }
            lineNumber += 1
            lineStart = lineEnd
        }

        return lineNumber
    }

    private func characterRange(forLineNumber lineNumber: Int, in text: NSString) -> NSRange {
        if lineNumber <= 1 {
            return NSRange(location: 0, length: min(1, text.length))
        }

        var currentLine = 1
        var searchLocation = 0
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0

        while searchLocation < text.length {
            text.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: searchLocation, length: 0))
            if currentLine == lineNumber {
                return NSRange(location: lineStart, length: max(contentsEnd - lineStart, 0))
            }
            currentLine += 1
            searchLocation = lineEnd
        }

        if text.length == 0 && lineNumber == 1 {
            return NSRange(location: 0, length: 0)
        }

        return NSRange(location: NSNotFound, length: 0)
    }
}
