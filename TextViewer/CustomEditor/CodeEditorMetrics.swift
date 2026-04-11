//
//  CodeEditorMetrics.swift
//  TextViewer
//
//  Created by Codex on 4/9/26.
//

import AppKit

enum CodeEditorMetrics {
    static let defaultTextFontSize: CGFloat = 14
    static let minimumTextFontSize: CGFloat = 11
    static let maximumTextFontSize: CGFloat = 28
    static let gutterWidth: CGFloat = 58
    static let horizontalInset: CGFloat = 10
    static let verticalInset: CGFloat = 14
    static let indentUnit = "    "

    static func textFont(size: CGFloat) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func lineNumberFont(size: CGFloat) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func lineHeight(for size: CGFloat) -> CGFloat {
        let font = textFont(size: size)
        return ceil(font.ascender - font.descender + font.leading)
    }

    static let editorBackgroundColor = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1)
    static let gutterBackgroundColor = NSColor(calibratedWhite: 0.0, alpha: 0.14)
    static let textColor = NSColor(calibratedWhite: 0.95, alpha: 1)
    static let currentLineNumberColor = NSColor.white
    static let lineNumberColor = NSColor(calibratedWhite: 0.62, alpha: 1)
    static let currentLineHighlightColor = NSColor.controlAccentColor.withAlphaComponent(0.18)
    static let currentLineFillColor = NSColor.white.withAlphaComponent(0.035)
    static let searchHighlightColor = NSColor.systemYellow.withAlphaComponent(0.22)
    static let selectedSearchHighlightColor = NSColor.systemOrange.withAlphaComponent(0.32)
}
