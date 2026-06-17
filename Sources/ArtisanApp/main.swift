import AppKit
import Darwin
import Foundation

struct OpenTarget: Codable, Hashable {
    let path: String
    let line: Int?
}

struct OpenRequest: Codable {
    let invocationID: String
    let targets: [OpenTarget]
    let wait: Bool

    enum CodingKeys: String, CodingKey {
        case invocationID
        case targets
        case paths
        case wait
    }

    init(invocationID: String, targets: [OpenTarget], wait: Bool) {
        self.invocationID = invocationID
        self.targets = targets
        self.wait = wait
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        invocationID = try container.decode(String.self, forKey: .invocationID)
        wait = try container.decode(Bool.self, forKey: .wait)
        if let targets = try container.decodeIfPresent([OpenTarget].self, forKey: .targets) {
            self.targets = targets
        } else {
            let paths = try container.decode([String].self, forKey: .paths)
            self.targets = paths.map { OpenTarget(path: $0, line: nil) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(invocationID, forKey: .invocationID)
        try container.encode(targets, forKey: .targets)
        try container.encode(targets.map(\.path), forKey: .paths)
        try container.encode(wait, forKey: .wait)
    }
}

struct OpenResponse: Codable {
    let ok: Bool
    let message: String
}

enum HighlightKind: String {
    case plain
    case keyword
    case string
    case number
    case comment
    case punctuation
    case tag
    case attribute
    case heading
    case code
    case link
    case emphasis
    case key
    case boolean
    case null
    case scalar
}

struct HighlightSegment {
    let text: String
    let color: NSColor
    let kind: HighlightKind

    init(text: String, color: NSColor, kind: HighlightKind = .plain) {
        self.text = text
        self.color = color
        self.kind = kind
    }
}

struct TextPosition: Comparable, Equatable {
    let line: Int
    let column: Int

    static func < (lhs: TextPosition, rhs: TextPosition) -> Bool {
        if lhs.line != rhs.line {
            return lhs.line < rhs.line
        }
        return lhs.column < rhs.column
    }
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

enum EditorPreferences {
    private static let fontSizeKey = "editor.fontSize"
    private static let windowFrameKey = "window.frame"
    static let defaultFontSize: CGFloat = 13

    static var fontSize: CGFloat {
        get {
            let stored = UserDefaults.standard.double(forKey: fontSizeKey)
            guard stored > 0 else { return defaultFontSize }
            return min(24, max(10, CGFloat(stored)))
        }
        set {
            UserDefaults.standard.set(Double(min(24, max(10, newValue))), forKey: fontSizeKey)
        }
    }

    static var savedWindowFrame: NSRect? {
        get {
            let value = UserDefaults.standard.string(forKey: windowFrameKey) ?? ""
            return NSRectFromString(value).isEmpty ? nil : NSRectFromString(value)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(NSStringFromRect(newValue), forKey: windowFrameKey)
            } else {
                UserDefaults.standard.removeObject(forKey: windowFrameKey)
            }
        }
    }
}

enum EditorLanguage: String, CaseIterable {
    case plainText = "text"
    case typeScript = "typescript"
    case javaScript = "javascript"
    case python = "python"
    case java = "java"
    case c = "c"
    case cpp = "cpp"
    case cSharp = "csharp"
    case go = "go"
    case rust = "rust"
    case php = "php"
    case ruby = "ruby"
    case swift = "swift"
    case kotlin = "kotlin"
    case sql = "sql"
    case html = "html"
    case css = "css"
    case shell = "shell"
    case json = "json"
    case yaml = "yaml"
    case r = "r"
    case markdown = "markdown"
    case makefile = "makefile"
    case dockerfile = "dockerfile"
    case xml = "xml"
    case toml = "toml"

    var id: String {
        rawValue
    }

    static func detect(path: String, data: Data) -> EditorLanguage {
        let url = URL(fileURLWithPath: path)
        let filename = url.lastPathComponent.lowercased()

        if let language = specialFilenameMap[filename] {
            return language
        }
        if filename.hasPrefix("dockerfile") {
            return .dockerfile
        }

        let fileExtension = url.pathExtension.lowercased()
        if let language = extensionMap[fileExtension] {
            return language
        }

        if let language = detectShebang(in: data) {
            return language
        }

        return .plainText
    }

    private static let specialFilenameMap: [String: EditorLanguage] = [
        "makefile": .makefile,
        "gnumakefile": .makefile,
        "gemfile": .ruby,
        "rakefile": .ruby,
        ".bashrc": .shell,
        ".zshrc": .shell
    ]

    private static let extensionMap: [String: EditorLanguage] = [
        "ts": .typeScript,
        "tsx": .typeScript,
        "mts": .typeScript,
        "cts": .typeScript,
        "js": .javaScript,
        "jsx": .javaScript,
        "mjs": .javaScript,
        "cjs": .javaScript,
        "py": .python,
        "pyi": .python,
        "java": .java,
        "c": .c,
        "h": .c,
        "cc": .cpp,
        "cpp": .cpp,
        "cxx": .cpp,
        "hpp": .cpp,
        "hh": .cpp,
        "hxx": .cpp,
        "cs": .cSharp,
        "go": .go,
        "rs": .rust,
        "php": .php,
        "phtml": .php,
        "rb": .ruby,
        "rake": .ruby,
        "swift": .swift,
        "kt": .kotlin,
        "kts": .kotlin,
        "sql": .sql,
        "html": .html,
        "htm": .html,
        "css": .css,
        "scss": .css,
        "sass": .css,
        "less": .css,
        "sh": .shell,
        "bash": .shell,
        "zsh": .shell,
        "fish": .shell,
        "json": .json,
        "jsonc": .json,
        "yml": .yaml,
        "yaml": .yaml,
        "r": .r,
        "md": .markdown,
        "mdx": .markdown,
        "markdown": .markdown,
        "txt": .plainText,
        "text": .plainText,
        "xml": .xml,
        "toml": .toml
    ]

    private static func detectShebang(in data: Data) -> EditorLanguage? {
        guard data.starts(with: Data("#!".utf8)) else {
            return nil
        }
        let prefix = data.prefix(256)
        let line = String(decoding: prefix, as: UTF8.self)
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .lowercased() ?? ""

        if line.contains("python") { return .python }
        if line.contains("ruby") { return .ruby }
        if line.contains("node") || line.contains("deno") { return .javaScript }
        if line.contains("php") { return .php }
        if line.contains("rscript") { return .r }
        if line.contains("bash") || line.contains("zsh") || line.contains("fish") || line.contains("/sh") {
            return .shell
        }
        return nil
    }
}

final class TextBuffer {
    let path: String
    private var data: Data
    private var language: EditorLanguage
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
        self.data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
        self.language = EditorLanguage.detect(path: path, data: data)
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

    var languageID: String {
        language.id
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

    func text(in range: (start: TextPosition, end: TextPosition)) -> String {
        let normalized = normalizedRange(range)
        let start = normalized.start
        let end = normalized.end
        guard start != end else { return "" }

        if start.line == end.line {
            return textSlice(lineText(at: start.line), start: start.column, end: end.column)
        }

        var pieces = [String]()
        pieces.append(textSuffix(lineText(at: start.line), from: start.column))
        if end.line > start.line + 1 {
            for line in (start.line + 1)..<end.line {
                pieces.append(lineText(at: line))
            }
        }
        pieces.append(textPrefix(lineText(at: end.line), through: end.column))
        return pieces.joined(separator: "\n")
    }

    func delete(in range: (start: TextPosition, end: TextPosition)) -> TextPosition {
        let normalized = normalizedRange(range)
        let start = normalized.start
        let end = normalized.end
        guard start != end else { return start }

        if start.line == end.line {
            var line = lineText(at: start.line)
            let startIndex = line.index(line.startIndex, offsetBy: start.column)
            let endIndex = line.index(line.startIndex, offsetBy: end.column)
            line.removeSubrange(startIndex..<endIndex)
            updateLine(start.line, text: line)
            return start
        }

        let prefix = textPrefix(lineText(at: start.line), through: start.column)
        let suffix = textSuffix(lineText(at: end.line), from: end.column)
        updateLine(start.line, text: prefix + suffix)

        let removedLineCount = end.line - start.line
        for _ in 0..<removedLineCount {
            let removalIndex = start.line + 1
            guard removalIndex < lineStarts.count else { break }
            lineStarts.remove(at: removalIndex)
            shiftSparseStateAfterLineRemoval(at: removalIndex)
        }

        highlightCache.removeAll(keepingCapacity: true)
        return start
    }

    func lines(start: Int, count: Int) -> [String] {
        if start + count > lineStarts.count && !fullyIndexed {
            ensureFullyIndexed()
        }
        let safeStart = min(max(0, start), lineCount - 1)
        let safeEnd = min(lineCount, safeStart + max(1, count))
        return (safeStart..<safeEnd).map { lineText(at: $0) }
    }

    func replaceLines(start: Int, removeCount: Int, with replacementLines: [String]) {
        if start + removeCount > lineStarts.count && !fullyIndexed {
            ensureFullyIndexed()
        }

        let lines = replacementLines.isEmpty ? [""] : replacementLines
        let safeStart = min(max(0, start), lineCount - 1)
        let safeRemoveCount = min(max(1, removeCount), lineCount - safeStart)

        updateLine(safeStart, text: lines[0])

        if safeRemoveCount > 1 {
            for _ in 1..<safeRemoveCount {
                let removalIndex = safeStart + 1
                guard removalIndex < lineStarts.count else { break }
                lineStarts.remove(at: removalIndex)
                shiftSparseStateAfterLineRemoval(at: removalIndex)
            }
        }

        if lines.count > 1 {
            let insertedCount = lines.count - 1
            for offset in 1...insertedCount {
                lineStarts.insert(0, at: safeStart + offset)
            }
            shiftSparseStateAfterLineInsertion(at: safeStart + 1, count: insertedCount)
            for offset in 1...insertedCount {
                updateLine(safeStart + offset, text: lines[offset])
            }
        }

        highlightCache.removeAll(keepingCapacity: true)
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
        language = EditorLanguage.detect(path: path, data: data)
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
        let segments = HighlighterRegistry.highlight(text, as: language)
        highlightCache[lineIndex] = (currentVersion, segments)
        return segments
    }

    private func updateLine(_ lineIndex: Int, text: String) {
        editedLines[lineIndex] = text
        lineVersions[lineIndex, default: 0] += 1
        maxLineByteCount = max(maxLineByteCount, text.utf8.count)
        highlightCache.removeValue(forKey: lineIndex)
    }

    private func normalizedRange(_ range: (start: TextPosition, end: TextPosition)) -> (start: TextPosition, end: TextPosition) {
        let rawStart = range.start < range.end ? range.start : range.end
        let rawEnd = range.start < range.end ? range.end : range.start
        return (
            start: clampedPosition(rawStart),
            end: clampedPosition(rawEnd)
        )
    }

    private func clampedPosition(_ position: TextPosition) -> TextPosition {
        if position.line >= lineStarts.count && !fullyIndexed {
            ensureFullyIndexed()
        }
        let safeLine = min(max(0, position.line), lineCount - 1)
        let safeColumn = min(max(0, position.column), lineText(at: safeLine).count)
        return TextPosition(line: safeLine, column: safeColumn)
    }

    private func textPrefix(_ text: String, through column: Int) -> String {
        let safeColumn = min(max(0, column), text.count)
        let end = text.index(text.startIndex, offsetBy: safeColumn)
        return String(text[..<end])
    }

    private func textSuffix(_ text: String, from column: Int) -> String {
        let safeColumn = min(max(0, column), text.count)
        let start = text.index(text.startIndex, offsetBy: safeColumn)
        return String(text[start...])
    }

    private func textSlice(_ text: String, start: Int, end: Int) -> String {
        let safeStart = min(max(0, start), text.count)
        let safeEnd = min(max(safeStart, end), text.count)
        let startIndex = text.index(text.startIndex, offsetBy: safeStart)
        let endIndex = text.index(text.startIndex, offsetBy: safeEnd)
        return String(text[startIndex..<endIndex])
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

protocol LineHighlighter {
    static func highlight(_ line: String) -> [HighlightSegment]
}

enum HighlighterRegistry {
    static func highlight(_ line: String, as language: EditorLanguage) -> [HighlightSegment] {
        switch language {
        case .typeScript, .javaScript:
            return TypeScriptHighlighter.highlight(line)
        case .markdown:
            return MarkdownHighlighter.highlight(line)
        case .json:
            return JSONHighlighter.highlight(line)
        case .yaml:
            return YAMLHighlighter.highlight(line)
        case .c:
            return CLikeHighlighter.highlight(line, keywords: CLikeHighlighter.cKeywords)
        case .cpp:
            return CLikeHighlighter.highlight(line, keywords: CLikeHighlighter.cppKeywords)
        case .cSharp:
            return CLikeHighlighter.highlight(line, keywords: CLikeHighlighter.cSharpKeywords)
        case .java:
            return CLikeHighlighter.highlight(line, keywords: CLikeHighlighter.javaKeywords)
        case .go:
            return CLikeHighlighter.highlight(line, keywords: CLikeHighlighter.goKeywords)
        case .rust:
            return CLikeHighlighter.highlight(line, keywords: CLikeHighlighter.rustKeywords)
        case .swift:
            return CLikeHighlighter.highlight(line, keywords: CLikeHighlighter.swiftKeywords)
        case .kotlin:
            return CLikeHighlighter.highlight(line, keywords: CLikeHighlighter.kotlinKeywords)
        case .python:
            return ScriptHighlighter.highlight(line, keywords: ScriptHighlighter.pythonKeywords)
        case .ruby:
            return ScriptHighlighter.highlight(line, keywords: ScriptHighlighter.rubyKeywords)
        case .php:
            return ScriptHighlighter.highlight(line, keywords: ScriptHighlighter.phpKeywords, commentMarkers: ["//", "#"])
        case .shell:
            return ScriptHighlighter.highlight(line, keywords: ScriptHighlighter.shellKeywords)
        case .r:
            return ScriptHighlighter.highlight(line, keywords: ScriptHighlighter.rKeywords)
        case .sql:
            return SQLHighlighter.highlight(line)
        case .html:
            return HTMLHighlighter.highlight(line)
        case .css:
            return CSSHighlighter.highlight(line)
        case .makefile:
            return MakefileHighlighter.highlight(line)
        case .dockerfile:
            return DockerfileHighlighter.highlight(line)
        case .xml:
            return XMLHighlighter.highlight(line)
        case .toml:
            return TOMLHighlighter.highlight(line)
        default:
            return PlainTextHighlighter.highlight(line)
        }
    }

    static func usesDedicatedHighlighter(for language: EditorLanguage) -> Bool {
        switch language {
        case .typeScript, .javaScript, .markdown, .json, .yaml,
             .c, .cpp, .cSharp, .java, .go, .rust, .swift, .kotlin:
            return true
        case .python, .ruby, .php, .shell, .r, .sql, .html, .css:
            return true
        case .makefile, .dockerfile, .xml, .toml:
            return true
        default:
            return false
        }
    }
}

enum PlainTextHighlighter: LineHighlighter {
    private static let plain = NSColor.labelColor

    static func highlight(_ line: String) -> [HighlightSegment] {
        [HighlightSegment(text: line, color: plain)]
    }
}

enum MarkdownHighlighter: LineHighlighter {
    private static let plain = NSColor.labelColor
    private static let heading = NSColor.systemBlue
    private static let code = NSColor.systemPurple
    private static let link = NSColor.systemTeal
    private static let emphasis = NSColor.systemOrange

    static func highlight(_ line: String) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }
        if line.hasPrefix("```") {
            return [HighlightSegment(text: line, color: code, kind: .code)]
        }
        if line.hasPrefix("#") {
            return [HighlightSegment(text: line, color: heading, kind: .heading)]
        }

        var segments: [HighlightSegment] = []
        var index = line.startIndex

        func append(_ start: String.Index, _ end: String.Index, _ color: NSColor, _ kind: HighlightKind = .plain) {
            guard start < end else { return }
            segments.append(HighlightSegment(text: String(line[start..<end]), color: color, kind: kind))
        }

        while index < line.endIndex {
            let char = line[index]
            let next = line.index(after: index)

            if char == "`", let close = line[next...].firstIndex(of: "`") {
                append(index, line.index(after: close), code, .code)
                index = line.index(after: close)
                continue
            }

            if char == "[",
               let closeLabel = line[next...].firstIndex(of: "]"),
               closeLabel < line.index(before: line.endIndex),
               line[line.index(after: closeLabel)] == "(",
               let closeURL = line[line.index(after: closeLabel)..<line.endIndex].firstIndex(of: ")") {
                append(index, line.index(after: closeURL), link, .link)
                index = line.index(after: closeURL)
                continue
            }

            if char == "*" {
                if next < line.endIndex, line[next] == "*" {
                    let contentStart = line.index(after: next)
                    if let close = line.range(of: "**", range: contentStart..<line.endIndex)?.lowerBound {
                        append(index, line.index(close, offsetBy: 2), emphasis, .emphasis)
                        index = line.index(close, offsetBy: 2)
                        continue
                    }
                } else if let close = line[next...].firstIndex(of: "*") {
                    append(index, line.index(after: close), emphasis, .emphasis)
                    index = line.index(after: close)
                    continue
                }
            }

            var end = next
            while end < line.endIndex, !"`[*".contains(line[end]) {
                end = line.index(after: end)
            }
            append(index, end, plain)
            index = end
        }

        return segments
    }
}

enum JSONHighlighter: LineHighlighter {
    private static let plain = NSColor.labelColor
    private static let key = NSColor.systemBlue
    private static let string = NSColor.systemRed
    private static let number = NSColor.systemPurple
    private static let keyword = NSColor.systemOrange
    private static let comment = NSColor.systemGreen
    private static let punctuation = NSColor.secondaryLabelColor

    static func highlight(_ line: String) -> [HighlightSegment] {
        lexValueLine(line, allowComments: true)
    }

    fileprivate static func lexValueLine(_ line: String, allowComments: Bool) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }
        var segments: [HighlightSegment] = []
        var index = line.startIndex

        func append(_ start: String.Index, _ end: String.Index, _ color: NSColor, _ kind: HighlightKind = .plain) {
            guard start < end else { return }
            segments.append(HighlightSegment(text: String(line[start..<end]), color: color, kind: kind))
        }

        func stringEnd(from start: String.Index, quote: Character) -> String.Index {
            var end = line.index(after: start)
            var escaped = false
            while end < line.endIndex {
                let char = line[end]
                let after = line.index(after: end)
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == quote {
                    return after
                }
                end = after
            }
            return end
        }

        func stringIsKey(endingAt end: String.Index) -> Bool {
            var cursor = end
            while cursor < line.endIndex, line[cursor].isWhitespace {
                cursor = line.index(after: cursor)
            }
            return cursor < line.endIndex && line[cursor] == ":"
        }

        while index < line.endIndex {
            let char = line[index]
            let next = line.index(after: index)

            if allowComments, char == "/", next < line.endIndex, line[next] == "/" {
                append(index, line.endIndex, comment, .comment)
                break
            }

            if char == "\"" {
                let end = stringEnd(from: index, quote: char)
                append(index, end, stringIsKey(endingAt: end) ? key : string, stringIsKey(endingAt: end) ? .key : .string)
                index = end
                continue
            }

            if char.isNumber || char == "-" {
                var end = next
                while end < line.endIndex, line[end].isNumber || line[end] == "." || line[end] == "e" || line[end] == "E" || line[end] == "+" || line[end] == "-" {
                    end = line.index(after: end)
                }
                append(index, end, number, .number)
                index = end
                continue
            }

            if char.isLetter {
                var end = next
                while end < line.endIndex, line[end].isLetter {
                    end = line.index(after: end)
                }
                let word = String(line[index..<end])
                switch word {
                case "true", "false":
                    append(index, end, keyword, .boolean)
                case "null":
                    append(index, end, keyword, .null)
                default:
                    append(index, end, plain, .scalar)
                }
                index = end
                continue
            }

            if "{}[]:,".contains(char) {
                append(index, next, punctuation, .punctuation)
            } else {
                append(index, next, plain)
            }
            index = next
        }

        return segments
    }
}

enum YAMLHighlighter: LineHighlighter {
    private static let plain = NSColor.labelColor
    private static let key = NSColor.systemBlue
    private static let punctuation = NSColor.secondaryLabelColor

