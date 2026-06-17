# Keyboard Navigation

Artisan follows familiar macOS-style text navigation without adding modal editor behavior.

| Shortcut | Behavior |
| --- | --- |
| Left / Right | Move one character, crossing line boundaries. |
| Up / Down | Move one line while preserving the preferred column where possible. |
| Option-Left / Option-Right | Move by word, treating whitespace and punctuation as separators. |
| Command-Left / Command-Right | Move to the start or end of the current line. |
| Command-Up / Command-Down | Move to the start or end of the file. |
| Page Up / Page Down | Move by the visible viewport height, clamped to file bounds. |
| Home / End | Move to the start or end of the current line. |
| Option-Backspace | Delete the previous word. |
| Command-Backspace | Delete to the start of the current line. |

Selection-modifying variants are handled by the selection issues.
