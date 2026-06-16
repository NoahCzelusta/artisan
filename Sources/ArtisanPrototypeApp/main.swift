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

final class TextBuffer {
    let path: String
    let data: Data
    private(set) var lineStarts: [Int]
    private(set) var maxLineByteCount: Int
    private var fullyIndexed = false
    private var estimatedLineCount: Int = 1
    private var editedLines: [Int: String] = [:]
    private var lineVersions: [Int: Int] = [:]
    private var highlightCache: [Int: (version: Int, segments: [HighlightSegment])] = [:]

    init(path: String) throws {
        self.path = path
        self.data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])

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

    func highlightedSegments(at lineIndex: Int) -> [HighlightSegment] {
        let currentVersion = version(at: lineIndex)
        if let cached = highlightCache[lineIndex], cached.version == currentVersion {
            return cached.segments
        }

        let segments = TypeScriptHighlighter.highlight(lineText(at: lineIndex))
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

    private func shiftSparseStateAfterLineInsertion(at insertedIndex: Int) {
        editedLines = Dictionary(uniqueKeysWithValues: editedLines.map { key, value in
            (key >= insertedIndex ? key + 1 : key, value)
        })
        lineVersions = Dictionary(uniqueKeysWithValues: lineVersions.map { key, value in
            (key >= insertedIndex ? key + 1 : key, value)
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
    private let buffer: TextBuffer
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
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 51:
            applyEdit { buffer.deleteBackward(atLine: caretLine, column: caretColumn) }
        case 36, 76:
            applyEdit { buffer.insertNewline(atLine: caretLine, column: caretColumn) }
        case 123:
            moveCaret(line: caretLine, column: caretColumn - 1)
        case 124:
            moveCaret(line: caretLine, column: caretColumn + 1)
        case 125:
            moveCaret(line: caretLine + 1, column: caretColumn)
        case 126:
            moveCaret(line: caretLine - 1, column: caretColumn)
        case 121:
            moveCaret(line: caretLine + visibleLineCount(), column: caretColumn)
        case 116:
            moveCaret(line: caretLine - visibleLineCount(), column: caretColumn)
        case 115:
            moveCaret(line: 0, column: 0)
        case 119:
            moveCaret(line: buffer.lineCount - 1, column: 0)
        default:
            if let characters = event.characters, characters.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) {
                applyEdit { buffer.insert(characters, atLine: caretLine, column: caretColumn) }
            } else {
                super.keyDown(with: event)
            }
        }
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

    private func applyEdit(_ operation: () -> (line: Int, column: Int)) {
        let oldLine = caretLine
        let result = operation()
        caretLine = result.line
        caretColumn = result.column
        attributedLineCache.removeValue(forKey: oldLine)
        attributedLineCache.removeValue(forKey: caretLine)
        resizeForBuffer()
        scrollLineToVisible(caretLine)
        markLinesDirty(oldLine, caretLine)
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

    func benchmarkEditing(iterations: Int) -> (insertMS: Double, deleteMS: Double, newlineMS: Double, pasteMS: Double) {
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

        return (insertMS, deleteMS, newlineMS, pasteMS)
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
    let item: NSTabViewItem
    let fileView: FastFileView
    var waitingInvocations = Set<String>()
    var isDirty = false

    init(path: String, item: NSTabViewItem, fileView: FastFileView) {
        self.path = path
        self.item = item
        self.fileView = fileView
    }
}

final class PendingInvocation {
    let id: String
    let paths: Set<String>
    let fd: Int32

    init(id: String, paths: Set<String>, fd: Int32) {
        self.id = id
        self.paths = paths
        self.fd = fd
    }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSTabViewDelegate {
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

    func applicationWillTerminate(_ notification: Notification) {
        for invocation in pendingInvocations.values {
            send(OpenResponse(ok: true, message: "app quit"), to: invocation.fd, closeAfterWrite: true)
        }
        socketServer?.stop()
    }

    @objc private func saveDocument(_ sender: Any?) {
        NSSound.beep()
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
        window.title = "Artisan Prototype"
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
        appMenu.addItem(withTitle: "Quit Artisan Prototype", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open...", action: #selector(openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Save Disabled In Prototype", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "Close Tab", action: #selector(closeCurrentTab(_:)), keyEquivalent: "w")
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
                fputs(String(format: "ArtisanPrototypeApp: opened %@ in %.2fms\n", path, elapsedMS), stderr)
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
        item.label = URL(fileURLWithPath: path).lastPathComponent
        item.view = scrollView

        return TabDocument(path: path, item: item, fileView: fileView)
    }

    private func close(item: NSTabViewItem) {
        guard let document = documentsByItem[item] else { return }

        tabView.removeTabViewItem(item)
        documentsByItem.removeValue(forKey: item)
        documentsByPath.removeValue(forKey: document.path)

        for invocationID in document.waitingInvocations {
            completeInvocationIfReady(invocationID)
        }
    }

    private func completeInvocationIfReady(_ invocationID: String) {
        guard let invocation = pendingInvocations[invocationID] else { return }
        let stillOpen = documentsByPath.values.contains { document in
            document.waitingInvocations.contains(invocationID)
        }
        guard !stillOpen else { return }

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
            fputs("ArtisanPrototypeApp: failed to encode response: \(error)\n", stderr)
        }

        if closeAfterWrite {
            Darwin.close(fd)
        }
    }
}

final class SocketServer {
    private let socketPath = "/tmp/artisan-prototype-\(getuid()).sock"
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

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.run()
