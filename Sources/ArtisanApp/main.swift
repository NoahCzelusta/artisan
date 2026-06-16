import AppKit
import Darwin
import Foundation

struct OpenRequest: Codable {
    let invocationID: String
    let paths: [String]
    let wait: Bool
}

struct OpenResponse: Codable {
    let ok: Bool
    let message: String
}

struct HighlightSegment {
    let text: String
    let color: NSColor
}

struct FileSnapshot: Equatable {
    let byteCount: Int
    let modifiedAt: Date?

    static func read(path: String) throws -> FileSnapshot {
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return FileSnapshot(
            byteCount: values.fileSize ?? 0,
            modifiedAt: values.contentModificationDate
        )
    }
}

enum EditorLanguage {
    case plainText
    case typeScript

    static func detect(path: String) -> EditorLanguage {
        let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch fileExtension {
        case "ts", "tsx":
            return .typeScript
        default:
            return .plainText
        }
    }
}

final class TextBuffer {
    let path: String
    private var data: Data
    private let language: EditorLanguage
    private var originalLineEnding: String
    private var originalHadFinalNewline: Bool
    private var lastKnownDiskSnapshot: FileSnapshot
    private(set) var lineStarts: [Int]
    private(set) var maxLineByteCount: Int
    private var fullyIndexed = false
    private var estimatedLineCount: Int = 1
    private var editedLines: [Int: String] = [:]
    private var lineVersions: [Int: Int] = [:]
    private var highlightCache: [Int: (version: Int, segments: [HighlightSegment])] = [:]

    init(path: String) throws {
        self.path = path
        self.language = EditorLanguage.detect(path: path)
        self.data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        self.originalLineEnding = TextBuffer.detectLineEnding(in: data)
        self.originalHadFinalNewline = data.last == 10
        self.lastKnownDiskSnapshot = try FileSnapshot.read(path: path)

        var starts = [Int]()
        starts.reserveCapacity(8192)
        starts.append(0)

        self.lineStarts = starts
        self.maxLineByteCount = 0
        rebuildIndex(limitBytes: min(data.count, 384 * 1024))
    }

    var lineCount: Int {
        max(fullyIndexed ? lineStarts.count : estimatedLineCount, 1)
    }

    var indexedLineCount: Int {
        lineStarts.count
    }

    var isFullyIndexed: Bool {
        fullyIndexed
    }

    func ensureFullyIndexed() {
        guard !fullyIndexed else { return }
        rebuildIndex(limitBytes: data.count)
    }