    static func highlight(_ line: String) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return [HighlightSegment(text: line, color: NSColor.systemGreen, kind: .comment)]
        }
        guard let colon = line.firstIndex(of: ":") else {
            return JSONHighlighter.lexValueLine(line, allowComments: true)
        }

        var segments: [HighlightSegment] = []
        let afterColon = line.index(after: colon)
        if line.startIndex < colon {
            segments.append(HighlightSegment(text: String(line[line.startIndex..<colon]), color: key, kind: .key))
        }
        segments.append(HighlightSegment(text: ":", color: punctuation, kind: .punctuation))
        if afterColon < line.endIndex {
            segments.append(contentsOf: JSONHighlighter.lexValueLine(String(line[afterColon...]), allowComments: true))
        }
        return segments
    }
}

enum CLikeHighlighter {
    static let cKeywords: Set<String> = ["auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long", "register", "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while"]
    static let cppKeywords = cKeywords.union(["alignas", "alignof", "and", "asm", "bool", "catch", "class", "concept", "constexpr", "consteval", "constinit", "delete", "explicit", "export", "false", "friend", "mutable", "namespace", "new", "noexcept", "nullptr", "operator", "or", "private", "protected", "public", "requires", "template", "this", "thread_local", "throw", "true", "try", "typename", "using", "virtual"])
    static let cSharpKeywords: Set<String> = ["abstract", "as", "base", "bool", "break", "case", "catch", "class", "const", "decimal", "default", "delegate", "do", "else", "enum", "event", "false", "finally", "fixed", "for", "foreach", "if", "implicit", "in", "int", "interface", "internal", "is", "lock", "namespace", "new", "null", "object", "out", "override", "private", "protected", "public", "readonly", "ref", "return", "sealed", "static", "string", "struct", "switch", "this", "throw", "true", "try", "typeof", "using", "var", "virtual", "void", "while"]
    static let javaKeywords: Set<String> = ["abstract", "assert", "boolean", "break", "case", "catch", "char", "class", "const", "continue", "default", "do", "double", "else", "enum", "extends", "false", "final", "finally", "float", "for", "if", "implements", "import", "instanceof", "int", "interface", "long", "native", "new", "null", "package", "private", "protected", "public", "return", "short", "static", "strictfp", "super", "switch", "synchronized", "this", "throw", "throws", "transient", "true", "try", "var", "void", "volatile", "while"]
    static let goKeywords: Set<String> = ["break", "case", "chan", "const", "continue", "defer", "else", "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct", "switch", "type", "var"]
    static let rustKeywords: Set<String> = ["as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while"]
    static let swiftKeywords: Set<String> = ["as", "associatedtype", "break", "case", "catch", "class", "continue", "default", "defer", "deinit", "do", "else", "enum", "extension", "false", "fileprivate", "for", "func", "guard", "if", "import", "in", "init", "inout", "internal", "let", "nil", "open", "operator", "private", "protocol", "public", "repeat", "return", "self", "Self", "static", "struct", "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while"]
    static let kotlinKeywords: Set<String> = ["as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in", "interface", "is", "null", "object", "package", "return", "super", "this", "throw", "true", "try", "typealias", "val", "var", "when", "while"]

    private static let plain = NSColor.labelColor
    private static let keyword = NSColor.systemBlue
    private static let string = NSColor.systemRed
    private static let number = NSColor.systemPurple
    private static let comment = NSColor.systemGreen
    private static let punctuation = NSColor.secondaryLabelColor

    static func highlight(_ line: String, keywords: Set<String>) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }
        var segments: [HighlightSegment] = []
        var index = line.startIndex

        func append(_ start: String.Index, _ end: String.Index, _ color: NSColor, _ kind: HighlightKind = .plain) {
            guard start < end else { return }
            segments.append(HighlightSegment(text: String(line[start..<end]), color: color, kind: kind))
        }

        while index < line.endIndex {
            let char = line[index]
            let next = line.index(after: index)

            if char == "/", next < line.endIndex, line[next] == "/" {
                append(index, line.endIndex, comment, .comment)
                break
            }

            if char == "/", next < line.endIndex, line[next] == "*" {
                var end = line.index(after: next)
                while end < line.endIndex {
                    let after = line.index(after: end)
                    if line[end] == "*", after < line.endIndex, line[after] == "/" {
                        end = line.index(after: after)
                        break
                    }
                    end = after
                }
                append(index, end, comment, .comment)
                index = end
                continue
            }

            if char == "\"" || char == "'" {
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
                append(index, end, string, .string)
                index = end
                continue
            }

            if char.isNumber {
                var end = next
                while end < line.endIndex, line[end].isNumber || line[end] == "." || line[end] == "_" {
                    end = line.index(after: end)
                }
                append(index, end, number, .number)
                index = end
                continue
            }

            if char.isLetter || char == "_" {
                var end = next
                while end < line.endIndex, line[end].isLetter || line[end].isNumber || line[end] == "_" {
                    end = line.index(after: end)
                }
                let word = String(line[index..<end])
                append(index, end, keywords.contains(word) ? keyword : plain, keywords.contains(word) ? .keyword : .plain)
                index = end
                continue
            }

            if "{}[]().,:;+-*=<>!&|?/".contains(char) {
                append(index, next, punctuation, .punctuation)
            } else {
                append(index, next, plain)
            }
            index = next
        }

        return segments
    }
}

enum ScriptHighlighter {
    static let pythonKeywords: Set<String> = ["and", "as", "assert", "async", "await", "break", "class", "continue", "def", "elif", "else", "except", "False", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "None", "nonlocal", "not", "or", "pass", "raise", "return", "True", "try", "while", "with", "yield"]
    static let rubyKeywords: Set<String> = ["BEGIN", "END", "alias", "and", "begin", "break", "case", "class", "def", "defined?", "do", "else", "elsif", "end", "ensure", "false", "for", "if", "in", "module", "next", "nil", "not", "or", "redo", "rescue", "retry", "return", "self", "super", "then", "true", "undef", "unless", "until", "when", "while", "yield"]
    static let phpKeywords: Set<String> = ["abstract", "and", "array", "as", "break", "case", "catch", "class", "const", "continue", "declare", "default", "do", "echo", "else", "elseif", "enddeclare", "endfor", "endforeach", "endif", "endswitch", "endwhile", "extends", "false", "final", "finally", "fn", "for", "foreach", "function", "global", "if", "implements", "include", "instanceof", "interface", "namespace", "new", "null", "or", "private", "protected", "public", "require", "return", "static", "switch", "throw", "trait", "true", "try", "use", "var", "while", "xor"]
    static let shellKeywords: Set<String> = ["case", "cd", "do", "done", "echo", "elif", "else", "esac", "export", "fi", "for", "function", "if", "in", "local", "printf", "return", "select", "then", "until", "while"]
    static let rKeywords: Set<String> = ["FALSE", "Inf", "NA", "NULL", "NaN", "TRUE", "break", "else", "for", "function", "if", "in", "next", "repeat", "return", "while"]

    private static let plain = NSColor.labelColor
    private static let keyword = NSColor.systemBlue
    private static let string = NSColor.systemRed
    private static let number = NSColor.systemPurple
    private static let comment = NSColor.systemGreen
    private static let punctuation = NSColor.secondaryLabelColor
    private static let variable = NSColor.systemOrange

    static func highlight(_ line: String, keywords: Set<String>, commentMarkers: [String] = ["#"]) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }
        var segments: [HighlightSegment] = []
        var index = line.startIndex

        func append(_ start: String.Index, _ end: String.Index, _ color: NSColor, _ kind: HighlightKind = .plain) {
            guard start < end else { return }
            segments.append(HighlightSegment(text: String(line[start..<end]), color: color, kind: kind))
        }

        while index < line.endIndex {
            for marker in commentMarkers where line[index...].hasPrefix(marker) {
                append(index, line.endIndex, comment, .comment)
                return segments
            }

            let char = line[index]
            let next = line.index(after: index)

            if char == "\"" || char == "'" {
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
                append(index, end, string, .string)
                index = end
                continue
            }

            if char == "$", next < line.endIndex {
                var end = next
                while end < line.endIndex, line[end].isLetter || line[end].isNumber || line[end] == "_" {
                    end = line.index(after: end)
                }
                append(index, end, variable, .attribute)
                index = end
                continue
            }

            if char.isNumber {
                var end = next
                while end < line.endIndex, line[end].isNumber || line[end] == "." || line[end] == "_" {
                    end = line.index(after: end)
                }
                append(index, end, number, .number)
                index = end
                continue
            }

            if char.isLetter || char == "_" {
                var end = next
                while end < line.endIndex, line[end].isLetter || line[end].isNumber || line[end] == "_" || line[end] == "?" {
                    end = line.index(after: end)
                }
                let word = String(line[index..<end])
                append(index, end, keywords.contains(word) ? keyword : plain, keywords.contains(word) ? .keyword : .plain)
                index = end
                continue
            }

            if "{}[]().,:;+-*=<>!&|?/\\%".contains(char) {
                append(index, next, punctuation, .punctuation)
            } else {
                append(index, next, plain)
            }
            index = next
        }

        return segments
    }
}

enum SQLHighlighter: LineHighlighter {
    private static let keywords: Set<String> = ["ALTER", "AND", "AS", "ASC", "BEGIN", "BETWEEN", "BY", "CASE", "CREATE", "DELETE", "DESC", "DROP", "ELSE", "END", "FALSE", "FROM", "GROUP", "HAVING", "IN", "INSERT", "INTO", "IS", "JOIN", "LEFT", "LIKE", "LIMIT", "NOT", "NULL", "ON", "OR", "ORDER", "RIGHT", "SELECT", "SET", "TABLE", "THEN", "TRUE", "UPDATE", "VALUES", "WHEN", "WHERE"]

    static func highlight(_ line: String) -> [HighlightSegment] {
        ScriptHighlighter.highlight(line, keywords: keywords, commentMarkers: ["--"])
    }
}

enum HTMLHighlighter: LineHighlighter {
    private static let plain = NSColor.labelColor
    private static let tag = NSColor.systemTeal
    private static let attribute = NSColor.systemOrange
    private static let string = NSColor.systemRed
    private static let comment = NSColor.systemGreen
    private static let punctuation = NSColor.secondaryLabelColor

    static func highlight(_ line: String) -> [HighlightSegment] {
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("<!--") {
            return [HighlightSegment(text: line, color: comment, kind: .comment)]
        }
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }
        var segments: [HighlightSegment] = []
        var index = line.startIndex

        func append(_ start: String.Index, _ end: String.Index, _ color: NSColor, _ kind: HighlightKind = .plain) {
            guard start < end else { return }
            segments.append(HighlightSegment(text: String(line[start..<end]), color: color, kind: kind))
        }

        func isNameCharacter(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "-" || character == "_" || character == ":"
        }

        while index < line.endIndex {
            let char = line[index]
            let next = line.index(after: index)
            guard char == "<" else {
                var end = next
                while end < line.endIndex, line[end] != "<" {
                    end = line.index(after: end)
                }
                append(index, end, plain)
                index = end
                continue
            }

            append(index, next, punctuation, .punctuation)
            index = next
            if index < line.endIndex, line[index] == "/" {
                let afterSlash = line.index(after: index)
                append(index, afterSlash, punctuation, .punctuation)
                index = afterSlash
            }
            if index < line.endIndex, isNameCharacter(line[index]) {
                var end = line.index(after: index)
                while end < line.endIndex, isNameCharacter(line[end]) {
                    end = line.index(after: end)
                }
                append(index, end, tag, .tag)
                index = end
            }
            while index < line.endIndex {
                let current = line[index]
                let after = line.index(after: index)
                if current == ">" {
                    append(index, after, punctuation, .punctuation)
                    index = after
                    break
                }
                if current == "\"" || current == "'" {
                    var end = after
                    while end < line.endIndex {
                        let nextEnd = line.index(after: end)
                        if line[end] == current {
                            end = nextEnd
                            break
                        }
                        end = nextEnd
                    }
                    append(index, end, string, .string)
                    index = end
                    continue
                }
                if isNameCharacter(current) {
                    var end = after
                    while end < line.endIndex, isNameCharacter(line[end]) {
                        end = line.index(after: end)
                    }
                    append(index, end, attribute, .attribute)
                    index = end
                    continue
                }
                append(index, after, "{}[]=/".contains(current) ? punctuation : plain, "{}[]=/".contains(current) ? .punctuation : .plain)
                index = after
            }
        }
        return segments
    }
}

enum CSSHighlighter: LineHighlighter {
    private static let plain = NSColor.labelColor
    private static let key = NSColor.systemBlue
    private static let string = NSColor.systemRed
    private static let number = NSColor.systemPurple
    private static let comment = NSColor.systemGreen
    private static let punctuation = NSColor.secondaryLabelColor

    static func highlight(_ line: String) -> [HighlightSegment] {
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("/*") {
            return [HighlightSegment(text: line, color: comment, kind: .comment)]
        }
        var segments: [HighlightSegment] = []
        var index = line.startIndex

        func append(_ start: String.Index, _ end: String.Index, _ color: NSColor, _ kind: HighlightKind = .plain) {
            guard start < end else { return }
            segments.append(HighlightSegment(text: String(line[start..<end]), color: color, kind: kind))
        }

        while index < line.endIndex {
            let char = line[index]
            let next = line.index(after: index)
            if char == "\"" || char == "'" {
                var end = next
                while end < line.endIndex {
                    let after = line.index(after: end)
                    if line[end] == char {
                        end = after
                        break
                    }
                    end = after
                }
                append(index, end, string, .string)
                index = end
                continue
            }
            if char.isNumber {
                var end = next
                while end < line.endIndex, line[end].isNumber || line[end] == "." {
                    end = line.index(after: end)
                }
                append(index, end, number, .number)
                index = end
                continue
            }
            if char.isLetter || char == "-" {
                var end = next
                while end < line.endIndex, line[end].isLetter || line[end].isNumber || line[end] == "-" {
                    end = line.index(after: end)
                }
                var cursor = end
                while cursor < line.endIndex, line[cursor].isWhitespace {
                    cursor = line.index(after: cursor)
                }
                append(index, end, cursor < line.endIndex && line[cursor] == ":" ? key : plain, cursor < line.endIndex && line[cursor] == ":" ? .key : .plain)
                index = end
                continue
            }
            if "{}[]().,:;#%+-*=<>!".contains(char) {
                append(index, next, punctuation, .punctuation)
            } else {
                append(index, next, plain)
            }
            index = next
        }
        return segments
    }
}

enum MakefileHighlighter: LineHighlighter {
    private static let plain = NSColor.labelColor
    private static let key = NSColor.systemBlue
    private static let keyword = NSColor.systemBlue
    private static let comment = NSColor.systemGreen
    private static let punctuation = NSColor.secondaryLabelColor

