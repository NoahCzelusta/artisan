# Syntax Highlighting

Syntax highlighting must stay subordinate to launch speed, editing latency, and scrolling. Artisan highlights the visible viewport first and must not parse or highlight an entire large file on open.

## Rules

- Highlighting is viewport-bounded.
- Highlighting must not block file open.
- Highlighting must not start a language server.
- Highlighting must not index a project or workspace.
- Highlighting may cache visible and nearby lines.
- Highlighting must degrade to plain text for unknown or expensive cases.
- Multi-line language state is allowed only when bounded and incrementally recoverable.

## Initial Coverage Set

This is a pragmatic first coverage set, not an exact popularity ranking. It is informed by public popularity signals such as GitHub Octoverse, TIOBE, and PYPL, but optimized for files developers commonly open during agent-assisted coding.

| Language / Format | Extensions | First highlighter strategy |
| --- | --- | --- |
| TypeScript | `.ts`, `.tsx`, `.mts`, `.cts` | C-like lexer plus JSX/TSX mode |
| JavaScript | `.js`, `.jsx`, `.mjs`, `.cjs` | C-like lexer plus JSX mode |
| Python | `.py`, `.pyi` | indentation-aware line lexer |
| Java | `.java` | C-like lexer |
| C | `.c`, `.h` | C-like lexer |
| C++ | `.cc`, `.cpp`, `.cxx`, `.hpp`, `.hh`, `.hxx` | C-like lexer |
| C# | `.cs` | C-like lexer |
| Go | `.go` | C-like lexer |
| Rust | `.rs` | C-like lexer |
| PHP | `.php`, `.phtml` | PHP lexer with HTML escapes |
| Ruby | `.rb`, `.rake`, `Gemfile` | Ruby line lexer |
| Swift | `.swift` | C-like lexer |
| Kotlin | `.kt`, `.kts` | C-like lexer |
| SQL | `.sql` | SQL keyword lexer |
| HTML | `.html`, `.htm` | tag/attribute lexer |
| CSS | `.css`, `.scss`, `.sass`, `.less` | CSS selector/property lexer |
| Shell | `.sh`, `.bash`, `.zsh`, `.fish` | shell line lexer |
| JSON | `.json`, `.jsonc` | structural lexer |
| YAML | `.yml`, `.yaml` | indentation-aware key/value lexer |
| R | `.r` | R line lexer |
| Markdown | `.md`, `.mdx`, `.markdown` | markdown block/inline lexer |
| Plain text | `.txt`, unknown | no-op highlighter |

## Architecture Direction

Use a language detector that maps file extension, filename, and shebang to a highlighter. Highlighters should expose a small interface that accepts a line plus bounded surrounding state and returns colored spans.

The editor core should keep syntax work disposable: if a line is not visible and not near the viewport, it does not need to be highlighted yet.

## Registry Contract

Language detection returns stable language ids such as `typescript`, `javascript`, `markdown`, `json`, `yaml`, `python`, `swift`, `shell`, and `text`. Extension and special-filename detection must not inspect parent directories, package manifests, git metadata, or project configuration.

Unknown files use the `text` id and the plain-text highlighter. Known languages may also use the plain-text highlighter until their dedicated MVP highlighter lands; this keeps detection independent from grammar implementation.

Shebang detection is limited to the first line and maps common script runtimes such as Python, Ruby, Node/Deno, PHP, Rscript, and POSIX shells.

## Implemented Highlighters

All language ids are covered by `scripts/check-all-language-highlighting-benchmarks.sh`,
which generates large fixtures and measures 1,000 steady-state highlighted lines
per language through `TextBuffer.highlightedSegments`.

- `typescript` and `javascript`: line-local lexical highlighting for keywords, line comments, inline block comments, strings, numbers, punctuation, and simple JSX/TSX tag and attribute spans.
- `markdown`: line-local headings, code fences, inline code, links, and emphasis.
- `json`: line-local strings, object keys, numbers, booleans, nulls, punctuation, and JSONC line comments.
- `yaml`: line-local comments, keys, quoted strings, numeric scalars, booleans, and punctuation.
- `c`, `cpp`, `csharp`, `java`, `go`, `rust`, `swift`, and `kotlin`: shared line-local C-like lexer with per-language keyword sets, comments, strings, numbers, and punctuation.
- `python`, `ruby`, `php`, `shell`, and `r`: shared line-local scripting lexer with per-language keyword sets, comments, strings, variables where applicable, numbers, and punctuation.
- `sql`: line-local SQL keyword lexer with strings, numbers, punctuation, and `--` comments.
- `html`: line-local tags, attributes, quoted strings, punctuation, and comments.
- `css`: line-local selectors/properties, strings, numbers, punctuation, and comments.

## Deferred Work

- Tree-sitter or parser-backed highlighting is not assumed. If introduced later, it must prove it can meet the benchmark targets without whole-file startup work.
- Semantic highlighting is out of scope because it requires language servers or project analysis.
- Formatting remains explicit and single-file only, if added later.
