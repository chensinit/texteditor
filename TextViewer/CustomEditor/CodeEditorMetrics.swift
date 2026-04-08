//
//  CodeEditorMetrics.swift
//  TextViewer
//
//  Created by Codex on 4/9/26.
//

import AppKit

enum CodeEditorMetrics {
    static let textFontSize: CGFloat = 14
    static let gutterWidth: CGFloat = 58
    static let horizontalInset: CGFloat = 10
    static let verticalInset: CGFloat = 14

    static let textFont: NSFont = .monospacedSystemFont(ofSize: textFontSize, weight: .regular)
    static let lineNumberFont: NSFont = .monospacedSystemFont(ofSize: textFontSize, weight: .regular)
    static let lineHeight: CGFloat = ceil(textFont.ascender - textFont.descender + textFont.leading)

    static let editorBackgroundColor = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1)
    static let gutterBackgroundColor = NSColor(calibratedWhite: 0.0, alpha: 0.14)
    static let textColor = NSColor(calibratedWhite: 0.95, alpha: 1)
    static let currentLineNumberColor = NSColor.white
    static let lineNumberColor = NSColor(calibratedWhite: 0.62, alpha: 1)
    static let currentLineHighlightColor = NSColor.controlAccentColor.withAlphaComponent(0.18)
}