    func lineText(at lineIndex: Int) -> String {
        guard lineIndex >= 0, lineIndex < lineStarts.count else {
            return ""
        }

        if let editedText = editedLines[lineIndex] {
            return editedText
        }

        let start = lineStarts[lineIndex]
        var end = lineIndex + 1 < lineStarts.count ? max(start, lineStarts[lineIndex + 1] - 1) : data.count
        if end > start, data[end - 1] == 10 {
            end -= 1
        }
        if end > start, data[end - 1] == 13 {
            end -= 1
        }
        guard end > start else {
            return ""
        }

        return data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return ""
            }
            let buffer = UnsafeBufferPointer(start: base + start, count: end - start)
            return String(decoding: buffer, as: UTF8.self)
        }
    }

    func version(at lineIndex: Int) -> Int {
        lineVersions[lineIndex] ?? 0
    }

    func insert(_ text: String, atLine lineIndex: Int, column: Int) -> (line: Int, column: Int) {
        guard lineIndex >= 0, lineIndex < lineStarts.count else { return (0, 0) }
        var line = lineText(at: lineIndex)
        let safeColumn = min(max(0, column), line.count)
        let index = line.index(line.startIndex, offsetBy: safeColumn)
        line.insert(contentsOf: text, at: index)
        updateLine(lineIndex, text: line)
        return (lineIndex, safeColumn + text.count)
    }

    func insertText(_ text: String, atLine lineIndex: Int, column: Int) -> (line: Int, column: Int) {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard normalized.contains("\n") else {
            return insert(normalized, atLine: lineIndex, column: column)
        }
        guard lineIndex >= 0, lineIndex < lineStarts.count else { return (0, 0) }

        let line = lineText(at: lineIndex)
        let safeColumn = min(max(0, column), line.count)
        let splitIndex = line.index(line.startIndex, offsetBy: safeColumn)
        let prefix = String(line[..<splitIndex])
        let suffix = String(line[splitIndex...])
        let pastedLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let firstPastedLine = pastedLines.first, let lastPastedLine = pastedLines.last else {
            return (lineIndex, safeColumn)
        }

        updateLine(lineIndex, text: prefix + firstPastedLine)
        let insertedLineCount = pastedLines.count - 1
        for offset in 1...insertedLineCount {
            lineStarts.insert(0, at: lineIndex + offset)
        }
        shiftSparseStateAfterLineInsertion(at: lineIndex + 1, count: insertedLineCount)

        if insertedLineCount > 1 {
            for offset in 1..<insertedLineCount {
                updateLine(lineIndex + offset, text: pastedLines[offset])
            }
        }
        updateLine(lineIndex + insertedLineCount, text: lastPastedLine + suffix)
        highlightCache.removeAll(keepingCapacity: true)
        return (lineIndex + insertedLineCount, lastPastedLine.count)
    }

    func insertNewline(atLine lineIndex: Int, column: Int) -> (line: Int, column: Int) {
        guard lineIndex >= 0, lineIndex < lineStarts.count else { return (0, 0) }
        let line = lineText(at: lineIndex)
        let safeColumn = min(max(0, column), line.count)
        let splitIndex = line.index(line.startIndex, offsetBy: safeColumn)
        let prefix = String(line[..<splitIndex])
        let suffix = String(line[splitIndex...])

        updateLine(lineIndex, text: prefix)
        lineStarts.insert(0, at: lineIndex + 1)
        shiftSparseStateAfterLineInsertion(at: lineIndex + 1)
        editedLines[lineIndex + 1] = suffix
        lineVersions[lineIndex + 1] = 1
        highlightCache.removeAll(keepingCapacity: true)
        return (lineIndex + 1, 0)
    }

    func deleteBackward(atLine lineIndex: Int, column: Int) -> (line: Int, column: Int) {
        guard lineIndex >= 0, lineIndex < lineStarts.count else { return (0, 0) }
        if column > 0 {
            var line = lineText(at: lineIndex)
            let safeColumn = min(column, line.count)
            let end = line.index(line.startIndex, offsetBy: safeColumn)
            let start = line.index(before: end)
            line.removeSubrange(start..<end)
            updateLine(lineIndex, text: line)
            return (lineIndex, safeColumn - 1)
        }

        guard lineIndex > 0 else {
            return (lineIndex, 0)
        }

        let previous = lineText(at: lineIndex - 1)
        let current = lineText(at: lineIndex)
        updateLine(lineIndex - 1, text: previous + current)
        lineStarts.remove(at: lineIndex)
        shiftSparseStateAfterLineRemoval(at: lineIndex)
        highlightCache.removeAll(keepingCapacity: true)
        return (lineIndex - 1, previous.count)
    }

    func deleteForward(atLine lineIndex: Int, column: Int) -> (line: Int, column: Int) {
        guard lineIndex >= 0, lineIndex < lineStarts.count else { return (0, 0) }
        var line = lineText(at: lineIndex)
        let safeColumn = min(max(0, column), line.count)
        if safeColumn < line.count {
            let start = line.index(line.startIndex, offsetBy: safeColumn)
            let end = line.index(after: start)
            line.removeSubrange(start..<end)
            updateLine(lineIndex, text: line)
            return (lineIndex, safeColumn)
        }

        guard lineIndex + 1 < lineStarts.count else {
            return (lineIndex, safeColumn)
        }

        let next = lineText(at: lineIndex + 1)
        updateLine(lineIndex, text: line + next)
        lineStarts.remove(at: lineIndex + 1)
        shiftSparseStateAfterLineRemoval(at: lineIndex + 1)
        highlightCache.removeAll(keepingCapacity: true)
        return (lineIndex, safeColumn)
    }

    func saveAtomically() throws {
        let text = serializedText()
        try Data(text.utf8).write(to: URL(fileURLWithPath: path), options: .atomic)
        lastKnownDiskSnapshot = try FileSnapshot.read(path: path)
    }

    func serializedText() -> String {
        ensureFullyIndexed()
        let lines = (0..<lineCount).map { lineText(at: $0) }
        var text = lines.joined(separator: originalLineEnding)
        if originalHadFinalNewline, !text.hasSuffix(originalLineEnding) {
            text += originalLineEnding
        }
        return text
    }

    func hasExternalChanges() throws -> Bool {
        try FileSnapshot.read(path: path) != lastKnownDiskSnapshot
    }

    func reloadFromDisk() throws {
        data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        originalLineEnding = TextBuffer.detectLineEnding(in: data)
        originalHadFinalNewline = data.last == 10
        lastKnownDiskSnapshot = try FileSnapshot.read(path: path)
        lineStarts = [0]
        maxLineByteCount = 0
        fullyIndexed = false
        estimatedLineCount = 1
        editedLines.removeAll(keepingCapacity: true)
        lineVersions.removeAll(keepingCapacity: true)
        highlightCache.removeAll(keepingCapacity: true)
        rebuildIndex(limitBytes: min(data.count, 384 * 1024))
    }

    func highlightedSegments(at lineIndex: Int) -> [HighlightSegment] {
        let currentVersion = version(at: lineIndex)
        if let cached = highlightCache[lineIndex], cached.version == currentVersion {
            return cached.segments
        }

        let text = lineText(at: lineIndex)
        let segments: [HighlightSegment]
        switch language {
        case .plainText:
            segments = PlainTextHighlighter.highlight(text)
        case .typeScript:
            segments = TypeScriptHighlighter.highlight(text)
        }
        highlightCache[lineIndex] = (currentVersion, segments)
        return segments
    }

    private func updateLine(_ lineIndex: Int, text: String) {
        editedLines[lineIndex] = text
        lineVersions[lineIndex, default: 0] += 1
        maxLineByteCount = max(maxLineByteCount, text.utf8.count)
        highlightCache.removeValue(forKey: lineIndex)
    }

    private func rebuildIndex(limitBytes: Int) {
        var starts = [Int]()
        starts.reserveCapacity(max(8192, min(data.count / 64, 200_000)))
        starts.append(0)
        var currentLineStart = 0
        var longest = 0
        let scanLimit = min(limitBytes, data.count)

        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            guard let rawBase = rawBuffer.baseAddress else {
                return
            }
            let base = rawBase.assumingMemoryBound(to: UInt8.self)

            for index in 0..<scanLimit {
                if base[index] == 10 {
                    var end = index
                    if end > currentLineStart, base[end - 1] == 13 {
                        end -= 1
                    }
                    longest = max(longest, end - currentLineStart)
                    let next = index + 1
                    if next < data.count {
                        starts.append(next)
                    }
                    currentLineStart = next
                }
            }

            if scanLimit == data.count, data.count >= currentLineStart {
                var end = data.count
                if end > currentLineStart, base[end - 1] == 13 {
                    end -= 1
                }
                longest = max(longest, end - currentLineStart)
            }
        }

        if starts.isEmpty {
            starts.append(0)
        }

        lineStarts = starts
        maxLineByteCount = max(maxLineByteCount, longest)
        fullyIndexed = scanLimit == data.count

        if fullyIndexed {
            estimatedLineCount = lineStarts.count
        } else {
            let scannedBytes = max(scanLimit, 1)
            let linesPerByte = Double(max(lineStarts.count, 1)) / Double(scannedBytes)
            estimatedLineCount = max(lineStarts.count, Int(Double(data.count) * linesPerByte))
        }
    }

    private func shiftSparseStateAfterLineInsertion(at insertedIndex: Int, count: Int = 1) {
        guard count > 0 else { return }
        editedLines = Dictionary(uniqueKeysWithValues: editedLines.map { key, value in
            (key >= insertedIndex ? key + count : key, value)
        })
        lineVersions = Dictionary(uniqueKeysWithValues: lineVersions.map { key, value in
            (key >= insertedIndex ? key + count : key, value)
        })
    }

    private func shiftSparseStateAfterLineRemoval(at removedIndex: Int) {
        editedLines = Dictionary(uniqueKeysWithValues: editedLines.compactMap { key, value in
            if key == removedIndex { return nil }
            return (key > removedIndex ? key - 1 : key, value)
        })
        lineVersions = Dictionary(uniqueKeysWithValues: lineVersions.compactMap { key, value in
            if key == removedIndex { return nil }
            return (key > removedIndex ? key - 1 : key, value)
        })
    }

    private static func detectLineEnding(in data: Data) -> String {
        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return "\n"
            }
            for index in 0..<data.count where base[index] == 10 {
                if index > 0, base[index - 1] == 13 {
                    return "\r\n"
                }
                return "\n"
            }
            return "\n"
        }
    }
}

enum PlainTextHighlighter {
    private static let plain = NSColor.labelColor

    static func highlight(_ line: String) -> [HighlightSegment] {
        [HighlightSegment(text: line, color: plain)]
    }
}

enum TypeScriptHighlighter {
    private static let keywords: Set<String> = [
        "abstract", "as", "async", "await", "break", "case", "catch", "class", "const",
        "continue", "debugger", "declare", "default", "delete", "do", "else", "enum",
        "export", "extends", "false", "finally", "for", "from", "function", "get", "if",
        "implements", "import", "in", "infer", "instanceof", "interface", "is", "keyof",
        "let", "module", "namespace", "new", "null", "of", "private", "protected", "public",
        "readonly", "return", "satisfies", "set", "static", "super", "switch", "this",
        "throw", "true", "try", "type", "typeof", "undefined", "var", "void", "while", "yield"
    ]