    static func highlight(_ line: String) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            return [HighlightSegment(text: line, color: comment, kind: .comment)]
        }

        if line.first == "\t" {
            return highlightRecipe(line)
        }

        if let colon = line.firstIndex(of: ":"), shouldTreatAsTarget(line, colon: colon) {
            return splitKeyValue(line, separator: colon)
        }

        if let assignment = assignmentSeparator(in: line) {
            return splitKeyValue(line, separator: assignment)
        }

        return ShellValueHighlighter.highlight(line)
    }

    private static func highlightRecipe(_ line: String) -> [HighlightSegment] {
        var segments: [HighlightSegment] = []
        var index = line.startIndex

        while index < line.endIndex, line[index].isWhitespace {
            let next = line.index(after: index)
            segments.append(HighlightSegment(text: String(line[index..<next]), color: plain))
            index = next
        }

        if index < line.endIndex {
            var end = line.index(after: index)
            while end < line.endIndex, isIdentifierCharacter(line[end]) {
                end = line.index(after: end)
            }
            if index < end {
                segments.append(HighlightSegment(text: String(line[index..<end]), color: keyword, kind: .keyword))
                index = end
            }
        }

        if index < line.endIndex {
            segments.append(contentsOf: ShellValueHighlighter.highlight(String(line[index...])))
        }
        return segments
    }

    private static func splitKeyValue(_ line: String, separator: String.Index) -> [HighlightSegment] {
        var segments: [HighlightSegment] = []
        if line.startIndex < separator {
            segments.append(HighlightSegment(text: String(line[line.startIndex..<separator]), color: key, kind: .key))
        }
        let afterSeparator = line.index(after: separator)
        segments.append(HighlightSegment(text: String(line[separator..<afterSeparator]), color: punctuation, kind: .punctuation))
        if afterSeparator < line.endIndex {
            segments.append(contentsOf: ShellValueHighlighter.highlight(String(line[afterSeparator...])))
        }
        return segments
    }

    private static func shouldTreatAsTarget(_ line: String, colon: String.Index) -> Bool {
        let prefix = line[line.startIndex..<colon]
        return !prefix.isEmpty && !prefix.contains("=")
    }

    private static func assignmentSeparator(in line: String) -> String.Index? {
        var index = line.startIndex
        while index < line.endIndex {
            let char = line[index]
            if char == "=" {
                return index
            }
            if char == ":" {
                let next = line.index(after: index)
                if next < line.endIndex, line[next] == "=" {
                    return index
                }
            }
            if char == "+" || char == "?" {
                let next = line.index(after: index)
                if next < line.endIndex, line[next] == "=" {
                    return index
                }
            }
            index = line.index(after: index)
        }
        return nil
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "-" || character == "." || character == "/"
    }
}

enum DockerfileHighlighter: LineHighlighter {
    private static let plain = NSColor.labelColor
    private static let keyword = NSColor.systemBlue
    private static let comment = NSColor.systemGreen

    static func highlight(_ line: String) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            return [HighlightSegment(text: line, color: comment, kind: .comment)]
        }

        var segments: [HighlightSegment] = []
        var index = line.startIndex
        while index < line.endIndex, line[index].isWhitespace {
            let next = line.index(after: index)
            segments.append(HighlightSegment(text: String(line[index..<next]), color: plain))
            index = next
        }

        if index < line.endIndex {
            var end = line.index(after: index)
            while end < line.endIndex, line[end].isLetter || line[end] == "_" {
                end = line.index(after: end)
            }
            segments.append(HighlightSegment(text: String(line[index..<end]), color: keyword, kind: .keyword))
            index = end
        }

        if index < line.endIndex {
            segments.append(contentsOf: ShellValueHighlighter.highlight(String(line[index...])))
        }
        return segments
    }
}

enum XMLHighlighter: LineHighlighter {
    static func highlight(_ line: String) -> [HighlightSegment] {
        HTMLHighlighter.highlight(line)
    }
}

enum TOMLHighlighter: LineHighlighter {
    private static let plain = NSColor.labelColor
    private static let key = NSColor.systemBlue
    private static let tag = NSColor.systemTeal
    private static let string = NSColor.systemRed
    private static let number = NSColor.systemPurple
    private static let boolean = NSColor.systemOrange
    private static let comment = NSColor.systemGreen
    private static let punctuation = NSColor.secondaryLabelColor

    static func highlight(_ line: String) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return [HighlightSegment(text: line, color: comment, kind: .comment)]
        }

        let firstNonWhitespace = line.firstIndex { !$0.isWhitespace } ?? line.startIndex
        if firstNonWhitespace < line.endIndex, line[firstNonWhitespace] == "[" {
            return highlightSection(line, from: firstNonWhitespace)
        }

        guard let equals = line.firstIndex(of: "=") else {
            return highlightValue(line)
        }

        var segments: [HighlightSegment] = []
        if line.startIndex < equals {
            segments.append(HighlightSegment(text: String(line[line.startIndex..<equals]), color: key, kind: .key))
        }
        let afterEquals = line.index(after: equals)
        segments.append(HighlightSegment(text: "=", color: punctuation, kind: .punctuation))
        if afterEquals < line.endIndex {
            segments.append(contentsOf: highlightValue(String(line[afterEquals...])))
        }
        return segments
    }

    private static func highlightSection(_ line: String, from start: String.Index) -> [HighlightSegment] {
        var segments: [HighlightSegment] = []
        if line.startIndex < start {
            segments.append(HighlightSegment(text: String(line[line.startIndex..<start]), color: plain))
        }
        var index = start
        while index < line.endIndex {
            let next = line.index(after: index)
            let char = line[index]
            if char == "[" || char == "]" || char == "." {
                segments.append(HighlightSegment(text: String(line[index..<next]), color: punctuation, kind: .punctuation))
            } else if char == "#" {
                segments.append(HighlightSegment(text: String(line[index..<line.endIndex]), color: comment, kind: .comment))
                break
            } else if char.isLetter || char.isNumber || char == "_" || char == "-" {
                var end = next
                while end < line.endIndex, line[end].isLetter || line[end].isNumber || line[end] == "_" || line[end] == "-" {
                    end = line.index(after: end)
                }
                segments.append(HighlightSegment(text: String(line[index..<end]), color: tag, kind: .tag))
                index = end
                continue
            } else {
                segments.append(HighlightSegment(text: String(line[index..<next]), color: plain))
            }
            index = next
        }
        return segments
    }

    private static func highlightValue(_ line: String) -> [HighlightSegment] {
        var segments: [HighlightSegment] = []
        var index = line.startIndex

        func append(_ start: String.Index, _ end: String.Index, _ color: NSColor, _ kind: HighlightKind = .plain) {
            guard start < end else { return }
            segments.append(HighlightSegment(text: String(line[start..<end]), color: color, kind: kind))
        }

        while index < line.endIndex {
            let char = line[index]
            let next = line.index(after: index)

            if char == "#" {
                append(index, line.endIndex, comment, .comment)
                break
            }

            if char == "\"" || char == "'" {
                let quote = char
                var end = next
                var escaped = false
                while end < line.endIndex {
                    let current = line[end]
                    let after = line.index(after: end)
                    if escaped {
                        escaped = false
                    } else if current == "\\" {
                        escaped = true
                    } else if current == quote {
                        end = after
                        break
                    }
                    end = after
                }
                append(index, end, string, .string)
                index = end
                continue
            }

            if char.isNumber || char == "-" {
                var end = next
                while end < line.endIndex, line[end].isNumber || line[end] == "." || line[end] == "_" || line[end] == "e" || line[end] == "E" || line[end] == "+" || line[end] == "-" {
                    end = line.index(after: end)
                }
                append(index, end, number, .number)
                index = end
                continue
            }

            if char.isLetter {
                var end = next
                while end < line.endIndex, line[end].isLetter || line[end].isNumber || line[end] == "_" || line[end] == "-" {
                    end = line.index(after: end)
                }
                let word = String(line[index..<end])
                if word == "true" || word == "false" {
                    append(index, end, boolean, .boolean)
                } else {
                    append(index, end, plain, .scalar)
                }
                index = end
                continue
            }

            if "[]{}=,.".contains(char) {
                append(index, next, punctuation, .punctuation)
            } else {
                append(index, next, plain)
            }
            index = next
        }

        return segments
    }
}

enum ShellValueHighlighter {
    static func highlight(_ line: String) -> [HighlightSegment] {
        ScriptHighlighter.highlight(line, keywords: [])
    }
}

enum TypeScriptHighlighter: LineHighlighter {
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
    private static let tag = NSColor.systemTeal
    private static let attribute = NSColor.systemOrange

    static func highlight(_ line: String) -> [HighlightSegment] {
        guard !line.isEmpty else { return [HighlightSegment(text: "", color: plain)] }

        var segments: [HighlightSegment] = []
        var index = line.startIndex

        func append(_ start: String.Index, _ end: String.Index, _ color: NSColor, _ kind: HighlightKind = .plain) {
            guard start < end else { return }
            segments.append(HighlightSegment(text: String(line[start..<end]), color: color, kind: kind))
        }

        while index < line.endIndex {
            let char = line[index]
            let next = line.index(after: index)

            if char == "/", next < line.endIndex, line[next] == "/" {
                append(index, line.endIndex, comment, .comment)
                break
            }

            if char == "/", next < line.endIndex, line[next] == "*" {
                var end = line.index(after: next)
                while end < line.endIndex {
                    let after = line.index(after: end)
                    if line[end] == "*", after < line.endIndex, line[after] == "/" {
                        end = line.index(after: after)
                        break
                    }
                    end = after
                }
                append(index, end, comment, .comment)
                index = end
                continue
            }

            if char == "<", next < line.endIndex, (line[next].isLetter || line[next] == "/" || line[next] == ">") {
                index = appendJSXTag(in: line, from: index, append: append)
                continue
            }

            if char == "{", next < line.endIndex, line[next] == "/" {
                append(index, next, punctuation, .punctuation)
                index = next
                continue
            }

            if char == "}", next < line.endIndex {
                append(index, next, punctuation, .punctuation)
                index = next
                continue
            }

            if char == "/" && next < line.endIndex && line[next] == ">" {
                append(index, line.index(after: next), punctuation, .punctuation)
                index = line.index(after: next)
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
                append(index, end, string, .string)
                index = end
                continue
            }

            if char.isNumber {
                var end = next
                while end < line.endIndex, line[end].isNumber || line[end] == "." || line[end] == "_" {
                    end = line.index(after: end)
                }
                append(index, end, number, .number)
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
                if keywords.contains(word) {
                    append(index, end, keyword, .keyword)
                } else {
                    append(index, end, plain)
                }
                index = end
                continue
            }

            if "{}[]().,:;+-*=<>!&|?/".contains(char) {
                append(index, next, punctuation, .punctuation)
            } else {
                append(index, next, plain)
            }
            index = next
        }

        return segments
    }

    private static func appendJSXTag(
        in line: String,
        from start: String.Index,
        append: (String.Index, String.Index, NSColor, HighlightKind) -> Void
    ) -> String.Index {
        var index = start

        func isNameCharacter(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "_" || character == "-" || character == "$" || character == ":"
        }

        let afterOpen = line.index(after: index)
        append(index, afterOpen, punctuation, .punctuation)
        index = afterOpen

        if index < line.endIndex, line[index] == "/" {
            let afterSlash = line.index(after: index)
            append(index, afterSlash, punctuation, .punctuation)
            index = afterSlash
        }

        if index < line.endIndex, isNameCharacter(line[index]) {
            var end = line.index(after: index)
            while end < line.endIndex, isNameCharacter(line[end]) {
                end = line.index(after: end)
            }
            append(index, end, tag, .tag)
            index = end
        }

        while index < line.endIndex {
            let char = line[index]
            let next = line.index(after: index)

            if char == ">" {
                append(index, next, punctuation, .punctuation)
                return next
            }

            if char == "/", next < line.endIndex, line[next] == ">" {
                append(index, line.index(after: next), punctuation, .punctuation)
                return line.index(after: next)
            }

            if char == "\"" || char == "'" {
                let quote = char
                var end = next
                while end < line.endIndex {
                    let after = line.index(after: end)
                    if line[end] == quote {
                        end = after
                        break
                    }
                    end = after
                }
                append(index, end, string, .string)
                index = end
                continue
            }

            if isNameCharacter(char) {
                var end = next
                while end < line.endIndex, isNameCharacter(line[end]) {
                    end = line.index(after: end)
                }
                append(index, end, attribute, .attribute)
                index = end
                continue
            }

            if "{}[]=.".contains(char) {
                append(index, next, punctuation, .punctuation)
            } else {
                append(index, next, plain, .plain)
            }
            index = next
        }

        return index
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
    private struct SelectionState: Equatable {
        let anchor: TextPosition?
        let active: TextPosition?
    }

    private struct UndoEntry {
        let startLine: Int
        let beforeLines: [String]
        var afterLines: [String]
        let beforeCaret: TextPosition
        var afterCaret: TextPosition
        let beforeSelection: SelectionState
        var afterSelection: SelectionState
        let coalescesTyping: Bool
    }

    private struct FindMatch: Equatable {
        let line: Int
        let startColumn: Int
        let endColumn: Int
    }

    private var buffer: TextBuffer
    private var font: NSFont
    private var lineNumberFont: NSFont
    private let lineNumberColor = NSColor.secondaryLabelColor
    private let caretColor = NSColor.controlAccentColor
    private var lineHeight: CGFloat
    private var charWidth: CGFloat
    private var gutterWidth: CGFloat
    private let horizontalPadding: CGFloat = 12
    private static let maxLayoutColumns = 20_000
    private var caretLine = 0
    private var caretColumn = 0
    private var selectionAnchor: TextPosition?
    private var selectionActive: TextPosition?
    private var undoStack: [UndoEntry] = []
    private var redoStack: [UndoEntry] = []
    private var findQuery = ""
    private var findMatches: [FindMatch] = []
    private var activeFindMatchIndex: Int?
    private var attributedLineCache: [Int: (version: Int, text: NSAttributedString)] = [:]
    var onEdit: (() -> Void)?
    private(set) var drawCallCount = 0
    private(set) var indexOnDrawCount = 0
    private(set) var indexOnScrollCount = 0
    private(set) var lastRenderedNonEmptyLines = 0
    private(set) var lastRenderedRange: ClosedRange<Int>?

    init(buffer: TextBuffer) {
        self.buffer = buffer
        let fontSize = EditorPreferences.fontSize
        self.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        self.lineNumberFont = NSFont.monospacedSystemFont(ofSize: max(10, fontSize - 1), weight: .regular)
        self.lineHeight = ceil(font.ascender - font.descender + font.leading) + 11
        self.charWidth = max(1, "W".size(withAttributes: [.font: font]).width)
        let digits = max(2, String(buffer.lineCount).count)
        self.gutterWidth = CGFloat(digits) * max(1, "8".size(withAttributes: [.font: lineNumberFont]).width) + 18

        let width = gutterWidth + horizontalPadding * 2 + CGFloat(min(buffer.maxLineByteCount, Self.maxLayoutColumns)) * charWidth
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
                currentLineHighlightRect(in: visibleRect).fill()
            }
            drawFindHighlights(onLine: line, atY: y)
            drawSelectionBackground(onLine: line, atY: y)
            drawHighlightedLine(line, atY: y)
        }
        drawStickyGutter(in: visibleRect, startLine: startLine, endLine: endLine, attributes: lineNumberAttributes)

