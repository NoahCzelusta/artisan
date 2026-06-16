# Preserve existing file semantics

Artisan edits existing code files, so saving must avoid surprising byte-level changes. V1 should preserve line endings, final newline presence, and UTF-8 text; binary-looking or unsupported encodings should open read-only or fail rather than risk corruption, saves should be atomic, and the app should warn if a file changed on disk after it was opened.