    private static let plain = NSColor.labelColor
    private static let keyword = NSColor.systemBlue
    private static let string = NSColor.systemRed
    private static let number = NSColor.systemPurple
    private static let comment = NSColor.systemGreen
    private static let punctuation = NSColor.secondaryLabelColor

    static func highlight(_ line: String) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }

        var segments: [HighlightSegment] = []
        var index = line.startIndex

        func append(_ start: String.Index, _ end: String.Index, _ color: NSColor) {
            guard start < end else { return }
            segments.append(HighlightSegment(text: String(line[start..<end]), color: color))
        }

        while index < line.endIndex {
            let char = line[index]
            let next = line.index(after: index)

            if char == "/", next < line.endIndex, line[next] == "/" {
                append(index, line.endIndex, comment)
                break
            }

            if char == "\"" || char == "'" || char == "`" {
                let quote = char
                var end = next
                var escaped = false
                while end < line.endIndex {
                    let c = line[end]
                    let after = line.index(after: end)
                    if escaped {
                        escaped = false
                    } else if c == "\\" {
                        escaped = true
                    } else if c == quote {
                        end = after
                        break
                    }
                    end = after
                }
                append(index, end, string)
                index = end
                continue
            }

            if char.isNumber {
                var end = next
                while end < line.endIndex, line[end].isNumber || line[end] == "." || line[end] == "_" {
                    end = line.index(after: end)
                }
                append(index, end, number)
                index = end
                continue
            }

            if char.isLetter || char == "_" || char == "$" {
                var end = next
                while end < line.endIndex {
                    let c = line[end]
                    if c.isLetter || c.isNumber || c == "_" || c == "$" {
                        end = line.index(after: end)
                    } else {
                        break
                    }
                }
                let word = String(line[index..<end])
                append(index, end, keywords.contains(word) ? keyword : plain)
                index = end
                continue
            }

            if "{}[]().,:;+-*=<>!&|?/".contains(char) {
                append(index, next, punctuation)
            } else {
                append(index, next, plain)
            }
            index = next
        }

        return segments
    }
}

final class EditorClipView: NSClipView {
    var onBoundsChanged: ((NSRect) -> Void)?

    override var bounds: NSRect {
        didSet {
            guard bounds != oldValue else { return }
            onBoundsChanged?(bounds)
        }
    }

    override func scroll(to newOrigin: NSPoint) {
        super.scroll(to: newOrigin)
        onBoundsChanged?(bounds)
    }
}

final class FastFileView: NSView {
    private var buffer: TextBuffer
    private let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    private let lineNumberFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private let lineNumberColor = NSColor.secondaryLabelColor
    private let caretColor = NSColor.controlAccentColor
    private let lineHeight: CGFloat
    private let charWidth: CGFloat
    private let gutterWidth: CGFloat
    private let horizontalPadding: CGFloat = 12
    private var caretLine = 0
    private var caretColumn = 0
    private var attributedLineCache: [Int: (version: Int, text: NSAttributedString)] = [:]
    var onEdit: (() -> Void)?
    private(set) var drawCallCount = 0
    private(set) var indexOnDrawCount = 0
    private(set) var indexOnScrollCount = 0
    private(set) var lastRenderedNonEmptyLines = 0
    private(set) var lastRenderedRange: ClosedRange<Int>?

    init(buffer: TextBuffer) {
        self.buffer = buffer
        self.lineHeight = ceil(font.ascender - font.descender + font.leading) + 11
        self.charWidth = max(1, "W".size(withAttributes: [.font: font]).width)
        let digits = max(2, String(buffer.lineCount).count)
        self.gutterWidth = CGFloat(digits) * max(1, "8".size(withAttributes: [.font: lineNumberFont]).width) + 18

        let width = gutterWidth + horizontalPadding * 2 + CGFloat(min(buffer.maxLineByteCount, 4_000)) * charWidth
        let height = CGFloat(buffer.lineCount) * lineHeight
        super.init(frame: NSRect(x: 0, y: 0, width: max(900, width), height: max(700, height)))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        drawCallCount += 1
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()

        var visibleRect = enclosingScrollView?.contentView.bounds ?? bounds
        if ensureIndexedForVisibleRect(visibleRect) {
            visibleRect = enclosingScrollView?.contentView.bounds ?? bounds
        }
        let startLine = max(0, Int(floor(visibleRect.minY / lineHeight)) - 2)
        let endLine = min(buffer.lineCount - 1, Int(ceil(visibleRect.maxY / lineHeight)) + 2)
        guard startLine <= endLine else { return }
        lastRenderedNonEmptyLines = 0
        lastRenderedRange = startLine...endLine

        let lineNumberAttributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor
        ]
        for line in startLine...endLine {
            let y = CGFloat(line) * lineHeight
            if line == caretLine {
                NSColor.selectedTextBackgroundColor.withAlphaComponent(0.22).setFill()
                NSRect(x: 0, y: y, width: visibleRect.width, height: lineHeight).fill()
            }

            let lineNumber = "\(line + 1)" as NSString
            let lineNumberSize = lineNumber.size(withAttributes: lineNumberAttributes)
            lineNumber.draw(
                at: NSPoint(x: gutterWidth - lineNumberSize.width - 8, y: y + 2),
                withAttributes: lineNumberAttributes
            )

            drawHighlightedLine(line, atY: y)
        }

        let caretY = CGFloat(caretLine) * lineHeight
        if visibleRect.intersects(NSRect(x: 0, y: caretY, width: 1, height: lineHeight)) {
            caretColor.setFill()
            let caretX = gutterWidth + horizontalPadding + CGFloat(caretColumn) * charWidth
            NSRect(x: caretX, y: caretY + 2, width: 2, height: lineHeight - 4).fill()
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers?.lowercased() == "v" {
                pasteFromClipboard()
                return
            }
            switch event.keyCode {
            case 123:
                moveToLineStart()
            case 124:
                moveToLineEnd()
            case 125:
                moveToFileEnd()
            case 126:
                moveToFileStart()
            default:
                super.keyDown(with: event)
            }
            return
        }

        if event.modifierFlags.contains(.option) {
            switch event.keyCode {
            case 123:
                moveWordLeft()
            case 124:
                moveWordRight()
            default:
                super.keyDown(with: event)
            }
            return
        }