        if let caret = visibleCaretRect(in: visibleRect) {
            caretColor.setFill()
            caret.fill()
        }
    }

    override func keyDown(with event: NSEvent) {
        let extendingSelection = event.modifierFlags.contains(.shift)
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "a":
                selectAll()
                return
            case "c":
                _ = copySelectionToPasteboard()
                return
            case "x":
                cutSelectionToPasteboard()
                return
            case "v":
                pasteFromClipboard()
                return
            case "z":
                if event.modifierFlags.contains(.shift) {
                    redo()
                } else {
                    undo()
                }
                return
            default:
                break
            }
            switch event.keyCode {
            case 123:
                moveToLineStart(extending: extendingSelection)
            case 124:
                moveToLineEnd(extending: extendingSelection)
            case 125:
                moveToFileEnd(extending: extendingSelection)
            case 126:
                moveToFileStart(extending: extendingSelection)
            default:
                super.keyDown(with: event)
            }
            return
        }

        if event.modifierFlags.contains(.option) {
            switch event.keyCode {
            case 123:
                moveWordLeft(extending: extendingSelection)
            case 124:
                moveWordRight(extending: extendingSelection)
            default:
                super.keyDown(with: event)
            }
            return
        }

        switch event.keyCode {
        case 51:
            applyEdit(affectedLines: backwardDeleteLineRange()) {
                deleteSelectionIfNeeded() ?? buffer.deleteBackward(atLine: caretLine, column: caretColumn)
            }
        case 117:
            applyEdit(affectedLines: forwardDeleteLineRange()) {
                deleteSelectionIfNeeded() ?? buffer.deleteForward(atLine: caretLine, column: caretColumn)
            }
        case 36, 76:
            applyEdit(affectedLines: selectionLineRange() ?? caretLine...caretLine) {
                replaceSelection(with: "\n")
            }
        case 123:
            moveCharacterLeft(extending: extendingSelection)
        case 124:
            moveCharacterRight(extending: extendingSelection)
        case 125:
            moveLineDown(extending: extendingSelection)
        case 126:
            moveLineUp(extending: extendingSelection)
        case 121:
            movePageDown(extending: extendingSelection)
        case 116:
            movePageUp(extending: extendingSelection)
        case 115:
            moveToLineStart(extending: extendingSelection)
        case 119:
            moveToLineEnd(extending: extendingSelection)
        default:
            if let characters = event.characters, characters.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) {
                applyEdit(
                    affectedLines: selectionLineRange() ?? caretLine...caretLine,
                    coalescesTyping: normalizedSelectionRange() == nil && characters.count == 1
                ) {
                    replaceSelection(with: characters)
                }
            } else {
                super.keyDown(with: event)
            }
        }
    }

    private func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            return
        }
        applyEdit(affectedLines: selectionLineRange() ?? caretLine...caretLine) {
            replaceSelection(with: text)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let position = position(for: convert(event.locationInWindow, from: nil))
        if event.clickCount >= 3 {
            selectLine(at: position.line)
        } else if event.clickCount == 2 {
            selectWord(at: position)
        } else {
            moveCaret(line: position.line, column: position.column)
        }
        displayVisibleRect()
    }

    override func mouseDragged(with event: NSEvent) {
        let position = position(for: convert(event.locationInWindow, from: nil))
        moveCaret(line: position.line, column: position.column, extending: true)
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

    private func drawSelectionBackground(onLine line: Int, atY y: CGFloat) {
        guard let columns = selectedColumns(onLine: line), columns.start < columns.end else {
            return
        }

        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.45).setFill()
        let startX = gutterWidth + horizontalPadding + CGFloat(columns.start) * charWidth
        let width = max(2, CGFloat(columns.end - columns.start) * charWidth)
        NSRect(x: startX, y: y + 1, width: width, height: lineHeight - 2).fill()
    }

    private func caretRect() -> NSRect {
        NSRect(
            x: gutterWidth + horizontalPadding + CGFloat(caretColumn) * charWidth,
            y: CGFloat(caretLine) * lineHeight,
            width: 2,
            height: lineHeight
        )
    }

    private func visibleCaretRect(in visibleRect: NSRect) -> NSRect? {
        let caret = caretRect()
        guard visibleRect.intersects(caret) else {
            return nil
        }

        let drawRect = NSRect(
            x: caret.minX,
            y: CGFloat(caretLine) * lineHeight + 2,
            width: caret.width,
            height: lineHeight - 4
        )
        let textViewport = textViewportRect(in: visibleRect)
        let clipped = drawRect.intersection(textViewport)
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else {
            return nil
        }

        return clipped
    }

    private func textViewportRect(in visibleRect: NSRect) -> NSRect {
        NSRect(
            x: visibleRect.minX + gutterWidth,
            y: visibleRect.minY,
            width: max(0, visibleRect.width - gutterWidth),
            height: visibleRect.height
        )
    }

    private func currentLineHighlightRect(in visibleRect: NSRect) -> NSRect {
        NSRect(
            x: visibleRect.minX,
            y: CGFloat(caretLine) * lineHeight,
            width: visibleRect.width,
            height: lineHeight
        )
    }

    private func lineNumberRect(
        for line: Int,
        in visibleRect: NSRect,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSRect {
        let lineNumber = "\(line + 1)" as NSString
        let lineNumberSize = lineNumber.size(withAttributes: attributes)
        return NSRect(
            x: visibleRect.minX + gutterWidth - lineNumberSize.width - 8,
            y: CGFloat(line) * lineHeight + 2,
            width: lineNumberSize.width,
            height: lineNumberSize.height
        )
    }

    private func drawStickyGutter(
        in visibleRect: NSRect,
        startLine: Int,
        endLine: Int,
        attributes: [NSAttributedString.Key: Any]
    ) {
        NSColor.textBackgroundColor.setFill()
        NSRect(
            x: visibleRect.minX,
            y: visibleRect.minY,
            width: gutterWidth,
            height: visibleRect.height
        ).fill()

        NSColor.separatorColor.withAlphaComponent(0.35).setFill()
        NSRect(
            x: visibleRect.minX + gutterWidth - 1,
            y: visibleRect.minY,
            width: 1,
            height: visibleRect.height
        ).fill()

        for line in startLine...endLine {
            let lineNumber = "\(line + 1)" as NSString
            lineNumber.draw(
                at: lineNumberRect(for: line, in: visibleRect, attributes: attributes).origin,
                withAttributes: attributes
            )
        }
    }

    private func drawFindHighlights(onLine line: Int, atY y: CGFloat) {
        let matches = findMatches(onLine: line)
        guard !matches.isEmpty else {
            return
        }

        for match in matches {
            let isActive = activeFindMatchIndex.map { findMatches.indices.contains($0) && findMatches[$0] == match } ?? false
            let color = isActive
                ? NSColor.systemYellow.withAlphaComponent(0.55)
                : NSColor.systemYellow.withAlphaComponent(0.28)
            color.setFill()
            let startX = gutterWidth + horizontalPadding + CGFloat(match.startColumn) * charWidth
            let width = max(2, CGFloat(match.endColumn - match.startColumn) * charWidth)
            NSRect(x: startX, y: y + 3, width: width, height: lineHeight - 6).fill()
        }
    }

    private func selectedColumns(onLine line: Int) -> (start: Int, end: Int)? {
        guard let range = normalizedSelectionRange(), line >= range.start.line, line <= range.end.line else {
            return nil
        }

        let lineLength = buffer.lineText(at: line).count
        if range.start.line == range.end.line {
            return (
                min(range.start.column, lineLength),
                min(range.end.column, lineLength)
            )
        }

        if line == range.start.line {
            return (min(range.start.column, lineLength), lineLength)
        }

        if line == range.end.line {
            return (0, min(range.end.column, lineLength))
        }

        return (0, lineLength)
    }

    private func findMatches(onLine line: Int) -> [FindMatch] {
        findMatches.filter { $0.line == line }
    }

    var hasFindQuery: Bool {
        !findQuery.isEmpty
    }

    var hasSelection: Bool {
        normalizedSelectionRange() != nil
    }

    var canUndoEdit: Bool {
        !undoStack.isEmpty
    }

    var canRedoEdit: Bool {
        !redoStack.isEmpty
    }

    func performUndoCommand() {
        undo()
    }

    func performRedoCommand() {
        redo()
    }

    func performCutCommand() {
        cutSelectionToPasteboard()
    }

    func performCopyCommand() {
        _ = copySelectionToPasteboard()
    }

    func performPasteCommand() {
        pasteFromClipboard()
    }

    func performSelectAllCommand() {
        selectAll()
    }

    @discardableResult
    func setFindQuery(_ query: String) -> Int {
        findQuery = query
        findMatches.removeAll(keepingCapacity: true)
        activeFindMatchIndex = nil
        guard !query.isEmpty, !query.contains("\n") else {
            setNeedsDisplay(bounds)
            return 0
        }

        buffer.ensureFullyIndexed()
        resizeForBuffer()
        for line in 0..<buffer.lineCount {
            findMatches.append(contentsOf: matches(for: query, onLine: line))
        }

        if !findMatches.isEmpty {
            let reference = currentPosition()
            let index = findMatches.firstIndex {
                $0.line > reference.line || ($0.line == reference.line && $0.startColumn >= reference.column)
            } ?? 0
            activateFindMatch(at: index)
        } else {
            setNeedsDisplay(bounds)
        }
        return findMatches.count
    }

    @discardableResult
    func findNextMatch() -> Bool {
        guard !findMatches.isEmpty else {
            return false
        }
        let nextIndex = activeFindMatchIndex.map { ($0 + 1) % findMatches.count } ?? 0
        activateFindMatch(at: nextIndex)
        return true
    }

    @discardableResult
    func findPreviousMatch() -> Bool {
        guard !findMatches.isEmpty else {
            return false
        }
        let previousIndex = activeFindMatchIndex.map { ($0 - 1 + findMatches.count) % findMatches.count } ?? (findMatches.count - 1)
        activateFindMatch(at: previousIndex)
        return true
    }

    private func matches(for query: String, onLine line: Int) -> [FindMatch] {
        let text = buffer.lineText(at: line)
        guard !text.isEmpty else {
            return []
        }

        var results: [FindMatch] = []
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(of: query, options: [], range: searchStart..<text.endIndex) {
            let startColumn = text.distance(from: text.startIndex, to: range.lowerBound)
            let endColumn = text.distance(from: text.startIndex, to: range.upperBound)
            results.append(FindMatch(line: line, startColumn: startColumn, endColumn: endColumn))
            searchStart = range.upperBound
        }
        return results
    }

    private func activateFindMatch(at index: Int) {
        guard findMatches.indices.contains(index) else {
            return
        }
        activeFindMatchIndex = index
        let match = findMatches[index]
        setSelection(
            anchor: TextPosition(line: match.line, column: match.startColumn),
            active: TextPosition(line: match.line, column: match.endColumn)
        )
        scrollCaretToVisible()
        setNeedsDisplay(enclosingScrollView?.contentView.bounds ?? bounds)
    }

    private func visibleLineCount() -> Int {
        let height = enclosingScrollView?.contentView.bounds.height ?? 700
        return max(1, Int(height / lineHeight))
    }

    private func moveCharacterLeft(extending: Bool = false) {
        if caretColumn > 0 {
            moveCaret(line: caretLine, column: caretColumn - 1, extending: extending)
        } else if caretLine > 0 {
            let previousLine = caretLine - 1
            moveCaret(line: previousLine, column: buffer.lineText(at: previousLine).count, extending: extending)
        }
    }

    private func moveCharacterRight(extending: Bool = false) {
        let lineLength = buffer.lineText(at: caretLine).count
        if caretColumn < lineLength {
            moveCaret(line: caretLine, column: caretColumn + 1, extending: extending)
        } else if caretLine + 1 < buffer.lineCount {
            moveCaret(line: caretLine + 1, column: 0, extending: extending)
        }
    }

    private func moveLineUp(extending: Bool = false) {
        moveCaret(line: caretLine - 1, column: caretColumn, extending: extending)
    }

    private func moveLineDown(extending: Bool = false) {
        moveCaret(line: caretLine + 1, column: caretColumn, extending: extending)
    }

    private func movePageUp(extending: Bool = false) {
        moveCaret(line: caretLine - visibleLineCount(), column: caretColumn, extending: extending)
    }

    private func movePageDown(extending: Bool = false) {
        moveCaret(line: caretLine + visibleLineCount(), column: caretColumn, extending: extending)
    }

    private func moveToLineStart(extending: Bool = false) {
        moveCaret(line: caretLine, column: 0, extending: extending)
    }

    private func moveToLineEnd(extending: Bool = false) {
        moveCaret(line: caretLine, column: buffer.lineText(at: caretLine).count, extending: extending)
    }

    private func moveToFileStart(extending: Bool = false) {
        moveCaret(line: 0, column: caretColumn, extending: extending)
    }

    private func moveToFileEnd(extending: Bool = false) {
        let lastLine = buffer.lineCount - 1
        moveCaret(line: lastLine, column: caretColumn, extending: extending)
    }

    private func moveWordLeft(extending: Bool = false) {
        if caretColumn == 0 {
            guard caretLine > 0 else { return }
            let previousLine = caretLine - 1
            moveCaret(line: previousLine, column: buffer.lineText(at: previousLine).count, extending: extending)
            return
        }

        let line = buffer.lineText(at: caretLine)
        let target = wordBoundaryLeft(in: line, from: caretColumn)
        moveCaret(line: caretLine, column: target, extending: extending)
    }

    private func moveWordRight(extending: Bool = false) {
        let line = buffer.lineText(at: caretLine)
        if caretColumn >= line.count {
            guard caretLine + 1 < buffer.lineCount else { return }
            moveCaret(line: caretLine + 1, column: 0, extending: extending)
            return
        }

        let target = wordBoundaryRight(in: line, from: caretColumn)
        moveCaret(line: caretLine, column: target, extending: extending)
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

    private func currentPosition() -> TextPosition {
        TextPosition(line: caretLine, column: caretColumn)
    }

    private func normalizedSelectionRange() -> (start: TextPosition, end: TextPosition)? {
        guard let anchor = selectionAnchor, let active = selectionActive, anchor != active else {
            return nil
        }
        return anchor < active ? (anchor, active) : (active, anchor)
    }

    private func clearSelection() {
        selectionAnchor = nil
        selectionActive = nil
    }

    private func setSelection(anchor: TextPosition, active: TextPosition) {
        if anchor == active {
            clearSelection()
        } else {
            selectionAnchor = anchor
            selectionActive = active
        }
        caretLine = active.line
        caretColumn = active.column
        setNeedsDisplay(enclosingScrollView?.contentView.bounds ?? bounds)
    }

    private func position(for point: NSPoint) -> TextPosition {
        let line = Int(floor(point.y / lineHeight))
        let column = Int(round((point.x - gutterWidth - horizontalPadding) / charWidth))
        return clampedPosition(line: line, column: column)
    }

    private func clampedPosition(line: Int, column: Int) -> TextPosition {
        if line >= buffer.indexedLineCount && !buffer.isFullyIndexed {
            buffer.ensureFullyIndexed()
            resizeForBuffer()
        }
        let safeLine = min(max(0, line), buffer.lineCount - 1)
        let safeColumn = min(max(0, column), buffer.lineText(at: safeLine).count)
        return TextPosition(line: safeLine, column: safeColumn)
    }

    private func selectWord(at position: TextPosition) {
        let line = buffer.lineText(at: position.line)
        let characters = Array(line)
        guard position.column < characters.count, isWordCharacter(characters[position.column]) else {
            moveCaret(line: position.line, column: position.column)
            return
        }

        var start = position.column
        while start > 0, isWordCharacter(characters[start - 1]) {
            start -= 1
        }

        var end = position.column
        while end < characters.count, isWordCharacter(characters[end]) {
            end += 1
        }

        setSelection(
            anchor: TextPosition(line: position.line, column: start),
            active: TextPosition(line: position.line, column: end)
        )
    }

    private func selectLine(at line: Int) {
        let safeLine = min(max(0, line), buffer.lineCount - 1)
        setSelection(
            anchor: TextPosition(line: safeLine, column: 0),
            active: TextPosition(line: safeLine, column: buffer.lineText(at: safeLine).count)
        )
    }

    private func selectionDescription() -> String {
        guard let range = normalizedSelectionRange() else { return "none" }
        return "\(range.start.line):\(range.start.column)-\(range.end.line):\(range.end.column)"
    }

    private func selectedText() -> String? {
        guard let range = normalizedSelectionRange() else {
            return nil
        }
        return buffer.text(in: range)
    }

    @discardableResult
    private func copySelectionToPasteboard() -> Bool {
        guard let text = selectedText(), !text.isEmpty else {
            return false
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    private func cutSelectionToPasteboard() {
        guard copySelectionToPasteboard() else {
            return
        }
        applyEdit(affectedLines: selectionLineRange() ?? caretLine...caretLine) {
            deleteSelectionIfNeeded() ?? (caretLine, caretColumn)
        }
    }

    private func selectAll() {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        let lastLine = max(0, buffer.lineCount - 1)
        let end = TextPosition(line: lastLine, column: buffer.lineText(at: lastLine).count)
        setSelection(anchor: TextPosition(line: 0, column: 0), active: end)
    }

    private func deleteSelectionIfNeeded() -> (line: Int, column: Int)? {
        guard let range = normalizedSelectionRange() else {
            return nil
        }
        let position = buffer.delete(in: range)
        return (position.line, position.column)
    }

    private func replaceSelection(with text: String) -> (line: Int, column: Int) {
        if let range = normalizedSelectionRange() {
            let start = buffer.delete(in: range)
            guard !text.isEmpty else {
                return (start.line, start.column)
            }
            return buffer.insertText(text, atLine: start.line, column: start.column)
        }
        return buffer.insertText(text, atLine: caretLine, column: caretColumn)
    }

    private func currentSelectionState() -> SelectionState {
        SelectionState(anchor: selectionAnchor, active: selectionActive)
    }

    private func restoreSelectionState(_ state: SelectionState) {
        selectionAnchor = state.anchor
        selectionActive = state.active
    }

    private func selectionLineRange() -> ClosedRange<Int>? {
        guard let range = normalizedSelectionRange() else {
            return nil
        }
        return range.start.line...range.end.line
    }

    private func backwardDeleteLineRange() -> ClosedRange<Int> {
        if let range = selectionLineRange() {
            return range
        }
        if caretColumn == 0, caretLine > 0 {
            return (caretLine - 1)...caretLine
        }
        return caretLine...caretLine
    }

    private func forwardDeleteLineRange() -> ClosedRange<Int> {
        if let range = selectionLineRange() {
            return range
        }
        if caretColumn >= buffer.lineText(at: caretLine).count, caretLine + 1 < buffer.lineCount {
            return caretLine...(caretLine + 1)
        }
        return caretLine...caretLine
    }

    private func clampedLineSpan(_ lines: ClosedRange<Int>) -> (start: Int, count: Int) {
        if lines.upperBound >= buffer.indexedLineCount && !buffer.isFullyIndexed {
            buffer.ensureFullyIndexed()
            resizeForBuffer()
        }
        let start = min(max(0, lines.lowerBound), buffer.lineCount - 1)
        let end = min(max(start, lines.upperBound), buffer.lineCount - 1)
        return (start, end - start + 1)
    }

    private func recordUndoEntry(_ entry: UndoEntry) {
        redoStack.removeAll(keepingCapacity: true)
        if entry.coalescesTyping,
           var previous = undoStack.last,
           previous.coalescesTyping,
           previous.startLine == entry.startLine,
           previous.afterCaret == entry.beforeCaret,
           previous.afterSelection == entry.beforeSelection {
            previous.afterLines = entry.afterLines
            previous.afterCaret = entry.afterCaret
            previous.afterSelection = entry.afterSelection
            undoStack[undoStack.count - 1] = previous
            return
        }
        undoStack.append(entry)
    }

    private func applyEdit(
        affectedLines: ClosedRange<Int>? = nil,
        coalescesTyping: Bool = false,
        _ operation: () -> (line: Int, column: Int)
    ) {
        let oldLine = caretLine
        let hadSelection = normalizedSelectionRange() != nil
        let beforeCaret = currentPosition()
        let beforeSelection = currentSelectionState()
        let beforeLineCount = buffer.lineCount
        let span = clampedLineSpan(affectedLines ?? oldLine...oldLine)
        let beforeLines = buffer.lines(start: span.start, count: span.count)

        let result = operation()
        caretLine = result.line
        caretColumn = result.column
        clearSelection()
        let afterCaret = currentPosition()
        let afterSelection = currentSelectionState()
        let afterCount = max(1, beforeLines.count + buffer.lineCount - beforeLineCount)
        let afterLines = buffer.lines(start: span.start, count: afterCount)
        let changedText = beforeLines != afterLines
        if changedText {
            recordUndoEntry(UndoEntry(
                startLine: span.start,
                beforeLines: beforeLines,
                afterLines: afterLines,
                beforeCaret: beforeCaret,
                afterCaret: afterCaret,
                beforeSelection: beforeSelection,
                afterSelection: afterSelection,
                coalescesTyping: coalescesTyping
            ))
            onEdit?()
        }

        if hadSelection {
            attributedLineCache.removeAll(keepingCapacity: true)
        } else {
            attributedLineCache.removeValue(forKey: oldLine)
            attributedLineCache.removeValue(forKey: caretLine)
        }
        resizeForBuffer()
        scrollCaretToVisible()
        if hadSelection {
            setNeedsDisplay(bounds)
        } else {
            markLinesDirty(oldLine, caretLine)
        }
    }

    private func undo() {
        guard let entry = undoStack.popLast() else {
            return
        }
        applyHistory(entry, restoringBeforeState: true)
        redoStack.append(entry)
    }

    private func redo() {
        guard let entry = redoStack.popLast() else {
            return
        }
        applyHistory(entry, restoringBeforeState: false)
        undoStack.append(entry)
    }

    private func applyHistory(_ entry: UndoEntry, restoringBeforeState: Bool) {
        let oldLine = caretLine
        if restoringBeforeState {
            buffer.replaceLines(start: entry.startLine, removeCount: entry.afterLines.count, with: entry.beforeLines)
            caretLine = entry.beforeCaret.line
            caretColumn = entry.beforeCaret.column
            restoreSelectionState(entry.beforeSelection)
        } else {
            buffer.replaceLines(start: entry.startLine, removeCount: entry.beforeLines.count, with: entry.afterLines)
            caretLine = entry.afterCaret.line
            caretColumn = entry.afterCaret.column
            restoreSelectionState(entry.afterSelection)
        }
        attributedLineCache.removeAll(keepingCapacity: true)
        resizeForBuffer()
        scrollCaretToVisible()
        setNeedsDisplay(bounds)
        markLinesDirty(oldLine, caretLine)
        onEdit?()
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
        clearSelection()
        undoStack.removeAll(keepingCapacity: true)
        redoStack.removeAll(keepingCapacity: true)
        attributedLineCache.removeAll(keepingCapacity: true)
        resizeForBuffer()
        setNeedsDisplay(bounds)
        displayIfNeeded()
    }

    var currentFontSize: CGFloat {
        font.pointSize
    }

    func applyPreferences() {
        let fontSize = EditorPreferences.fontSize
        font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        lineNumberFont = NSFont.monospacedSystemFont(ofSize: max(10, fontSize - 1), weight: .regular)
        lineHeight = ceil(font.ascender - font.descender + font.leading) + 11
        charWidth = max(1, "W".size(withAttributes: [.font: font]).width)
        let digits = max(2, String(buffer.lineCount).count)
        gutterWidth = CGFloat(digits) * max(1, "8".size(withAttributes: [.font: lineNumberFont]).width) + 18
        attributedLineCache.removeAll(keepingCapacity: true)
        resizeForBuffer()
        setNeedsDisplay(bounds)
    }

    func goToLine(_ oneBasedLine: Int) {
        moveCaret(line: max(0, oneBasedLine - 1), column: 0)
    }

    private func moveCaret(line: Int, column: Int, extending: Bool = false) {
        let oldLine = caretLine
        let oldPosition = currentPosition()
        let hadSelection = normalizedSelectionRange() != nil
        let nextPosition = clampedPosition(line: line, column: column)
        caretLine = nextPosition.line
        caretColumn = nextPosition.column
        if extending {
            setSelection(anchor: selectionAnchor ?? oldPosition, active: nextPosition)
        } else {
            clearSelection()
        }
        scrollCaretToVisible()
        markLinesDirty(oldLine, caretLine)
        if extending || hadSelection || selectionAnchor != nil {
            setNeedsDisplay(enclosingScrollView?.contentView.bounds ?? bounds)
        }
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

    func benchmarkCaretPosition() -> TextPosition {
        currentPosition()
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

        func keyEvent(
            flags: NSEvent.ModifierFlags,
            keyCode: UInt16
        ) -> NSEvent {
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: keyCode
            )!
        }

        func expect(_ label: String, line expectedLine: Int, column expectedColumn: Int) {
            if caretLine != expectedLine || caretColumn != expectedColumn {
                failures.append("\(label): expected \(expectedLine):\(expectedColumn), got \(caretLine):\(caretColumn)")
            }
        }

        moveCaret(line: 0, column: 0)
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
        expect("file end", line: 2, column: 0)

        moveCharacterRight()
        expect("character right at file-edge column", line: 2, column: 1)

        moveCaret(line: 0, column: 0)
        movePageDown()
        expect("page down clamps to file end line", line: 2, column: 0)

        movePageUp()
        expect("page up clamps to file start line", line: 0, column: 0)

        moveCaret(line: 1, column: 6)
        keyDown(with: keyEvent(flags: .command, keyCode: 125))
        expect("command down preserves file-edge column", line: 2, column: 6)

        keyDown(with: keyEvent(flags: .command, keyCode: 126))
        expect("command up preserves file-edge column", line: 0, column: 6)

        moveCaret(line: 1, column: 15)
        keyDown(with: keyEvent(flags: .command, keyCode: 125))
        expect("command down clamps preserved column", line: 2, column: 9)

        return failures
    }

    func benchmarkHorizontalCaretVisibility(viewport: NSSize) -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()

        let scrollView = NSScrollView(frame: NSRect(origin: .zero, size: viewport))
        scrollView.contentView = EditorClipView(frame: scrollView.contentView.frame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = self
        attach(to: scrollView)
        resizeForBuffer()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        var failures: [String] = []
        let firstLineLength = buffer.lineText(at: 0).count
        if firstLineLength < 120 {
            failures.append("fixture first line must be long enough to exceed the initial viewport, got \(firstLineLength) columns")
        }
        if bounds.width <= scrollView.contentView.bounds.width {
            failures.append("document view must be wider than viewport for horizontal caret benchmark")
        }

        func keyEvent(flags: NSEvent.ModifierFlags, keyCode: UInt16) -> NSEvent {
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: keyCode
            )!
        }

        func caretIsVisible(in visible: NSRect) -> Bool {
            visible.insetBy(dx: -4, dy: -2).intersects(caretRect())
        }

        moveCaret(line: 0, column: 0)
        let initialVisible = scrollView.contentView.bounds
        keyDown(with: keyEvent(flags: .command, keyCode: 124))
        let afterCommandRight = scrollView.contentView.bounds
        if caretColumn != firstLineLength {
            failures.append("command-right should move caret to line end \(firstLineLength), got \(caretColumn)")
        }
        if afterCommandRight.minX <= initialVisible.minX {
            failures.append("command-right should scroll horizontally when line end is offscreen")
        }
        if !caretIsVisible(in: afterCommandRight) {
            failures.append("caret should be visible after command-right; visible=\(NSStringFromRect(afterCommandRight)) caret=\(NSStringFromRect(caretRect()))")
        }

        let highlight = currentLineHighlightRect(in: afterCommandRight)
        if highlight.minX > afterCommandRight.minX || highlight.maxX < afterCommandRight.maxX {
            failures.append("current-line highlight should cover the horizontal viewport; visible=\(NSStringFromRect(afterCommandRight)) highlight=\(NSStringFromRect(highlight))")
        }

        let lineNumberAttributes: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor
        ]
        let lineNumber = lineNumberRect(for: 0, in: afterCommandRight, attributes: lineNumberAttributes)
        let expectedMaxX = afterCommandRight.minX + gutterWidth - 8
        if abs(lineNumber.maxX - expectedMaxX) > 1 {
            failures.append("line number should stay sticky at x=\(expectedMaxX), got \(lineNumber.maxX)")
        }

        moveCaret(line: 0, column: min(firstLineLength, 80))
        let caretBehindGutterX = max(0, caretRect().minX - (gutterWidth / 2))
        scrollView.contentView.scroll(to: NSPoint(x: caretBehindGutterX, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        let behindGutterVisible = scrollView.contentView.bounds
        let stickyGutter = NSRect(
            x: behindGutterVisible.minX,
            y: behindGutterVisible.minY,
            width: gutterWidth,
            height: behindGutterVisible.height
        )
        if !stickyGutter.intersects(caretRect()) {
            failures.append("benchmark setup should place caret under sticky gutter; visible=\(NSStringFromRect(behindGutterVisible)) caret=\(NSStringFromRect(caretRect()))")
        }
        if visibleCaretRect(in: behindGutterVisible) != nil {
            failures.append("caret should not draw through sticky line-number gutter")
        }

        let clickColumn = Int(round((afterCommandRight.midX - gutterWidth - horizontalPadding) / charWidth))
        moveCaret(line: 0, column: clickColumn)
        if !caretIsVisible(in: scrollView.contentView.bounds) {
            failures.append("clicked caret should remain visible in horizontally scrolled viewport")
        }

        return failures
    }

    func benchmarkSelectionModel() -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        var failures: [String] = []

        func expect(_ label: String, _ expected: String) {
            let actual = selectionDescription()
            if actual != expected {
                failures.append("\(label): expected \(expected), got \(actual)")
            }
        }

        func expectColumns(_ label: String, line: Int, start: Int, end: Int) {
            guard let columns = selectedColumns(onLine: line) else {
                failures.append("\(label): expected \(start)-\(end), got none")
                return
            }
            if columns.start != start || columns.end != end {
                failures.append("\(label): expected \(start)-\(end), got \(columns.start)-\(columns.end)")
            }
        }

        moveCaret(line: 0, column: 0)
        moveCharacterRight(extending: true)
        expect("shift right", "0:0-0:1")

        moveCaret(line: 0, column: 0)
        moveWordRight(extending: true)
        expect("shift option right", "0:0-0:5")

        moveWordRight(extending: true)
        expect("shift option right second word", "0:0-0:10")

        moveCaret(line: 0, column: 0)
        moveToLineEnd(extending: true)
        expect("shift command right", "0:0-0:16")

        moveCaret(line: 0, column: 0)
        moveToFileEnd(extending: true)
        expect("shift command down", "0:0-2:0")

        moveCaret(line: 0, column: 0)
        moveCaret(line: 1, column: 8, extending: true)
        expect("mouse drag style multiline", "0:0-1:8")

        selectWord(at: TextPosition(line: 0, column: 7))
        expect("double-click word", "0:6-0:10")

        selectLine(at: 1)
        expect("triple-click line", "1:0-1:19")

        moveCaret(line: 2, column: 4)
        expect("plain click clears selection", "none")

        setSelection(anchor: TextPosition(line: 0, column: 6), active: TextPosition(line: 2, column: 4))
        expectColumns("selection columns line 0", line: 0, start: 6, end: 16)
        expectColumns("selection columns line 1", line: 1, start: 0, end: 19)
        expectColumns("selection columns line 2", line: 2, start: 0, end: 4)

        return failures
    }

    func benchmarkSelectionEditing() -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        var failures: [String] = []
        var editCount = 0
        onEdit = { editCount += 1 }

        let pasteboard = NSPasteboard.general
        let previousClipboard = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let previousClipboard {
                pasteboard.setString(previousClipboard, forType: .string)
            }
        }

        func expect(_ actual: String, _ expected: String, _ label: String) {
            if actual != expected {
                failures.append("\(label): expected \(expected), got \(actual)")
            }
        }

        func expectLine(_ line: Int, _ expected: String, _ label: String) {
            expect(buffer.lineText(at: line), expected, label)
        }

        func expectSelection(_ expected: String, _ label: String) {
            expect(selectionDescription(), expected, label)
        }

        func expectClipboard(_ expected: String, _ label: String) {
            expect(pasteboard.string(forType: .string) ?? "", expected, label)
        }

        func keyEvent(
            characters: String,
            ignoring: String,
            flags: NSEvent.ModifierFlags = [],
            keyCode: UInt16
        ) -> NSEvent {
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: ignoring,
                isARepeat: false,
                keyCode: keyCode
            )!
        }

        func command(_ character: String, keyCode: UInt16) {
            keyDown(with: keyEvent(characters: character, ignoring: character, flags: .command, keyCode: keyCode))
        }

        func type(_ text: String) {
            keyDown(with: keyEvent(characters: text, ignoring: text, keyCode: 0))
        }

        func backspace() {
            keyDown(with: keyEvent(characters: "", ignoring: "", keyCode: 51))
        }

        command("a", keyCode: 0)
        expectSelection("0:0-2:8", "command-a selects all")

        command("c", keyCode: 8)
        expectClipboard("one two\nthree four\nfive six", "command-c copies multiline selection")
        if editCount != 0 {
            failures.append("copy should not dirty document")
        }

        setSelection(anchor: TextPosition(line: 0, column: 4), active: TextPosition(line: 0, column: 7))
        type("TWO")
        expectLine(0, "one TWO", "typing replaces single-line selection")
        expectSelection("none", "typing clears selection")
        if editCount != 1 {
            failures.append("typing replacement should dirty document once, got \(editCount)")
        }

        pasteboard.clearContents()
        pasteboard.setString("alpha\nbeta", forType: .string)
        setSelection(anchor: TextPosition(line: 0, column: 4), active: TextPosition(line: 1, column: 5))
        command("v", keyCode: 9)
        expectLine(0, "one alpha", "paste replacement first line")
        expectLine(1, "beta four", "paste replacement second line")
        expectLine(2, "five six", "paste replacement keeps suffix line")
        expectSelection("none", "paste clears selection")

        let editsBeforeCut = editCount
        setSelection(anchor: TextPosition(line: 1, column: 0), active: TextPosition(line: 1, column: 4))
        command("x", keyCode: 7)
        expectClipboard("beta", "command-x copies selection")
        expectLine(1, " four", "command-x deletes selection")
        if editCount != editsBeforeCut + 1 {
            failures.append("cut should dirty document once")
        }

        let editsBeforeDelete = editCount
        setSelection(anchor: TextPosition(line: 0, column: 4), active: TextPosition(line: 1, column: 1))
        backspace()
        expectLine(0, "one four", "backspace deletes multiline selection")
        expectLine(1, "five six", "backspace shifts following line")
        expectSelection("none", "backspace clears selection")
        if editCount != editsBeforeDelete + 1 {
            failures.append("selection delete should dirty document once")
        }

        command("a", keyCode: 0)
        expectSelection("0:0-1:8", "command-a updates after multiline edit")

        return failures
    }

    func benchmarkLargeSelectAll() -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        let lastLine = max(0, buffer.lineCount - 1)
        let expected = "0:0-\(lastLine):\(buffer.lineText(at: lastLine).count)"
        selectAll()
        guard selectionDescription() == expected else {
            return ["large select all: expected \(expected), got \(selectionDescription())"]
        }
        return []
    }

    func benchmarkUndoRedo() -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        var failures: [String] = []

        let pasteboard = NSPasteboard.general
        let previousClipboard = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let previousClipboard {
                pasteboard.setString(previousClipboard, forType: .string)
            }
        }

        func expect(_ actual: String, _ expected: String, _ label: String) {
            if actual != expected {
                failures.append("\(label): expected \(expected), got \(actual)")
            }
        }

        func expectLine(_ line: Int, _ expected: String, _ label: String) {
            expect(buffer.lineText(at: line), expected, label)
        }

        func keyEvent(
            characters: String,
            ignoring: String,
            flags: NSEvent.ModifierFlags = [],
            keyCode: UInt16
        ) -> NSEvent {
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: characters,
                charactersIgnoringModifiers: ignoring,
                isARepeat: false,
                keyCode: keyCode
            )!
        }

        func command(_ character: String, keyCode: UInt16, shift: Bool = false) {
            let flags: NSEvent.ModifierFlags = shift ? [.command, .shift] : .command
            keyDown(with: keyEvent(characters: character, ignoring: character, flags: flags, keyCode: keyCode))
        }

        func type(_ text: String) {
            keyDown(with: keyEvent(characters: text, ignoring: text, keyCode: 0))
        }

        func enter() {
            keyDown(with: keyEvent(characters: "\r", ignoring: "\r", keyCode: 36))
        }

        moveCaret(line: 0, column: 0)
        type("X")
        type("Y")
        type("Z")
        expectLine(0, "XYZalpha beta", "typing burst applies")
        if undoStack.count != 1 {
            failures.append("typing burst should coalesce to one undo entry, got \(undoStack.count)")
        }
        command("z", keyCode: 6)
        expectLine(0, "alpha beta", "undo typing burst")
        expect(selectionDescription(), "none", "undo typing selection")
        command("z", keyCode: 6, shift: true)
        expectLine(0, "XYZalpha beta", "redo typing burst")

        pasteboard.clearContents()
        pasteboard.setString("one\ntwo", forType: .string)
        command("v", keyCode: 9)
        expectLine(0, "XYZone", "paste first line")
        expectLine(1, "twoalpha beta", "paste second line")
        command("z", keyCode: 6)
        expectLine(0, "XYZalpha beta", "undo paste first line")
        expectLine(1, "gamma delta", "undo paste restores next line")
        command("z", keyCode: 6, shift: true)
        expectLine(0, "XYZone", "redo paste first line")
        expectLine(1, "twoalpha beta", "redo paste second line")

        setSelection(anchor: TextPosition(line: 0, column: 3), active: TextPosition(line: 1, column: 3))
        type("Q")
        expectLine(0, "XYZQalpha beta", "selection replacement applies")
        expectLine(1, "gamma delta", "selection replacement removes second selected line")
        command("z", keyCode: 6)
        expectLine(0, "XYZone", "undo selection replacement first line")
        expectLine(1, "twoalpha beta", "undo selection replacement second line")
        command("z", keyCode: 6, shift: true)
        expectLine(0, "XYZQalpha beta", "redo selection replacement")

        setSelection(anchor: TextPosition(line: 0, column: 3), active: TextPosition(line: 0, column: 4))
        command("x", keyCode: 7)
        expectLine(0, "XYZalpha beta", "cut deletes selection")
        expect(pasteboard.string(forType: .string) ?? "", "Q", "cut copies selection")
        command("z", keyCode: 6)
        expectLine(0, "XYZQalpha beta", "undo cut")
        command("z", keyCode: 6, shift: true)
        expectLine(0, "XYZalpha beta", "redo cut")

        moveCaret(line: 0, column: 3)
        enter()
        expectLine(0, "XYZ", "newline first line")
        expectLine(1, "alpha beta", "newline second line")
        command("z", keyCode: 6)
        expectLine(0, "XYZalpha beta", "undo newline")
        command("z", keyCode: 6, shift: true)
        expectLine(0, "XYZ", "redo newline first line")
        expectLine(1, "alpha beta", "redo newline second line")

        return failures
    }

    func benchmarkLargeBottomUndoRedo() -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        let lastLine = max(0, buffer.lineCount - 1)
        let original = buffer.lineText(at: lastLine)
        moveCaret(line: lastLine, column: original.count)
        applyEdit(affectedLines: lastLine...lastLine, coalescesTyping: true) {
            buffer.insert("z", atLine: caretLine, column: caretColumn)
        }
        guard buffer.lineText(at: lastLine) == original + "z" else {
            return ["large bottom insert did not apply"]
        }
        undo()
        guard buffer.lineText(at: lastLine) == original else {
            return ["large bottom undo did not restore original line"]
        }
        redo()
        guard buffer.lineText(at: lastLine) == original + "z" else {
            return ["large bottom redo did not restore inserted text"]
        }
        undo()
        guard buffer.lineText(at: lastLine) == original else {
            return ["large bottom second undo did not restore original line"]
        }
        return []
    }

    func benchmarkFind() -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        var failures: [String] = []

        func expect(_ actual: String, _ expected: String, _ label: String) {
            if actual != expected {
                failures.append("\(label): expected \(expected), got \(actual)")
            }
        }

        func expectColumns(_ line: Int, _ expected: [(Int, Int)], _ label: String) {
            let actual = findMatches(onLine: line).map { ($0.startColumn, $0.endColumn) }
            guard actual.count == expected.count else {
                failures.append("\(label): expected \(expected), got \(actual)")
                return
            }
            for index in expected.indices where actual[index] != expected[index] {
                failures.append("\(label): expected \(expected), got \(actual)")
                return
            }
        }

        moveCaret(line: 0, column: 0)
        let alphaCount = setFindQuery("alpha")
        if alphaCount != 3 {
            failures.append("alpha match count: expected 3, got \(alphaCount)")
        }
        expect(selectionDescription(), "0:0-0:5", "initial alpha selection")
        expectColumns(2, [(0, 5), (11, 16)], "visible alpha match columns")

        _ = findNextMatch()
        expect(selectionDescription(), "2:0-2:5", "find next wraps to second line")
        _ = findNextMatch()
        expect(selectionDescription(), "2:11-2:16", "find next advances on same line")
        _ = findNextMatch()
        expect(selectionDescription(), "0:0-0:5", "find next wraps to first match")
        _ = findPreviousMatch()
        expect(selectionDescription(), "2:11-2:16", "find previous wraps to last match")

        let missingCount = setFindQuery("missing")
        if missingCount != 0 {
            failures.append("missing match count: expected 0, got \(missingCount)")
        }
        expect(selectionDescription(), "2:11-2:16", "missing query preserves current selection")

        return failures
    }

    func benchmarkLargeFind() -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        var failures: [String] = []
        moveCaret(line: 0, column: 0)

        let count = setFindQuery("needle")
        if count != 3 {
            failures.append("large needle match count: expected 3, got \(count)")
        }
        if !selectionDescription().hasPrefix("99:") {
            failures.append("large initial match should be near line 100, got \(selectionDescription())")
        }
        _ = findNextMatch()
        if !selectionDescription().hasPrefix("14999:") {
            failures.append("large next match should be near line 15000, got \(selectionDescription())")
        }
        _ = findNextMatch()
        if !selectionDescription().hasPrefix("29949:") {
            failures.append("large next match should be near line 29950, got \(selectionDescription())")
        }
        _ = findPreviousMatch()
        if !selectionDescription().hasPrefix("14999:") {
            failures.append("large previous match should return near line 15000, got \(selectionDescription())")
        }
        return failures
    }

    func benchmarkNativeMenuCommands() -> [String] {
        buffer.ensureFullyIndexed()
        resizeForBuffer()
        var failures: [String] = []

        let pasteboard = NSPasteboard.general
        let previousClipboard = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let previousClipboard {
                pasteboard.setString(previousClipboard, forType: .string)
            }
        }

        func expect(_ actual: String, _ expected: String, _ label: String) {
            if actual != expected {
                failures.append("\(label): expected \(expected), got \(actual)")
            }
        }

        func expectLine(_ line: Int, _ expected: String, _ label: String) {
            expect(buffer.lineText(at: line), expected, label)
        }

        moveCaret(line: 0, column: 5)
        applyEdit(affectedLines: 0...0, coalescesTyping: true) {
            buffer.insert("!", atLine: caretLine, column: caretColumn)
        }
        expectLine(0, "alpha! beta", "menu benchmark edit applies")
        performUndoCommand()
        expectLine(0, "alpha beta", "menu undo")
        performRedoCommand()
        expectLine(0, "alpha! beta", "menu redo")

        setSelection(anchor: TextPosition(line: 0, column: 0), active: TextPosition(line: 0, column: 5))
        performCopyCommand()
        expect(pasteboard.string(forType: .string) ?? "", "alpha", "menu copy")

        performCutCommand()
        expectLine(0, "! beta", "menu cut")
        performUndoCommand()
        expectLine(0, "alpha! beta", "undo menu cut")

        pasteboard.clearContents()
        pasteboard.setString("PASTE", forType: .string)
        moveCaret(line: 1, column: 5)
        performPasteCommand()
        expectLine(1, "gammaPASTE delta", "menu paste")

        performSelectAllCommand()
        expect(selectionDescription(), "0:0-1:16", "menu select all")

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

    private func scrollCaretToVisible() {
        guard let scrollView = enclosingScrollView else { return }
        let visible = scrollView.contentView.bounds
        let textViewport = textViewportRect(in: visible)
        let targetRect = caretRect().insetBy(dx: -horizontalPadding, dy: -4)
        let maxX = max(0, bounds.width - visible.width)
        let maxY = max(0, bounds.height - visible.height)
        var target = visible.origin

        if targetRect.minX < textViewport.minX {
            target.x = targetRect.minX - gutterWidth
        } else if targetRect.maxX > textViewport.maxX {
            target.x = targetRect.maxX - visible.width
        }

        if targetRect.minY < visible.minY {
            target.y = targetRect.minY
        } else if targetRect.maxY > visible.maxY {
            target.y = targetRect.maxY - visible.height
        }

        target.x = min(max(0, target.x), maxX)
        target.y = min(max(0, target.y), maxY)
        if abs(target.x - visible.minX) > 0.5 || abs(target.y - visible.minY) > 0.5 {
            scrollView.contentView.scroll(to: target)
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
        if requestedEndLine >= buffer.indexedLineCount, !buffer.isFullyIndexed {
            buffer.ensureFullyIndexed()
            resizeForBuffer()
            indexOnScrollCount += 1
        }

        setNeedsDisplay(visibleRect)
    }

    private func resizeForBuffer() {
        let measuredColumns = max(buffer.maxLineByteCount, caretColumn + 1)
        let width = gutterWidth + horizontalPadding * 2 + CGFloat(min(measuredColumns, Self.maxLayoutColumns)) * charWidth
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
    private let rootStack = NSStackView()
    private let tabBarScrollView = NSScrollView()
    private let tabBarContentView = NSView()
    private let tabBarStack = NSStackView()
    private var tabButtonsByItem: [NSTabViewItem: NSButton] = [:]
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

    func windowDidMove(_ notification: Notification) {
        EditorPreferences.savedWindowFrame = window.frame
    }

    func windowDidResize(_ notification: Notification) {
        EditorPreferences.savedWindowFrame = window.frame
        layoutTabBar()
        scrollSelectedTabButtonIntoView()
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
        if tabView.numberOfTabViewItems == 1 {
            window.performClose(sender)
            return
        }
        close(item: item)
    }

    @objc private func selectNextTab(_ sender: Any?) {
        selectTab(offset: 1)
    }

    @objc private func selectPreviousTab(_ sender: Any?) {
        selectTab(offset: -1)
    }

    @objc private func selectTabButton(_ sender: NSButton) {
        guard let item = tabButtonsByItem.first(where: { $0.value === sender })?.key else {
            return
        }

        tabView.selectTabViewItem(item)
        if let document = selectedDocument() {
            window.makeFirstResponder(document.fileView)
        }
        updateTabButtons()
    }

    @objc private func showPreferencesPanel(_ sender: Any?) {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        field.stringValue = String(format: "%.0f", EditorPreferences.fontSize)
        field.placeholderString = "Font size"

        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = "Editor font size"
        alert.accessoryView = field
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn,
                  let self,
                  let value = Double(field.stringValue)
            else {
                return
            }
            EditorPreferences.fontSize = CGFloat(value)
            for document in self.documentsByPath.values {
                document.fileView.applyPreferences()
            }
        }
    }

    @objc private func undoEdit(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }
        document.fileView.performUndoCommand()
    }

    @objc private func redoEdit(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }
        document.fileView.performRedoCommand()
    }

    @objc private func cutSelection(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }
        document.fileView.performCutCommand()
    }

    @objc private func copySelection(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }
        document.fileView.performCopyCommand()
    }

    @objc private func pasteClipboard(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }
        document.fileView.performPasteCommand()
    }

    @objc private func selectAllText(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }
        document.fileView.performSelectAllCommand()
    }

    @objc private func showFindPanel(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "Find"

        let alert = NSAlert()
        alert.messageText = "Find in \(document.displayName)"
        alert.accessoryView = field
        alert.addButton(withTitle: "Find")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self, weak document] response in
            guard response == .alertFirstButtonReturn,
                  let self,
                  let document
            else {
                return
            }
            let count = document.fileView.setFindQuery(field.stringValue)
            if count == 0 {
                NSSound.beep()
            }
            self.window.makeFirstResponder(document.fileView)
        }
    }

    @objc private func findNextResult(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }
        guard document.fileView.hasFindQuery else {
            showFindPanel(sender)
            return
        }
        if !document.fileView.findNextMatch() {
            NSSound.beep()
        }
        window.makeFirstResponder(document.fileView)
    }

    @objc private func findPreviousResult(_ sender: Any?) {
        guard let document = selectedDocument() else {
            NSSound.beep()
            return
        }
        guard document.fileView.hasFindQuery else {
            showFindPanel(sender)
            return
        }
        if !document.fileView.findPreviousMatch() {
            NSSound.beep()
        }
        window.makeFirstResponder(document.fileView)
    }

    func tabView(_ tabView: NSTabView, willClose tabViewItem: NSTabViewItem) {
        close(item: tabViewItem)
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        updateTabButtons()
        scrollSelectedTabButtonIntoView()
        if let document = selectedDocument() {
            window.makeFirstResponder(document.fileView)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            return true
        }

        if action == #selector(openDocument(_:)) || action == #selector(showPreferencesPanel(_:)) {
            return true
        }

        if action == #selector(selectNextTab(_:)) || action == #selector(selectPreviousTab(_:)) {
            return tabView.numberOfTabViewItems > 1
        }

        guard let document = selectedDocument() else {
            return action == #selector(NSApplication.terminate(_:))
        }

        switch action {
        case #selector(saveDocument(_:)):
            return document.isDirty
        case #selector(closeCurrentTab(_:)),
             #selector(showFindPanel(_:)),
             #selector(findNextResult(_:)),
             #selector(findPreviousResult(_:)),
             #selector(selectAllText(_:)):
            return true
        case #selector(undoEdit(_:)):
            return document.fileView.canUndoEdit
        case #selector(redoEdit(_:)):
            return document.fileView.canRedoEdit
        case #selector(cutSelection(_:)),
             #selector(copySelection(_:)):
            return document.fileView.hasSelection
        case #selector(pasteClipboard(_:)):
            return NSPasteboard.general.string(forType: .string) != nil
        default:
            return true
        }
    }

    private func configureWindow() {
        window.title = "Artisan"
        window.isRestorable = false
        window.delegate = self
        if let savedFrame = EditorPreferences.savedWindowFrame {
            window.setFrame(savedFrame, display: false)
        } else {
            window.center()
        }

        rootStack.orientation = .vertical
        rootStack.alignment = .width
        rootStack.distribution = .fill
        rootStack.spacing = 0
        rootStack.frame = window.contentView?.bounds ?? window.frame
        rootStack.autoresizingMask = [.width, .height]

        tabBarScrollView.hasHorizontalScroller = true
        tabBarScrollView.hasVerticalScroller = false
        tabBarScrollView.autohidesScrollers = true
        tabBarScrollView.borderType = .noBorder
        tabBarScrollView.drawsBackground = true
        tabBarScrollView.backgroundColor = .windowBackgroundColor
        tabBarScrollView.documentView = tabBarContentView
        tabBarScrollView.isHidden = true
        tabBarScrollView.translatesAutoresizingMaskIntoConstraints = false

        tabBarStack.orientation = .horizontal
        tabBarStack.alignment = .centerY
        tabBarStack.distribution = .gravityAreas
        tabBarStack.spacing = 4
        tabBarContentView.addSubview(tabBarStack)

        tabView.tabViewType = .noTabsNoBorder
        tabView.delegate = self
        tabView.translatesAutoresizingMaskIntoConstraints = false

        if rootStack.arrangedSubviews.isEmpty {
            rootStack.addArrangedSubview(tabBarScrollView)
            rootStack.addArrangedSubview(tabView)
            tabBarScrollView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        }

        window.contentView = rootStack
        layoutTabBar()
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let fileMenuItem = NSMenuItem()
        let editMenuItem = NSMenuItem()
        let windowMenuItem = NSMenuItem()

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(fileMenuItem)
        mainMenu.addItem(editMenuItem)
        mainMenu.addItem(windowMenuItem)

        let appMenu = NSMenu()
        let preferencesItem = appMenu.addItem(withTitle: "Preferences...", action: #selector(showPreferencesPanel(_:)), keyEquivalent: ",")
        preferencesItem.target = self
        appMenu.addItem(.separator())
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

        let editMenu = NSMenu(title: "Edit")
        let undoItem = editMenu.addItem(withTitle: "Undo", action: #selector(undoEdit(_:)), keyEquivalent: "z")
        undoItem.target = self
        let redoItem = editMenu.addItem(withTitle: "Redo", action: #selector(redoEdit(_:)), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        redoItem.target = self
        editMenu.addItem(.separator())
        let cutItem = editMenu.addItem(withTitle: "Cut", action: #selector(cutSelection(_:)), keyEquivalent: "x")
        cutItem.target = self
        let copyItem = editMenu.addItem(withTitle: "Copy", action: #selector(copySelection(_:)), keyEquivalent: "c")
        copyItem.target = self
        let pasteItem = editMenu.addItem(withTitle: "Paste", action: #selector(pasteClipboard(_:)), keyEquivalent: "v")
        pasteItem.target = self
        let selectAllItem = editMenu.addItem(withTitle: "Select All", action: #selector(selectAllText(_:)), keyEquivalent: "a")
        selectAllItem.target = self
        editMenu.addItem(.separator())
        let findItem = editMenu.addItem(withTitle: "Find...", action: #selector(showFindPanel(_:)), keyEquivalent: "f")
        findItem.target = self
        let findNextItem = editMenu.addItem(withTitle: "Find Next", action: #selector(findNextResult(_:)), keyEquivalent: "g")
        findNextItem.target = self
        let findPreviousItem = editMenu.addItem(withTitle: "Find Previous", action: #selector(findPreviousResult(_:)), keyEquivalent: "g")
        findPreviousItem.keyEquivalentModifierMask = [.command, .shift]
        findPreviousItem.target = self
        editMenuItem.submenu = editMenu

        let windowMenu = NSMenu(title: "Window")
        let nextTabItem = windowMenu.addItem(withTitle: "Next Tab", action: #selector(selectNextTab(_:)), keyEquivalent: "\t")
        nextTabItem.keyEquivalentModifierMask = [.control]
        nextTabItem.target = self
        let previousTabItem = windowMenu.addItem(withTitle: "Previous Tab", action: #selector(selectPreviousTab(_:)), keyEquivalent: "\t")
        previousTabItem.keyEquivalentModifierMask = [.control, .shift]
        previousTabItem.target = self
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    func benchmarkMenuConfiguration() -> [String] {
        buildMenu()
        var failures: [String] = []

        func submenu(_ title: String) -> NSMenu? {
            NSApp.mainMenu?.items.first { $0.submenu?.title == title }?.submenu
        }

        func expectItem(
            _ menu: NSMenu?,
            title: String,
            action: Selector,
            keyEquivalent: String,
            modifiers: NSEvent.ModifierFlags = .command
        ) {
            guard let item = menu?.items.first(where: { $0.title == title }) else {
                failures.append("missing menu item \(title)")
                return
            }
            if item.action != action {
                failures.append("\(title) action mismatch")
            }
            if item.keyEquivalent != keyEquivalent {
                failures.append("\(title) key equivalent expected \(keyEquivalent), got \(item.keyEquivalent)")
            }
            if item.keyEquivalentModifierMask.intersection([.command, .shift, .option, .control]) != modifiers {
                failures.append("\(title) modifiers mismatch")
            }
        }

        let fileMenu = submenu("File")
        let editMenu = submenu("Edit")
        let windowMenu = submenu("Window")

        expectItem(fileMenu, title: "Open...", action: #selector(openDocument(_:)), keyEquivalent: "o")
        expectItem(fileMenu, title: "Save", action: #selector(saveDocument(_:)), keyEquivalent: "s")
        expectItem(fileMenu, title: "Close Tab", action: #selector(closeCurrentTab(_:)), keyEquivalent: "w")
        expectItem(editMenu, title: "Undo", action: #selector(undoEdit(_:)), keyEquivalent: "z")
        expectItem(editMenu, title: "Redo", action: #selector(redoEdit(_:)), keyEquivalent: "z", modifiers: [.command, .shift])
        expectItem(editMenu, title: "Cut", action: #selector(cutSelection(_:)), keyEquivalent: "x")
        expectItem(editMenu, title: "Copy", action: #selector(copySelection(_:)), keyEquivalent: "c")
        expectItem(editMenu, title: "Paste", action: #selector(pasteClipboard(_:)), keyEquivalent: "v")
        expectItem(editMenu, title: "Select All", action: #selector(selectAllText(_:)), keyEquivalent: "a")
        expectItem(editMenu, title: "Find...", action: #selector(showFindPanel(_:)), keyEquivalent: "f")
        expectItem(editMenu, title: "Find Next", action: #selector(findNextResult(_:)), keyEquivalent: "g")
        expectItem(editMenu, title: "Find Previous", action: #selector(findPreviousResult(_:)), keyEquivalent: "g", modifiers: [.command, .shift])
        expectItem(windowMenu, title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        expectItem(windowMenu, title: "Next Tab", action: #selector(selectNextTab(_:)), keyEquivalent: "\t", modifiers: [.control])
        expectItem(windowMenu, title: "Previous Tab", action: #selector(selectPreviousTab(_:)), keyEquivalent: "\t", modifiers: [.control, .shift])

        return failures
    }

    func benchmarkTabNavigation(directory: URL) -> [String] {
        buildMenu()
        configureWindow()
        window.setFrame(NSRect(x: 0, y: 0, width: 420, height: 260), display: false)
        var failures: [String] = []
        let paths = (0..<12).map {
            directory.appendingPathComponent(String(format: "tab-%02d.txt", $0)).path
        }
        let response = open(paths: paths, invocationID: nil)
        if !response.ok {
            failures.append("open tabs failed: \(response.message)")
            return failures
        }
        window.layoutIfNeeded()

        if tabView.numberOfTabViewItems != paths.count {
            failures.append("expected \(paths.count) tab view items, got \(tabView.numberOfTabViewItems)")
        }
        if tabButtonsByItem.count != paths.count {
            failures.append("expected \(paths.count) custom tab buttons, got \(tabButtonsByItem.count)")
        }
        if tabView.tabViewType != .noTabsNoBorder {
            failures.append("tab view should hide default overflowing tabs")
        }
        if tabBarScrollView.superview == nil {
            failures.append("scrollable tab bar should be installed in the window")
        }
        if !tabBarScrollView.hasHorizontalScroller {
            failures.append("tab bar should expose horizontal scrolling")
        }
        let contentWidth = tabBarScrollView.documentView?.frame.width ?? 0
        let visibleWidth = tabBarScrollView.contentView.bounds.width
        if contentWidth <= visibleWidth {
            failures.append("many tabs should overflow into a scrollable document width; content=\(contentWidth), visible=\(visibleWidth)")
        }

        guard !tabView.tabViewItems.isEmpty else {
            return failures
        }
        tabView.selectTabViewItem(tabView.tabViewItems[0])
        selectNextTab(nil)
        if tabView.indexOfTabViewItem(tabView.selectedTabViewItem!) != 1 {
            failures.append("ctrl-tab next should select the second tab")
        }
        selectPreviousTab(nil)
        if tabView.indexOfTabViewItem(tabView.selectedTabViewItem!) != 0 {
            failures.append("ctrl-shift-tab previous should return to the first tab")
        }
        selectPreviousTab(nil)
        if tabView.indexOfTabViewItem(tabView.selectedTabViewItem!) != tabView.numberOfTabViewItems - 1 {
            failures.append("previous tab should wrap to the last tab")
        }

        if let selected = tabView.selectedTabViewItem,
           let button = tabButtonsByItem[selected] {
            let visible = tabBarScrollView.contentView.bounds
            if !visible.insetBy(dx: -1, dy: 0).intersects(button.frame) {
                failures.append("selected overflow tab button should be scrolled into view")
            }
        } else {
            failures.append("selected tab should have a custom button")
        }

        return failures
    }

    func benchmarkOpenTargets(path: String, secondPath: String) -> [String] {
        buildMenu()
        configureWindow()
        window.setFrame(NSRect(x: 0, y: 0, width: 640, height: 360), display: false)
        var failures: [String] = []

        let targetLine = 3
        let response = open(targets: [OpenTarget(path: path, line: targetLine)], invocationID: nil)
        if !response.ok {
            failures.append("open target failed: \(response.message)")
            return failures
        }

        guard let document = documentsByPath[path] else {
            failures.append("line-target document was not registered")
            return failures
        }

        let position = document.fileView.benchmarkCaretPosition()
        if position != TextPosition(line: targetLine - 1, column: 0) {
            failures.append("line target expected \(targetLine - 1):0, got \(position.line):\(position.column)")
        }
        if tabView.numberOfTabViewItems != 1 {
            failures.append("line target should open exactly one tab, got \(tabView.numberOfTabViewItems)")
        }

        let focusResponse = open(targets: [OpenTarget(path: path, line: 1)], invocationID: nil)
        if !focusResponse.ok {
            failures.append("existing target focus failed: \(focusResponse.message)")
            return failures
        }
        if tabView.numberOfTabViewItems != 1 {
            failures.append("opening an existing path should not duplicate tabs, got \(tabView.numberOfTabViewItems)")
        }
        let focusedPosition = document.fileView.benchmarkCaretPosition()
        if focusedPosition != TextPosition(line: 0, column: 0) {
            failures.append("existing target line expected 0:0, got \(focusedPosition.line):\(focusedPosition.column)")
        }

        let secondResponse = open(paths: [secondPath], invocationID: nil)
        if !secondResponse.ok {
            failures.append("second open failed: \(secondResponse.message)")
            return failures
        }
        if tabView.numberOfTabViewItems != 2 {
            failures.append("second path should create a second tab, got \(tabView.numberOfTabViewItems)")
        }

        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        closeCurrentTab(nil)
        if tabView.numberOfTabViewItems != 1 {
            failures.append("Cmd-W with multiple tabs should close one tab, got \(tabView.numberOfTabViewItems)")
        }
        if documentsByPath[secondPath] != nil {
            failures.append("Cmd-W with multiple tabs should unregister the selected tab")
        }
        if !window.isVisible {
            failures.append("Cmd-W with multiple tabs should keep the window open")
        }

        closeCurrentTab(nil)
        if window.isVisible {
            failures.append("Cmd-W with one tab should close the window")
        }

        return failures
    }

    private func handle(request: OpenRequest, responseFD fd: Int32) {
        let opened = open(targets: request.targets, invocationID: request.invocationID)
        guard opened.ok else {
            send(opened, to: fd, closeAfterWrite: true)
            return
        }

        let paths = request.targets.map(\.path)
        if request.wait {
            pendingInvocations[request.invocationID] = PendingInvocation(
                id: request.invocationID,
                paths: Set(paths),
                fd: fd
            )
            send(OpenResponse(ok: true, message: "opened; waiting for tabs to close"), to: fd, closeAfterWrite: false)
        } else {
            send(OpenResponse(ok: true, message: "opened \(request.targets.count) file(s)"), to: fd, closeAfterWrite: true)
        }
    }

    private func open(paths: [String], invocationID: String?) -> OpenResponse {
        open(targets: paths.map { OpenTarget(path: $0, line: nil) }, invocationID: invocationID)
    }

    private func open(targets: [OpenTarget], invocationID: String?) -> OpenResponse {
        var selectedDocument: TabDocument?

        for target in targets {
            let path = target.path
            if let existing = documentsByPath[path] {
                if let invocationID {
                    existing.waitingInvocations.insert(invocationID)
                }
                if let line = target.line {
                    existing.fileView.goToLine(line)
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
                if let line = target.line {
                    document.fileView.goToLine(line)
                }
                selectedDocument = document
                fputs(String(format: "ArtisanApp: opened %@ in %.2fms\n", path, elapsedMS), stderr)
            } catch {
                return OpenResponse(ok: false, message: "could not open \(path): \(error)")
            }
        }

        if let selectedDocument {
            tabView.selectTabViewItem(selectedDocument.item)
            window.makeFirstResponder(selectedDocument.fileView)
            updateTabButtons()
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

    private func selectTab(offset: Int) {
        let items = tabView.tabViewItems
        guard !items.isEmpty else { return }
        let currentIndex = tabView.selectedTabViewItem.map { tabView.indexOfTabViewItem($0) } ?? 0
        let nextIndex = (currentIndex + offset + items.count) % items.count
        tabView.selectTabViewItem(items[nextIndex])
        if let document = selectedDocument() {
            window.makeFirstResponder(document.fileView)
        }
        updateTabButtons()
        scrollSelectedTabButtonIntoView()
    }

    private func markDirty(_ document: TabDocument) {
        guard !document.isDirty else { return }
        document.isDirty = true
        updateTabLabel(document)
    }

    private func updateTabLabel(_ document: TabDocument) {
        document.item.label = document.isDirty ? "\(document.displayName) *" : document.displayName
        if let button = tabButtonsByItem[document.item] {
            button.title = document.item.label
            button.toolTip = document.path
            layoutTabBar()
        }
    }

    private func updateTabButtons() {
        ensureTabButtonsForOpenDocuments()
        let selected = tabView.selectedTabViewItem
        for (item, button) in tabButtonsByItem {
            button.state = item === selected ? .on : .off
            button.contentTintColor = item === selected ? NSColor.controlAccentColor : nil
        }
        layoutTabBar()
    }

    private func ensureTabButtonsForOpenDocuments() {
        tabBarScrollView.isHidden = tabView.numberOfTabViewItems <= 1
        guard tabView.numberOfTabViewItems > 1 else {
            return
        }

        for item in tabView.tabViewItems {
            guard tabButtonsByItem[item] == nil,
                  let document = documentsByItem[item]
            else {
                continue
            }

            addTabButton(for: document)
        }
    }

    private func addTabButton(for document: TabDocument) {
        guard tabButtonsByItem[document.item] == nil else {
            return
        }

        let button = NSButton(title: document.item.label, target: self, action: #selector(selectTabButton(_:)))
        button.setButtonType(.toggle)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 12)
        button.lineBreakMode = .byTruncatingMiddle
        button.toolTip = document.path
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
        button.widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true

        tabButtonsByItem[document.item] = button
        tabBarStack.addArrangedSubview(button)
    }

    private func removeTabButton(for item: NSTabViewItem) {
        guard let button = tabButtonsByItem.removeValue(forKey: item) else {
            return
        }

        tabBarStack.removeArrangedSubview(button)
        button.removeFromSuperview()
        layoutTabBar()
    }

    private func layoutTabBar() {
        guard tabBarScrollView.documentView === tabBarContentView else {
            return
        }

        tabBarStack.layoutSubtreeIfNeeded()
        let fittingSize = tabBarStack.fittingSize
        let visibleWidth = max(tabBarScrollView.contentView.bounds.width, tabBarScrollView.bounds.width)
        let height = max(30, tabBarScrollView.contentView.bounds.height, tabBarScrollView.bounds.height)
        let contentWidth = max(visibleWidth, fittingSize.width + 16)

        tabBarContentView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: height)
        tabBarStack.frame = NSRect(x: 8, y: 0, width: fittingSize.width, height: height)
        tabBarStack.needsLayout = true
        tabBarStack.layoutSubtreeIfNeeded()
    }

    private func scrollSelectedTabButtonIntoView() {
        guard let selected = tabView.selectedTabViewItem,
              let button = tabButtonsByItem[selected]
        else {
            return
        }

        layoutTabBar()
        button.scrollToVisible(button.bounds.insetBy(dx: -8, dy: 0))
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

        removeTabButton(for: item)
        tabView.removeTabViewItem(item)
        documentsByItem.removeValue(forKey: item)
        documentsByPath.removeValue(forKey: document.path)
        updateTabButtons()

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

func runLargeLanguageHighlightingBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-large-language-highlighting"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let fixtureDirectory = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL
    let requestedSampleLines = Int(ProcessInfo.processInfo.environment["ARTISAN_BENCH_LANGUAGE_HIGHLIGHT_SAMPLE_LINES"] ?? "") ?? 1_000
    let expectations: [(path: String, languageID: String, dedicated: Bool)] = [
        ("large.ts", "typescript", true),
        ("large.js", "javascript", true),
        ("large.py", "python", true),
        ("Large.java", "java", true),
        ("large.c", "c", true),
        ("large.cpp", "cpp", true),
        ("Large.cs", "csharp", true),
        ("large.go", "go", true),
        ("large.rs", "rust", true),
        ("large.php", "php", true),
        ("large.rb", "ruby", true),
        ("large.swift", "swift", true),
        ("Large.kt", "kotlin", true),
        ("large.sql", "sql", true),
        ("large.html", "html", true),
        ("large.css", "css", true),
        ("large.sh", "shell", true),
        ("large.json", "json", true),
        ("large.yaml", "yaml", true),
        ("large.r", "r", true),
        ("README.md", "markdown", true),
        ("large.txt", "text", false),
        ("Makefile", "makefile", true),
        ("Dockerfile", "dockerfile", true),
        ("large.xml", "xml", true),
        ("large.toml", "toml", true)
    ]

    do {
        var failures: [String] = []
        var totalSampleLines = 0
        var worstLanguage = ""
        var worstAverage = 0.0

        for expectation in expectations {
            let buffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent(expectation.path).path)
            if buffer.languageID != expectation.languageID {
                failures.append("\(expectation.path): expected \(expectation.languageID), got \(buffer.languageID)")
            }

            _ = buffer.highlightedSegments(at: 0)
            let firstMeasuredLine = buffer.indexedLineCount > 1 ? 1 : 0
            let availableMeasuredLines = max(1, buffer.indexedLineCount - firstMeasuredLine)
            let sampleLines = min(max(1, requestedSampleLines), availableMeasuredLines)
            var totalSegments = 0
            var multiSegmentLines = 0
            var nonPlainLines = 0

            let start = DispatchTime.now().uptimeNanoseconds
            for offset in 0..<sampleLines {
                let lineIndex = firstMeasuredLine + offset
                let segments = buffer.highlightedSegments(at: lineIndex)
                totalSegments += segments.count
                if segments.count > 1 {
                    multiSegmentLines += 1
                }
                if segments.contains(where: { $0.kind != .plain }) {
                    nonPlainLines += 1
                }
            }
            let elapsedMS = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            let averageLineMS = elapsedMS / Double(sampleLines)

            if expectation.dedicated && nonPlainLines == 0 {
                failures.append("\(expectation.path): dedicated highlighter produced only plain segments")
            }
            if expectation.languageID == "text", multiSegmentLines != 0 {
                failures.append("\(expectation.path): plain text produced \(multiSegmentLines) multi-segment lines")
            }
            if averageLineMS > worstAverage {
                worstAverage = averageLineMS
                worstLanguage = expectation.languageID
            }

            totalSampleLines += sampleLines
            print("benchmark.large_language.\(expectation.languageID).sample_lines=\(sampleLines)")
            print("benchmark.large_language.\(expectation.languageID).total_segments=\(totalSegments)")
            print("benchmark.large_language.\(expectation.languageID).multi_segment_lines=\(multiSegmentLines)")
            print(String(format: "benchmark.large_language.%@.highlight_ms=%.2f", expectation.languageID, elapsedMS))
            print(String(format: "benchmark.large_language.%@.avg_line_ms=%.4f", expectation.languageID, averageLineMS))
        }

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.large_language.count=\(expectations.count)")
        print("benchmark.large_language.sample_lines_total=\(totalSampleLines)")
        print("benchmark.large_language.worst_language=\(worstLanguage)")
        print(String(format: "benchmark.large_language.worst_avg_line_ms=%.4f", worstAverage))
        print("benchmark.large_language_highlighting=PASS")
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

func runSelectionModelBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-selection-model"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        let buffer = try TextBuffer(path: path)
        let fileView = FastFileView(buffer: buffer)
        let failures = fileView.benchmarkSelectionModel()
        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.selection_model=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runSelectionEditingBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-selection-editing"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        let buffer = try TextBuffer(path: path)
        let fileView = FastFileView(buffer: buffer)
        let failures = fileView.benchmarkSelectionEditing()
        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }

        if args.indices.contains(modeIndex + 2) {
            let largePath = URL(fileURLWithPath: args[modeIndex + 2]).standardizedFileURL.path
            let largeBuffer = try TextBuffer(path: largePath)
            let largeView = FastFileView(buffer: largeBuffer)
            let start = DispatchTime.now().uptimeNanoseconds
            let largeFailures = largeView.benchmarkLargeSelectAll()
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            if !largeFailures.isEmpty {
                for failure in largeFailures {
                    fputs("benchmark error: \(failure)\n", stderr)
                }
                exit(1)
            }
            print(String(format: "benchmark.selection_editing_large_select_all_ms=%.2f", elapsedMs))
            print("benchmark.selection_editing_large_select_all=PASS")
        }

        print("benchmark.selection_editing=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runUndoRedoBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-undo-redo"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        let buffer = try TextBuffer(path: path)
        let fileView = FastFileView(buffer: buffer)
        let failures = fileView.benchmarkUndoRedo()
        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }

        if args.indices.contains(modeIndex + 2) {
            let largePath = URL(fileURLWithPath: args[modeIndex + 2]).standardizedFileURL.path
            let largeBuffer = try TextBuffer(path: largePath)
            let largeView = FastFileView(buffer: largeBuffer)
            let start = DispatchTime.now().uptimeNanoseconds
            let largeFailures = largeView.benchmarkLargeBottomUndoRedo()
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            if !largeFailures.isEmpty {
                for failure in largeFailures {
                    fputs("benchmark error: \(failure)\n", stderr)
                }
                exit(1)
            }
            print(String(format: "benchmark.undo_redo_large_bottom_ms=%.2f", elapsedMs))
            print("benchmark.undo_redo_large_bottom=PASS")
        }

        print("benchmark.undo_redo=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runFindBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-find"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        let buffer = try TextBuffer(path: path)
        let fileView = FastFileView(buffer: buffer)
        let failures = fileView.benchmarkFind()
        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }

        if args.indices.contains(modeIndex + 2) {
            let largePath = URL(fileURLWithPath: args[modeIndex + 2]).standardizedFileURL.path
            let largeBuffer = try TextBuffer(path: largePath)
            let largeView = FastFileView(buffer: largeBuffer)
            let start = DispatchTime.now().uptimeNanoseconds
            let largeFailures = largeView.benchmarkLargeFind()
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            if !largeFailures.isEmpty {
                for failure in largeFailures {
                    fputs("benchmark error: \(failure)\n", stderr)
                }
                exit(1)
            }
            print(String(format: "benchmark.find_large_ms=%.2f", elapsedMs))
            print("benchmark.find_large=PASS")
        }

        print("benchmark.find=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

@MainActor
func runNativeMenusBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-native-menus"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        _ = NSApplication.shared
        let controller = AppController()
        var failures = controller.benchmarkMenuConfiguration()

        let buffer = try TextBuffer(path: path)
        let fileView = FastFileView(buffer: buffer)
        failures.append(contentsOf: fileView.benchmarkNativeMenuCommands())

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.native_menus=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runLanguageRegistryBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-language-registry"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let fixtureDirectory = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL
    let expectations: [(name: String, languageID: String, dedicated: Bool)] = [
        ("app.ts", "typescript", true),
        ("app.jsx", "javascript", true),
        ("README.md", "markdown", true),
        ("config.yaml", "yaml", true),
        ("Dockerfile", "dockerfile", true),
        ("Makefile", "makefile", true),
        ("config.xml", "xml", true),
        ("config.toml", "toml", true),
        ("script", "python", true),
        ("unknown.artisanfixture", "text", false)
    ]

    do {
        var failures: [String] = []
        var highlightedLineCount = 0
        for expectation in expectations {
            let path = fixtureDirectory.appendingPathComponent(expectation.name).path
            let buffer = try TextBuffer(path: path)
            if buffer.languageID != expectation.languageID {
                failures.append("\(expectation.name): expected \(expectation.languageID), got \(buffer.languageID)")
            }
            if let language = EditorLanguage(rawValue: buffer.languageID) {
                let dedicated = HighlighterRegistry.usesDedicatedHighlighter(for: language)
                if dedicated != expectation.dedicated {
                    failures.append("\(expectation.name): expected dedicated=\(expectation.dedicated), got \(dedicated)")
                }
            } else {
                failures.append("\(expectation.name): unknown language id \(buffer.languageID)")
            }
            _ = buffer.highlightedSegments(at: 0)
            highlightedLineCount += 1
        }

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.language_registry_known_count=\(expectations.count)")
        print("benchmark.language_registry_highlighted_lines=\(highlightedLineCount)")
        print("benchmark.language_registry=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runTSJSHighlightingBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-ts-js-highlighting"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let fixtureDirectory = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL

    do {
        var failures: [String] = []

        func expectKinds(_ path: String, line: Int, contains requiredKinds: Set<HighlightKind>) throws {
            let buffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent(path).path)
            let kinds = Set(buffer.highlightedSegments(at: line).map(\.kind))
            for kind in requiredKinds where !kinds.contains(kind) {
                failures.append("\(path): line \(line + 1) missing \(kind.rawValue), got \(kinds.map(\.rawValue).sorted())")
            }
        }

        let tsBuffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent("sample.ts").path)
        if tsBuffer.languageID != "typescript" {
            failures.append("sample.ts language expected typescript, got \(tsBuffer.languageID)")
        }
        try expectKinds("sample.ts", line: 0, contains: [.keyword, .number, .punctuation])
        try expectKinds("sample.ts", line: 1, contains: [.comment])
        try expectKinds("sample.ts", line: 2, contains: [.keyword, .string])
        try expectKinds("sample.ts", line: 3, contains: [.keyword, .comment])

        let tsxBuffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent("component.tsx").path)
        if tsxBuffer.languageID != "typescript" {
            failures.append("component.tsx language expected typescript, got \(tsxBuffer.languageID)")
        }
        try expectKinds("component.tsx", line: 0, contains: [.keyword, .tag, .attribute, .string, .punctuation])

        let jsxBuffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent("module.jsx").path)
        if jsxBuffer.languageID != "javascript" {
            failures.append("module.jsx language expected javascript, got \(jsxBuffer.languageID)")
        }
        try expectKinds("module.jsx", line: 0, contains: [.keyword, .tag, .attribute, .string, .punctuation])

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.ts_js_highlighting=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runDocDataHighlightingBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-doc-data-highlighting"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let fixtureDirectory = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL

    do {
        var failures: [String] = []

        func expectKinds(_ path: String, line: Int, contains requiredKinds: Set<HighlightKind>) throws {
            let buffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent(path).path)
            let kinds = Set(buffer.highlightedSegments(at: line).map(\.kind))
            for kind in requiredKinds where !kinds.contains(kind) {
                failures.append("\(path): line \(line + 1) missing \(kind.rawValue), got \(kinds.map(\.rawValue).sorted())")
            }
        }

        try expectKinds("README.md", line: 0, contains: [.heading])
        try expectKinds("README.md", line: 1, contains: [.code, .link, .emphasis])
        try expectKinds("README.md", line: 2, contains: [.code])
        try expectKinds("config.jsonc", line: 1, contains: [.comment])
        try expectKinds("config.jsonc", line: 2, contains: [.key, .boolean, .punctuation])
        try expectKinds("config.jsonc", line: 3, contains: [.key, .number])
        try expectKinds("config.jsonc", line: 4, contains: [.key, .null])
        try expectKinds("config.yaml", line: 0, contains: [.comment])
        try expectKinds("config.yaml", line: 1, contains: [.key, .string])
        try expectKinds("config.yaml", line: 2, contains: [.key, .boolean])
        try expectKinds("config.yaml", line: 3, contains: [.key, .number])

        let plainBuffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent("notes.txt").path)
        let plainSegments = plainBuffer.highlightedSegments(at: 0)
        if plainBuffer.languageID != "text" {
            failures.append("notes.txt language expected text, got \(plainBuffer.languageID)")
        }
        if plainSegments.count != 1 || plainSegments.first?.kind != .plain {
            failures.append("notes.txt should have one plain segment, got \(plainSegments.map(\.kind.rawValue))")
        }

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.doc_data_highlighting=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runCFamilyHighlightingBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-c-family-highlighting"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let fixtureDirectory = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL
    let expectations: [(path: String, languageID: String)] = [
        ("main.c", "c"),
        ("main.cpp", "cpp"),
        ("Main.cs", "csharp"),
        ("Main.java", "java"),
        ("main.go", "go"),
        ("main.rs", "rust"),
        ("main.swift", "swift"),
        ("Main.kt", "kotlin")
    ]

    do {
        var failures: [String] = []

        for expectation in expectations {
            let buffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent(expectation.path).path)
            if buffer.languageID != expectation.languageID {
                failures.append("\(expectation.path): expected \(expectation.languageID), got \(buffer.languageID)")
            }
            let line0Kinds = Set(buffer.highlightedSegments(at: 0).map(\.kind))
            for kind in [HighlightKind.keyword, .number, .comment, .punctuation] where !line0Kinds.contains(kind) {
                failures.append("\(expectation.path): first line missing \(kind.rawValue), got \(line0Kinds.map(\.rawValue).sorted())")
            }
            let line1Kinds = Set(buffer.highlightedSegments(at: 1).map(\.kind))
            if !line1Kinds.contains(.string) {
                failures.append("\(expectation.path): second line missing string, got \(line1Kinds.map(\.rawValue).sorted())")
            }
        }

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.c_family_highlighting=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runWebScriptingHighlightingBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-web-scripting-highlighting"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let fixtureDirectory = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL

    do {
        var failures: [String] = []

        func expect(_ path: String, languageID: String, line: Int, contains requiredKinds: Set<HighlightKind>) throws {
            let buffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent(path).path)
            if buffer.languageID != languageID {
                failures.append("\(path): expected \(languageID), got \(buffer.languageID)")
            }
            let kinds = Set(buffer.highlightedSegments(at: line).map(\.kind))
            for kind in requiredKinds where !kinds.contains(kind) {
                failures.append("\(path): line \(line + 1) missing \(kind.rawValue), got \(kinds.map(\.rawValue).sorted())")
            }
        }

        try expect("app.py", languageID: "python", line: 0, contains: [.keyword, .punctuation])
        try expect("app.py", languageID: "python", line: 1, contains: [.number, .comment])
        try expect("app.py", languageID: "python", line: 2, contains: [.string])
        try expect("app.rb", languageID: "ruby", line: 0, contains: [.keyword])
        try expect("app.rb", languageID: "ruby", line: 1, contains: [.number, .comment])
        try expect("app.php", languageID: "php", line: 0, contains: [.keyword, .attribute, .number, .comment, .punctuation])
        try expect("run-script", languageID: "shell", line: 1, contains: [.number, .comment, .punctuation])
        try expect("run-script", languageID: "shell", line: 2, contains: [.keyword, .string])
        try expect("query.sql", languageID: "sql", line: 0, contains: [.keyword, .number, .comment, .punctuation])
        try expect("query.sql", languageID: "sql", line: 1, contains: [.keyword, .string])
        try expect("index.html", languageID: "html", line: 0, contains: [.comment])
        try expect("index.html", languageID: "html", line: 1, contains: [.tag, .attribute, .string, .punctuation])
        try expect("styles.css", languageID: "css", line: 0, contains: [.comment])
        try expect("styles.css", languageID: "css", line: 1, contains: [.key, .string, .number, .punctuation])
        try expect("analysis.r", languageID: "r", line: 0, contains: [.number, .comment, .punctuation])
        try expect("analysis.r", languageID: "r", line: 1, contains: [.string])

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.web_scripting_highlighting=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runBuildConfigHighlightingBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-build-config-highlighting"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let fixtureDirectory = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL

    do {
        var failures: [String] = []

        func expect(_ path: String, languageID: String, line: Int, contains requiredKinds: Set<HighlightKind>) throws {
            let buffer = try TextBuffer(path: fixtureDirectory.appendingPathComponent(path).path)
            if buffer.languageID != languageID {
                failures.append("\(path): expected \(languageID), got \(buffer.languageID)")
            }
            guard let language = EditorLanguage(rawValue: buffer.languageID),
                  HighlighterRegistry.usesDedicatedHighlighter(for: language)
            else {
                failures.append("\(path): expected dedicated highlighter for \(buffer.languageID)")
                return
            }
            let kinds = Set(buffer.highlightedSegments(at: line).map(\.kind))
            for kind in requiredKinds where !kinds.contains(kind) {
                failures.append("\(path): line \(line + 1) missing \(kind.rawValue), got \(kinds.map(\.rawValue).sorted())")
            }
        }

        try expect("Makefile", languageID: "makefile", line: 0, contains: [.key, .punctuation])
        try expect("Makefile", languageID: "makefile", line: 1, contains: [.key, .string, .comment, .punctuation])
        try expect("Makefile", languageID: "makefile", line: 2, contains: [.keyword, .string])
        try expect("Dockerfile", languageID: "dockerfile", line: 0, contains: [.keyword])
        try expect("Dockerfile", languageID: "dockerfile", line: 1, contains: [.keyword, .string, .comment])
        try expect("Dockerfile", languageID: "dockerfile", line: 2, contains: [.keyword, .number, .punctuation])
        try expect("config.xml", languageID: "xml", line: 0, contains: [.comment])
        try expect("config.xml", languageID: "xml", line: 1, contains: [.tag, .attribute, .string, .punctuation])
        try expect("config.toml", languageID: "toml", line: 0, contains: [.tag, .punctuation])
        try expect("config.toml", languageID: "toml", line: 1, contains: [.key, .boolean, .punctuation])
        try expect("config.toml", languageID: "toml", line: 2, contains: [.key, .number])
        try expect("config.toml", languageID: "toml", line: 3, contains: [.key, .string, .comment])

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.build_config_highlighting=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

@MainActor
func runHorizontalCaretVisibilityBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-horizontal-caret-visibility"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        let buffer = try TextBuffer(path: path)
        let fileView = FastFileView(buffer: buffer)
        let failures = fileView.benchmarkHorizontalCaretVisibility(viewport: NSSize(width: 420, height: 140))
        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.horizontal_caret_visibility=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

@MainActor
func runTabNavigationBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-tab-navigation"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let directory = URL(fileURLWithPath: args[modeIndex + 1], isDirectory: true).standardizedFileURL
    _ = NSApplication.shared
    let controller = AppController()
    let failures = controller.benchmarkTabNavigation(directory: directory)
    if !failures.isEmpty {
        for failure in failures {
            fputs("benchmark error: \(failure)\n", stderr)
        }
        exit(1)
    }
    print("benchmark.tab_navigation=PASS")
    exit(0)
}

@MainActor
func runOpenTargetsBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-open-targets"),
          args.indices.contains(modeIndex + 2)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    let secondPath = URL(fileURLWithPath: args[modeIndex + 2]).standardizedFileURL.path
    _ = NSApplication.shared
    let controller = AppController()
    let failures = controller.benchmarkOpenTargets(path: path, secondPath: secondPath)
    if !failures.isEmpty {
        for failure in failures {
            fputs("benchmark error: \(failure)\n", stderr)
        }
        exit(1)
    }
    print("benchmark.open_targets=PASS")
    exit(0)
}

func runPreferencesBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-preferences"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    let oldFontSize = EditorPreferences.fontSize
    let oldFrame = EditorPreferences.savedWindowFrame
    defer {
        EditorPreferences.fontSize = oldFontSize
        EditorPreferences.savedWindowFrame = oldFrame
    }

    do {
        var failures: [String] = []

        EditorPreferences.fontSize = 17
        let buffer = try TextBuffer(path: path)
        let fileView = FastFileView(buffer: buffer)
        if Int(fileView.currentFontSize.rounded()) != 17 {
            failures.append("new view should use persisted font size 17, got \(fileView.currentFontSize)")
        }

        EditorPreferences.fontSize = 15
        fileView.applyPreferences()
        if Int(fileView.currentFontSize.rounded()) != 15 {
            failures.append("open view should apply persisted font size 15, got \(fileView.currentFontSize)")
        }

        let frame = NSRect(x: 44, y: 55, width: 900, height: 640)
        EditorPreferences.savedWindowFrame = frame
        guard let restoredFrame = EditorPreferences.savedWindowFrame,
              NSEqualRects(restoredFrame, frame)
        else {
            failures.append("window frame preference did not round-trip")
            if let restoredFrame = EditorPreferences.savedWindowFrame {
                failures.append("restored frame was \(NSStringFromRect(restoredFrame))")
            }
            if !failures.isEmpty {
                for failure in failures {
                    fputs("benchmark error: \(failure)\n", stderr)
                }
                exit(1)
            }
            return
        }

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.preferences=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

func runEditorCoreBenchmarkIfRequested() {
    let args = CommandLine.arguments
    guard let modeIndex = args.firstIndex(of: "--benchmark-editor-core"),
          args.indices.contains(modeIndex + 1)
    else {
        return
    }

    let path = URL(fileURLWithPath: args[modeIndex + 1]).standardizedFileURL.path
    do {
        let buffer = try TextBuffer(path: path)
        buffer.ensureFullyIndexed()
        var failures: [String] = []

        let originalLineCount = buffer.lineCount
        let topOriginal = buffer.lineText(at: 0)
        let middleLine = max(0, originalLineCount / 2)
        let middleOriginal = buffer.lineText(at: middleLine)
        let bottomLine = max(0, originalLineCount - 1)
        let bottomOriginal = buffer.lineText(at: bottomLine)

        _ = buffer.insert("TOP-", atLine: 0, column: 0)
        _ = buffer.insert("-MID-", atLine: middleLine, column: min(5, middleOriginal.count))
        _ = buffer.insert("-BOTTOM", atLine: bottomLine, column: bottomOriginal.count)

        if buffer.lineText(at: 0) != "TOP-" + topOriginal {
            failures.append("top edit did not apply")
        }
        if !buffer.lineText(at: middleLine).contains("-MID-") {
            failures.append("middle edit did not apply")
        }
        if buffer.lineText(at: bottomLine) != bottomOriginal + "-BOTTOM" {
            failures.append("bottom edit did not apply")
        }
        if buffer.lineCount != originalLineCount {
            failures.append("single-line edits should not change line count")
        }

        _ = buffer.delete(in: (
            start: TextPosition(line: 0, column: 0),
            end: TextPosition(line: 0, column: 4)
        ))
        if buffer.lineText(at: 0) != topOriginal {
            failures.append("top delete did not restore original")
        }

        if !failures.isEmpty {
            for failure in failures {
                fputs("benchmark error: \(failure)\n", stderr)
            }
            exit(1)
        }
        print("benchmark.editor_core=PASS")
        exit(0)
    } catch {
        fputs("benchmark error: \(error)\n", stderr)
        exit(1)
    }
}

runHighlightModeBenchmarkIfRequested()
runLargeLanguageHighlightingBenchmarkIfRequested()
runEditOperationsBenchmarkIfRequested()
runSaveOperationsBenchmarkIfRequested()
runDiskChangeSaveBenchmarkIfRequested()
runKeyboardNavigationBenchmarkIfRequested()
runSelectionModelBenchmarkIfRequested()
runSelectionEditingBenchmarkIfRequested()
runUndoRedoBenchmarkIfRequested()
runFindBenchmarkIfRequested()
runNativeMenusBenchmarkIfRequested()
runLanguageRegistryBenchmarkIfRequested()
runTSJSHighlightingBenchmarkIfRequested()
runDocDataHighlightingBenchmarkIfRequested()
runCFamilyHighlightingBenchmarkIfRequested()
runWebScriptingHighlightingBenchmarkIfRequested()
runBuildConfigHighlightingBenchmarkIfRequested()
runHorizontalCaretVisibilityBenchmarkIfRequested()
runTabNavigationBenchmarkIfRequested()
runOpenTargetsBenchmarkIfRequested()
runPreferencesBenchmarkIfRequested()
runEditorCoreBenchmarkIfRequested()

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.run()