        switch event.keyCode {
        case 51:
            applyEdit { buffer.deleteBackward(atLine: caretLine, column: caretColumn) }
        case 117:
            applyEdit { buffer.deleteForward(atLine: caretLine, column: caretColumn) }
        case 36, 76:
            applyEdit { buffer.insertNewline(atLine: caretLine, column: caretColumn) }
        case 123:
            moveCharacterLeft()
        case 124:
            moveCharacterRight()
        case 125:
            moveLineDown()
        case 126:
            moveLineUp()
        case 121:
            movePageDown()
        case 116:
            movePageUp()
        case 115:
            moveToLineStart()
        case 119:
            moveToLineEnd()
        default:
            if let characters = event.characters, characters.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) {
                applyEdit { buffer.insert(characters, atLine: caretLine, column: caretColumn) }
            } else {
                super.keyDown(with: event)
            }
        }
    }

    private func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            return
        }
        applyEdit { buffer.insertText(text, atLine: caretLine, column: caretColumn) }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let line = Int(floor(point.y / lineHeight))
        let rawColumn = Int(round((point.x - gutterWidth - horizontalPadding) / charWidth))
        moveCaret(line: line, column: rawColumn)
        displayVisibleRect()
    }

    private func drawHighlightedLine(_ line: Int, atY y: CGFloat) {
        if !buffer.lineText(at: line).isEmpty {
            lastRenderedNonEmptyLines += 1
        }
        let version = buffer.version(at: line)
        let attributed: NSAttributedString
        if let cached = attributedLineCache[line], cached.version == version {
            attributed = cached.text
        } else {
            let mutable = NSMutableAttributedString()
            for segment in buffer.highlightedSegments(at: line) {
                mutable.append(NSAttributedString(
                    string: segment.text,
                    attributes: [
                        .font: font,
                        .foregroundColor: segment.color
                    ]
                ))
            }
            attributed = mutable
            attributedLineCache[line] = (version, attributed)
        }
        attributed.draw(at: NSPoint(x: gutterWidth + horizontalPadding, y: y + 1))
    }

    private func visibleLineCount() -> Int {
        let height = enclosingScrollView?.contentView.bounds.height ?? 700
        return max(1, Int(height / lineHeight))
    }

    private func moveCharacterLeft() {
        if caretColumn > 0 {
            moveCaret(line: caretLine, column: caretColumn - 1)
        } else if caretLine > 0 {
            let previousLine = caretLine - 1
            moveCaret(line: previousLine, column: buffer.lineText(at: previousLine).count)
        }
    }

    private func moveCharacterRight() {
        let lineLength = buffer.lineText(at: caretLine).count
        if caretColumn < lineLength {
            moveCaret(line: caretLine, column: caretColumn + 1)
        } else if caretLine + 1 < buffer.lineCount {
            moveCaret(line: caretLine + 1, column: 0)
        }
    }

    private func moveLineUp() {
        moveCaret(line: caretLine - 1, column: caretColumn)
    }

    private func moveLineDown() {
        moveCaret(line: caretLine + 1, column: caretColumn)
    }

    private func movePageUp() {
        moveCaret(line: caretLine - visibleLineCount(), column: caretColumn)
    }

    private func movePageDown() {
        moveCaret(line: caretLine + visibleLineCount(), column: caretColumn)
    }

    private func moveToLineStart() {
        moveCaret(line: caretLine, column: 0)
    }

    private func moveToLineEnd() {
        moveCaret(line: caretLine, column: buffer.lineText(at: caretLine).count)
    }

    private func moveToFileStart() {
        moveCaret(line: 0, column: 0)
    }

    private func moveToFileEnd() {
        let lastLine = buffer.lineCount - 1
        moveCaret(line: lastLine, column: buffer.lineText(at: lastLine).count)
    }

    private func moveWordLeft() {
        if caretColumn == 0 {
            guard caretLine > 0 else { return }
            let previousLine = caretLine - 1
            moveCaret(line: previousLine, column: buffer.lineText(at: previousLine).count)
            return
        }

        let line = buffer.lineText(at: caretLine)
        let target = wordBoundaryLeft(in: line, from: caretColumn)
        moveCaret(line: caretLine, column: target)
    }

    private func moveWordRight() {
        let line = buffer.lineText(at: caretLine)
        if caretColumn >= line.count {
            guard caretLine + 1 < buffer.lineCount else { return }
            moveCaret(line: caretLine + 1, column: 0)
            return
        }

        let target = wordBoundaryRight(in: line, from: caretColumn)
        moveCaret(line: caretLine, column: target)
    }

    private func wordBoundaryLeft(in line: String, from column: Int) -> Int {
        let characters = Array(line)
        var index = min(max(0, column), characters.count)

        while index > 0, !isWordCharacter(characters[index - 1]) {
            index -= 1
        }
        while index > 0, isWordCharacter(characters[index - 1]) {
            index -= 1
        }

        return index
    }

    private func wordBoundaryRight(in line: String, from column: Int) -> Int {
        let characters = Array(line)
        var index = min(max(0, column), characters.count)

        while index < characters.count, !isWordCharacter(characters[index]) {
            index += 1
        }
        while index < characters.count, isWordCharacter(characters[index]) {
            index += 1
        }

        return index
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private func applyEdit(_ operation: () -> (line: Int, column: Int)) {
        let oldLine = caretLine
        let result = operation()
        caretLine = result.line
        caretColumn = result.column
        onEdit?()
        attributedLineCache.removeValue(forKey: oldLine)
        attributedLineCache.removeValue(forKey: caretLine)
        resizeForBuffer()
        scrollLineToVisible(caretLine)
        markLinesDirty(oldLine, caretLine)
    }

    func save() throws {
        try buffer.saveAtomically()
    }

    func hasExternalChanges() throws -> Bool {
        try buffer.hasExternalChanges()
    }

    func reloadFromDisk() throws {
        try buffer.reloadFromDisk()
        caretLine = 0
        caretColumn = 0
        attributedLineCache.removeAll(keepingCapacity: true)
        resizeForBuffer()
        setNeedsDisplay(bounds)
        displayIfNeeded()
    }

    private func moveCaret(line: Int, column: Int) {
        let oldLine = caretLine
        if line >= buffer.indexedLineCount && !buffer.isFullyIndexed {
            buffer.ensureFullyIndexed()
            resizeForBuffer()
        }
        caretLine = min(max(0, line), buffer.lineCount - 1)
        caretColumn = min(max(0, column), buffer.lineText(at: caretLine).count)
        scrollLineToVisible(caretLine)
        markLinesDirty(oldLine, caretLine)
    }

    func benchmarkNavigation(iterations: Int) -> Double {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        let start = DispatchTime.now().uptimeNanoseconds
        for index in 0..<iterations {
            moveCaret(line: (index * 97) % buffer.lineCount, column: 0)
            displayVisibleRect()
        }
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    func attach(to scrollView: NSScrollView) {
        guard let clipView = scrollView.contentView as? EditorClipView else {
            return
        }

        clipView.onBoundsChanged = { [weak self] bounds in
            self?.handleClipViewBoundsChanged(bounds)
        }
    }

    func benchmarkFullIndex() -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    func benchmarkScroll(steps: Int) -> Double {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        guard let scrollView = enclosingScrollView else { return 0 }
        let maxY = max(0, bounds.height - scrollView.contentView.bounds.height)
        let start = DispatchTime.now().uptimeNanoseconds

        for step in 0..<steps {
            let fraction = steps <= 1 ? 0 : CGFloat(step) / CGFloat(steps - 1)
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY * fraction))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            displayVisibleRect()
        }

        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    func benchmarkImmediateBottomRender() -> (ms: Double, nonEmptyLines: Int, renderedRange: String, indexOnDrawCount: Int, indexOnScrollCount: Int) {
        guard let scrollView = enclosingScrollView else {
            return (0, 0, "none", indexOnDrawCount, indexOnScrollCount)
        }

        let maxY = max(0, bounds.height - scrollView.contentView.bounds.height)
        let start = DispatchTime.now().uptimeNanoseconds
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        displayVisibleRect()
        let elapsedMS = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        let range = lastRenderedRange.map { "\($0.lowerBound)...\($0.upperBound)" } ?? "none"
        return (elapsedMS, lastRenderedNonEmptyLines, range, indexOnDrawCount, indexOnScrollCount)
    }

    func benchmarkEditing(iterations: Int) -> (insertMS: Double, deleteMS: Double, newlineMS: Double, pasteMS: Double, bottomEditMS: Double) {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        moveCaret(line: min(buffer.lineCount / 2, buffer.lineCount - 1), column: 8)
        let insertStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            applyEdit { buffer.insert("x", atLine: caretLine, column: caretColumn) }
            displayVisibleRect()
        }
        let insertMS = Double(DispatchTime.now().uptimeNanoseconds - insertStart) / 1_000_000

        let deleteStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            applyEdit { buffer.deleteBackward(atLine: caretLine, column: caretColumn) }
            displayVisibleRect()
        }
        let deleteMS = Double(DispatchTime.now().uptimeNanoseconds - deleteStart) / 1_000_000

        let newlineStart = DispatchTime.now().uptimeNanoseconds
        for index in 0..<max(1, iterations / 10) {
            moveCaret(line: min(buffer.lineCount - 1, index * 3), column: 8)
            applyEdit { buffer.insertNewline(atLine: caretLine, column: caretColumn) }
            displayVisibleRect()
        }
        let newlineMS = Double(DispatchTime.now().uptimeNanoseconds - newlineStart) / 1_000_000

        moveCaret(line: min(buffer.lineCount / 2, buffer.lineCount - 1), column: 4)
        let pasteText = String(repeating: "p", count: 1024)
        let pasteStart = DispatchTime.now().uptimeNanoseconds
        applyEdit { buffer.insert(pasteText, atLine: caretLine, column: caretColumn) }
        displayVisibleRect()
        let pasteMS = Double(DispatchTime.now().uptimeNanoseconds - pasteStart) / 1_000_000

        moveCaret(line: max(0, buffer.lineCount - 1), column: 0)
        displayVisibleRect()
        let bottomEditStart = DispatchTime.now().uptimeNanoseconds
        applyEdit { buffer.insert("z", atLine: caretLine, column: caretColumn) }
        applyEdit { buffer.deleteBackward(atLine: caretLine, column: caretColumn) }
        displayVisibleRect()
        let bottomEditMS = Double(DispatchTime.now().uptimeNanoseconds - bottomEditStart) / 1_000_000

        return (insertMS, deleteMS, newlineMS, pasteMS, bottomEditMS)
    }

    func benchmarkKeyboardNavigation() -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        var failures: [String] = []

        func expect(_ label: String, line expectedLine: Int, column expectedColumn: Int) {
            if caretLine != expectedLine || caretColumn != expectedColumn {
                failures.append("\(label): expected \(expectedLine):\(expectedColumn), got \(caretLine):\(caretColumn)")
            }
        }

        moveToFileStart()
        expect("file start", line: 0, column: 0)

        moveCharacterRight()
        expect("character right", line: 0, column: 1)

        moveCharacterLeft()
        expect("character left", line: 0, column: 0)

        moveToLineEnd()
        expect("line end", line: 0, column: 16)

        moveToLineStart()
        expect("line start", line: 0, column: 0)

        moveWordRight()
        expect("word right alpha", line: 0, column: 5)

        moveWordRight()
        expect("word right beta", line: 0, column: 10)

        moveWordRight()
        expect("word right gamma", line: 0, column: 16)

        moveWordLeft()
        expect("word left gamma", line: 0, column: 11)

        moveWordLeft()
        expect("word left beta", line: 0, column: 6)

        moveLineDown()
        expect("line down preserves column", line: 1, column: 6)

        moveToLineEnd()
        expect("second line end", line: 1, column: 19)

        moveCharacterRight()
        expect("character right across newline", line: 2, column: 0)

        moveToFileEnd()
        expect("file end", line: 2, column: 9)

        moveCharacterRight()
        expect("character right at eof", line: 2, column: 9)

        moveToFileStart()
        movePageDown()
        expect("page down clamps to file end line", line: 2, column: 0)

        movePageUp()
        expect("page up clamps to file start line", line: 0, column: 0)

        return failures
    }

    func benchmarkHighlighting(iterations: Int) -> Double {
        buffer.ensureFullyIndexed()
        let start = DispatchTime.now().uptimeNanoseconds
        for index in 0..<iterations {
            _ = buffer.highlightedSegments(at: (index * 37) % buffer.lineCount)
        }
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }

    private func scrollLineToVisible(_ line: Int) {
        guard let scrollView = enclosingScrollView else { return }
        let visible = scrollView.contentView.bounds
        let lineRect = NSRect(x: 0, y: CGFloat(line) * lineHeight, width: bounds.width, height: lineHeight)

        if lineRect.minY < visible.minY {
            scrollView.contentView.scroll(to: NSPoint(x: visible.minX, y: lineRect.minY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        } else if lineRect.maxY > visible.maxY {
            scrollView.contentView.scroll(to: NSPoint(x: visible.minX, y: lineRect.maxY - visible.height))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    private func markLinesDirty(_ lines: Int...) {
        for line in lines {
            let rect = NSRect(x: 0, y: CGFloat(line) * lineHeight, width: bounds.width, height: lineHeight)
            setNeedsDisplay(rect)
        }
    }

    private func displayVisibleRect() {
        let visibleRect = enclosingScrollView?.contentView.bounds ?? bounds
        setNeedsDisplay(visibleRect)
        displayIfNeeded()
    }

    private func ensureIndexedForVisibleRect(_ visibleRect: NSRect) -> Bool {
        let requestedEndLine = Int(ceil(visibleRect.maxY / lineHeight)) + 2
        guard requestedEndLine >= buffer.indexedLineCount, !buffer.isFullyIndexed else {
            return false
        }

        buffer.ensureFullyIndexed()
        resizeForBuffer()
        indexOnDrawCount += 1
        return true
    }

    private func handleClipViewBoundsChanged(_ visibleRect: NSRect) {
        let requestedEndLine = Int(ceil(visibleRect.maxY / lineHeight)) + 2
        guard requestedEndLine >= buffer.indexedLineCount, !buffer.isFullyIndexed else {
            return
        }

        buffer.ensureFullyIndexed()
        resizeForBuffer()
        indexOnScrollCount += 1
        setNeedsDisplay(visibleRect)
    }

    private func resizeForBuffer() {
        let width = gutterWidth + horizontalPadding * 2 + CGFloat(min(buffer.maxLineByteCount, 4_000)) * charWidth
        let height = CGFloat(buffer.lineCount) * lineHeight
        frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: max(900, width), height: max(700, height))
    }
}

final class TabDocument {
    let path: String
    let displayName: String
    let item: NSTabViewItem
    let fileView: FastFileView
    var waitingInvocations = Set<String>()
    var isDirty = false

    init(path: String, item: NSTabViewItem, fileView: FastFileView) {
        self.path = path
        self.displayName = URL(fileURLWithPath: path).lastPathComponent
        self.item = item
        self.fileView = fileView
    }
}

final class PendingInvocation {
    let id: String
    let paths: Set<String>
    var remainingPaths: Set<String>
    let fd: Int32

    init(id: String, paths: Set<String>, fd: Int32) {
        self.id = id
        self.paths = paths
        self.remainingPaths = paths
        self.fd = fd
    }
}

enum DiskChangeDecision {
    case reload
    case saveAnyway
    case cancel
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSTabViewDelegate, NSWindowDelegate {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    private let tabView = NSTabView()
    private var documentsByPath: [String: TabDocument] = [:]
    private var documentsByItem: [NSTabViewItem: TabDocument] = [:]
    private var pendingInvocations: [String: PendingInvocation] = [:]
    private var socketServer: SocketServer?
    private var benchmarkPath: String?
    private var isRunningBenchmark = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        configureWindow()

        socketServer = SocketServer { [weak self] request, fd in
            Task { @MainActor in
                self?.handle(request: request, responseFD: fd)
            }
        }
        socketServer?.start()

        let args = Array(CommandLine.arguments.dropFirst())
        if let benchmarkIndex = args.firstIndex(of: "--benchmark-scroll"),
           args.indices.contains(benchmarkIndex + 1) {
            benchmarkPath = URL(fileURLWithPath: args[benchmarkIndex + 1]).standardizedFileURL.path
        }

        let startupPaths: [String]
        if benchmarkPath != nil {
            startupPaths = []
        } else {
            startupPaths = args
                .filter { !$0.hasPrefix("--") }
                .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        }

        if !startupPaths.isEmpty {
            _ = open(paths: startupPaths, invocationID: nil)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let benchmarkPath {
            runBenchmark(path: benchmarkPath)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isRunningBenchmark {
            return .terminateNow
        }
        return confirmCloseDirtyDocuments()
            ? NSApplication.TerminateReply.terminateNow
            : NSApplication.TerminateReply.terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        for invocation in pendingInvocations.values {
            send(OpenResponse(ok: true, message: "app quit"), to: invocation.fd, closeAfterWrite: true)
        }
        socketServer?.stop()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmCloseDirtyDocuments()
    }

    @objc private func saveDocument(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }
        _ = save(document: document)
    }

    @objc private func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                _ = self?.open(paths: panel.urls.map(\.standardizedFileURL.path), invocationID: nil)
            }
        }
    }

    @objc private func closeCurrentTab(_ sender: Any?) {
        guard let item = tabView.selectedTabViewItem else { return }
        close(item: item)
    }

    func tabView(_ tabView: NSTabView, willClose tabViewItem: NSTabViewItem) {
        close(item: tabViewItem)
    }

    private func configureWindow() {
        window.title = "Artisan"
        window.isRestorable = false
        window.delegate = self
        window.center()
        tabView.frame = window.contentView?.bounds ?? .zero
        tabView.autoresizingMask = [.width, .height]
        tabView.delegate = self
        window.contentView = tabView
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let fileMenuItem = NSMenuItem()

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Artisan", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let fileMenu = NSMenu(title: "File")
        let openItem = fileMenu.addItem(withTitle: "Open...", action: #selector(openDocument(_:)), keyEquivalent: "o")
        openItem.target = self
        let saveItem = fileMenu.addItem(withTitle: "Save", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        saveItem.target = self
        let closeTabItem = fileMenu.addItem(withTitle: "Close Tab", action: #selector(closeCurrentTab(_:)), keyEquivalent: "w")
        closeTabItem.target = self
        fileMenuItem.submenu = fileMenu

        NSApp.mainMenu = mainMenu
    }

    private func handle(request: OpenRequest, responseFD fd: Int32) {
        let opened = open(paths: request.paths, invocationID: request.invocationID)
        guard opened.ok else {
            send(opened, to: fd, closeAfterWrite: true)
            return
        }

        if request.wait {
            pendingInvocations[request.invocationID] = PendingInvocation(
                id: request.invocationID,
                paths: Set(request.paths),
                fd: fd
            )
            send(OpenResponse(ok: true, message: "opened; waiting for tabs to close"), to: fd, closeAfterWrite: false)
        } else {
            send(OpenResponse(ok: true, message: "opened \(request.paths.count) file(s)"), to: fd, closeAfterWrite: true)
        }
    }

    private func open(paths: [String], invocationID: String?) -> OpenResponse {
        var selectedDocument: TabDocument?

        for path in paths {
            if let existing = documentsByPath[path] {
                if let invocationID {
                    existing.waitingInvocations.insert(invocationID)
                }
                selectedDocument = existing
                continue
            }

            do {
                let start = DispatchTime.now().uptimeNanoseconds
                let document = try makeDocument(path: path)
                let elapsedMS = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                if let invocationID {
                    document.waitingInvocations.insert(invocationID)
                }
                documentsByPath[path] = document
                documentsByItem[document.item] = document
                tabView.addTabViewItem(document.item)
                selectedDocument = document
                fputs(String(format: "ArtisanApp: opened %@ in %.2fms\n", path, elapsedMS), stderr)
            } catch {
                return OpenResponse(ok: false, message: "could not open \(path): \(error)")
            }
        }

        if let selectedDocument {
            tabView.selectTabViewItem(selectedDocument.item)
            window.makeFirstResponder(selectedDocument.fileView)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return OpenResponse(ok: true, message: "opened")
    }

    private func runBenchmark(path: String) {
        isRunningBenchmark = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let openStart = DispatchTime.now().uptimeNanoseconds
            let response = self.open(paths: [path], invocationID: nil)
            let openMS = Double(DispatchTime.now().uptimeNanoseconds - openStart) / 1_000_000

            guard response.ok,
                  let document = self.documentsByPath[path]
            else {
                fputs("benchmark error: \(response.message)\n", stderr)
                NSApp.terminate(nil)
                return
            }

            self.window.layoutIfNeeded()
            document.fileView.displayIfNeeded()
            let bottomRender = document.fileView.benchmarkImmediateBottomRender()
            let fullIndexMS = document.fileView.benchmarkFullIndex()
            let scrollMS = document.fileView.benchmarkScroll(steps: 240)
            let navMS = document.fileView.benchmarkNavigation(iterations: 1_000)
            let highlightMS = document.fileView.benchmarkHighlighting(iterations: 1_000)
            let edit = document.fileView.benchmarkEditing(iterations: 100)

            print(String(format: "benchmark.open_ms=%.2f", openMS))
            print(String(format: "benchmark.immediate_bottom_render_ms=%.2f", bottomRender.ms))
            print("benchmark.immediate_bottom_non_empty_lines=\(bottomRender.nonEmptyLines)")
            print("benchmark.immediate_bottom_rendered_range=\(bottomRender.renderedRange)")
            print("benchmark.index_on_draw_count=\(bottomRender.indexOnDrawCount)")
            print("benchmark.index_on_scroll_count=\(bottomRender.indexOnScrollCount)")
            print(String(format: "benchmark.full_index_ms=%.2f", fullIndexMS))
            print(String(format: "benchmark.scroll_240_steps_ms=%.2f", scrollMS))
            print(String(format: "benchmark.scroll_avg_step_ms=%.4f", scrollMS / 240))
            print(String(format: "benchmark.navigation_1000_moves_ms=%.2f", navMS))
            print(String(format: "benchmark.navigation_avg_move_ms=%.4f", navMS / 1_000))
            print("benchmark.draw_calls=\(document.fileView.drawCallCount)")
            print(String(format: "benchmark.highlight_1000_lines_ms=%.2f", highlightMS))
            print(String(format: "benchmark.highlight_avg_line_ms=%.4f", highlightMS / 1_000))
            print(String(format: "benchmark.insert_100_chars_ms=%.2f", edit.insertMS))
            print(String(format: "benchmark.insert_avg_char_ms=%.4f", edit.insertMS / 100))
            print(String(format: "benchmark.delete_100_chars_ms=%.2f", edit.deleteMS))
            print(String(format: "benchmark.delete_avg_char_ms=%.4f", edit.deleteMS / 100))
            print(String(format: "benchmark.newline_10_inserts_ms=%.2f", edit.newlineMS))
            print(String(format: "benchmark.newline_avg_insert_ms=%.4f", edit.newlineMS / 10))
            print(String(format: "benchmark.paste_1kb_ms=%.2f", edit.pasteMS))
            print(String(format: "benchmark.bottom_insert_delete_ms=%.2f", edit.bottomEditMS))
            NSApp.terminate(nil)
        }
    }

    private func makeDocument(path: String) throws -> TabDocument {
        let buffer = try TextBuffer(path: path)
        let fileView = FastFileView(buffer: buffer)

        let scrollView = NSScrollView()
        scrollView.contentView = EditorClipView(frame: scrollView.contentView.frame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.documentView = fileView
        fileView.attach(to: scrollView)

        let item = NSTabViewItem(identifier: path)
        item.view = scrollView

        let document = TabDocument(path: path, item: item, fileView: fileView)
        updateTabLabel(document)
        fileView.onEdit = { [weak self, weak document] in
            guard let document else { return }
            self?.markDirty(document)
        }
        return document
    }

    private func selectedDocument() -> TabDocument? {
        guard let item = tabView.selectedTabViewItem else { return nil }
        return documentsByItem[item]
    }

    private func markDirty(_ document: TabDocument) {
        guard !document.isDirty else { return }
        document.isDirty = true
        updateTabLabel(document)
    }

    private func updateTabLabel(_ document: TabDocument) {
        document.item.label = document.isDirty ? "\(document.displayName) *" : document.displayName
    }

    private func save(document: TabDocument) -> Bool {
        do {
            if try document.fileView.hasExternalChanges() {
                switch confirmDiskChange(document: document) {
                case .reload:
                    try document.fileView.reloadFromDisk()
                    document.isDirty = false
                    updateTabLabel(document)
                    return false
                case .saveAnyway:
                    break
                case .cancel:
                    return false
                }
            }

            try document.fileView.save()
            document.isDirty = false
            updateTabLabel(document)
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not save \(document.displayName)"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return false
        }
    }

    private func confirmDiskChange(document: TabDocument) -> DiskChangeDecision {
        let alert = NSAlert()
        alert.messageText = "\(document.displayName) changed on disk"
        alert.informativeText = "Reload the file, overwrite the disk version with your changes, or cancel the save."
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Save Anyway")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .reload
        case .alertSecondButtonReturn:
            return .saveAnyway
        default:
            return .cancel
        }
    }

    private func confirmCloseDirtyDocuments() -> Bool {
        for document in documentsByPath.values where document.isDirty {
            guard confirmClose(document: document) else {
                return false
            }
        }
        return true
    }

    private func confirmClose(document: TabDocument) -> Bool {
        guard document.isDirty else { return true }

        let alert = NSAlert()
        alert.messageText = "Save changes to \(document.displayName)?"
        alert.informativeText = "Your changes will be lost if you do not save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return save(document: document)
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func close(item: NSTabViewItem) {
        guard let document = documentsByItem[item] else { return }
        guard confirmClose(document: document) else { return }

        tabView.removeTabViewItem(item)
        documentsByItem.removeValue(forKey: item)
        documentsByPath.removeValue(forKey: document.path)

        let affectedInvocationIDs = Set(document.waitingInvocations).union(
            pendingInvocations.values.compactMap { invocation in
                invocation.remainingPaths.contains(document.path) ? invocation.id : nil
            }
        )

        for invocationID in affectedInvocationIDs {
            markClosed(path: document.path, for: invocationID)
        }
    }

    private func markClosed(path: String, for invocationID: String) {
        guard let invocation = pendingInvocations[invocationID] else { return }
        invocation.remainingPaths.remove(path)
        guard invocation.remainingPaths.isEmpty else { return }

        pendingInvocations.removeValue(forKey: invocationID)
        send(OpenResponse(ok: true, message: "closed \(invocation.paths.count) file(s)"), to: invocation.fd, closeAfterWrite: true)
    }

    private func send(_ response: OpenResponse, to fd: Int32, closeAfterWrite: Bool) {
        do {
            let data = try JSONEncoder().encode(response)
            _ = data.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, data.count) }
            _ = "\n".utf8CString.withUnsafeBufferPointer { buffer in
                Darwin.write(fd, buffer.baseAddress, 1)
            }
        } catch {
            fputs("ArtisanApp: failed to encode response: \(error)\n", stderr)
        }

        if closeAfterWrite {
            Darwin.close(fd)
        }
    }
}

final class SocketServer {
    private let socketPath = "/tmp/artisan-\(getuid()).sock"
    private let queue = DispatchQueue(label: "artisan.prototype.socket")
    private var listenerFD: Int32 = -1
    private let handler: @Sendable (OpenRequest, Int32) -> Void

    init(handler: @escaping @Sendable (OpenRequest, Int32) -> Void) {
        self.handler = handler
    }

    func start() {
        queue.async {
            self.run()
        }
    }

    func stop() {
        if listenerFD >= 0 {
            Darwin.close(listenerFD)
        }
        unlink(socketPath)
    }

    private func run() {
        unlink(socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            perror("socket")
            return
        }
        listenerFD = fd

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { rawBuffer in
            for index in rawBuffer.indices {
                rawBuffer[index] = 0
            }
            for (index, byte) in socketPath.utf8.enumerated() {
                rawBuffer[index] = byte
            }
        }

        let bindStatus = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindStatus == 0 else {
            perror("bind")
            Darwin.close(fd)
            return
        }

        guard listen(fd, 16) == 0 else {
            perror("listen")
            Darwin.close(fd)
            return
        }

        while true {
            let connectionFD = accept(fd, nil, nil)
            if connectionFD < 0 {
                return
            }
            handle(connectionFD)
        }
    }

    private func handle(_ fd: Int32) {
        var bytes: [UInt8] = []
        var byte: UInt8 = 0

        while true {
            let count = Darwin.read(fd, &byte, 1)
            if count <= 0 {
                Darwin.close(fd)
                return
            }
            if byte == 10 {
                break
            }
            bytes.append(byte)
        }

        guard let request = try? JSONDecoder().decode(OpenRequest.self, from: Data(bytes)) else {
            let response = OpenResponse(ok: false, message: "invalid request")
            if let data = try? JSONEncoder().encode(response) {
                _ = data.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, data.count) }
                _ = "\n".utf8CString.withUnsafeBufferPointer { buffer in
                    Darwin.write(fd, buffer.baseAddress, 1)
                }
            }
            Darwin.close(fd)
            return
        }

        handler(request, fd)
    }
}

func runHighlightModeBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-highlight-mode"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        let buffer = try TextBuffer(path: path)
        buffer.ensureFullyIndexed()

        let sampleLines = min(buffer.lineCount, 1_000)
        var totalSegments = 0
        var multiSegmentLines = 0

        for lineIndex in 0..<sampleLines {
            let segments = buffer.highlightedSegments(at: lineIndex)
            totalSegments += segments.count
            if segments.count > 1 {
                multiSegmentLines += 1
            }
        }

        print("benchmark.highlight_sample_lines=\(sampleLines)")
        print("benchmark.highlight_total_segments=\(totalSegments)")
        print("benchmark.highlight_multi_segment_lines=\(multiSegmentLines)")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runEditOperationsBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-edit-operations"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    func assertEqual(_ actual: String, _ expected: String, _ message: String) {
        guard actual != expected else { return }
        fputs("benchmark error: \(message): expected \(expected.debugDescription), got \(actual.debugDescription)\n", stderr)
        exit(1)
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        let buffer = try TextBuffer(path: path)
        var caret = buffer.insertText("!", atLine: 0, column: 5)
        assertEqual(buffer.lineText(at: 0), "alpha!", "insert character")

        caret = buffer.deleteBackward(atLine: caret.line, column: caret.column)
        assertEqual(buffer.lineText(at: 0), "alpha", "backspace character")

        caret = buffer.deleteForward(atLine: 1, column: 0)
        assertEqual(buffer.lineText(at: 1), "ravo", "delete forward character")

        caret = buffer.insertNewline(atLine: caret.line, column: 2)
        assertEqual(buffer.lineText(at: 1), "ra", "newline prefix")
        assertEqual(buffer.lineText(at: 2), "vo", "newline suffix")

        caret = buffer.insertText("PASTE\nTEXT", atLine: caret.line, column: caret.column)
        assertEqual(buffer.lineText(at: 2), "PASTE", "paste first line")
        assertEqual(buffer.lineText(at: 3), "TEXTvo", "paste second line")

        print("benchmark.edit_final_line=\(caret.line)")
        print("benchmark.edit_final_column=\(caret.column)")
        print("benchmark.edit_operations=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runSaveOperationsBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-save-operations"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let directory = URL(fileURLWithPath: args[modeIndex + 1], isDirectory: true).standardizedFileURL
    do {
        let lfPath = directory.appendingPathComponent("lf-final.txt").path
        let lfBuffer = try TextBuffer(path: lfPath)
        _ = lfBuffer.insertText("!", atLine: 0, column: 5)
        try lfBuffer.saveAtomically()

        let crlfPath = directory.appendingPathComponent("crlf-final.txt").path
        let crlfBuffer = try TextBuffer(path: crlfPath)
        _ = crlfBuffer.insertText("!", atLine: 0, column: 3)
        try crlfBuffer.saveAtomically()

        let noFinalPath = directory.appendingPathComponent("no-final.txt").path
        let noFinalBuffer = try TextBuffer(path: noFinalPath)
        _ = noFinalBuffer.insertText("!", atLine: 0, column: 4)
        try noFinalBuffer.saveAtomically()

        print("benchmark.save_operations=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runDiskChangeSaveBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-disk-change-save"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    func assertEqual(_ actual: String, _ expected: String, _ message: String) {
        guard actual != expected else { return }
        fputs("benchmark error: \(message): expected \(expected.debugDescription), got \(actual.debugDescription)\n", stderr)
        exit(1)
    }

    let directory = URL(fileURLWithPath: args[modeIndex + 1], isDirectory: true).standardizedFileURL
    do {
        let cancelURL = directory.appendingPathComponent("cancel.txt")
        let cancelBuffer = try TextBuffer(path: cancelURL.path)
        _ = cancelBuffer.insertText("local!", atLine: 0, column: 0)
        try Data("external\n".utf8).write(to: cancelURL, options: .atomic)
        guard try cancelBuffer.hasExternalChanges() else {
            fputs("benchmark error: cancel branch did not detect external change\n", stderr)
            exit(1)
        }
        assertEqual(cancelBuffer.serializedText(), "local!original\n", "cancel branch keeps local buffer")

        let reloadURL = directory.appendingPathComponent("reload.txt")
        let reloadBuffer = try TextBuffer(path: reloadURL.path)
        _ = reloadBuffer.insertText("local!", atLine: 0, column: 0)
        try Data("external\n".utf8).write(to: reloadURL, options: .atomic)
        guard try reloadBuffer.hasExternalChanges() else {
            fputs("benchmark error: reload branch did not detect external change\n", stderr)
            exit(1)
        }
        try reloadBuffer.reloadFromDisk()
        assertEqual(reloadBuffer.lineText(at: 0), "external", "reload branch updates buffer from disk")

        let saveAnywayURL = directory.appendingPathComponent("save-anyway.txt")
        let saveAnywayBuffer = try TextBuffer(path: saveAnywayURL.path)
        _ = saveAnywayBuffer.insertText("local!", atLine: 0, column: 0)
        try Data("external\n".utf8).write(to: saveAnywayURL, options: .atomic)
        guard try saveAnywayBuffer.hasExternalChanges() else {
            fputs("benchmark error: save-anyway branch did not detect external change\n", stderr)
            exit(1)
        }
        try saveAnywayBuffer.saveAtomically()
        assertEqual(try String(contentsOf: saveAnywayURL, encoding: .utf8), "local!original\n", "save-anyway branch overwrites disk")
        guard try !saveAnywayBuffer.hasExternalChanges() else {
            fputs("benchmark error: save-anyway branch did not update snapshot\n", stderr)
            exit(1)
        }

        print("benchmark.disk_change_save=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runKeyboardNavigationBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-keyboard-navigation"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        let buffer = try TextBuffer(path: path)
        let fileView = FastFileView(buffer: buffer)
        let failures = fileView.benchmarkKeyboardNavigation()
        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.keyboard_navigation=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

runHighlightModeBenchmarkIfRequested()
runEditOperationsBenchmarkIfRequested()
runSaveOperationsBenchmarkIfRequested()
runDiskChangeSaveBenchmarkIfRequested()
runKeyboardNavigationBenchmarkIfRequested()

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.run()
