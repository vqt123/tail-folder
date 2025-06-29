# tail-folder.sh

A powerful, cross-platform file monitoring script that shows real-time file changes with colorized diff output. Perfect for development workflows where you need to see exactly what's changing in your project files.

## Features

- 🎨 **Colorized Output** - Events and diffs are color-coded for easy reading
- ⚡ **Instant Startup** - Lazy backup mode starts immediately without scanning all files
- 🔍 **Real Diffs** - Shows actual line-by-line changes, not just "file modified"
- 🙈 **Smart Filtering** - Automatically ignores common build artifacts (node_modules, .git, dist, build)
- 🖥️ **Cross-Platform** - Works on both Linux (inotifywait) and macOS (fswatch)
- 📁 **Recursive Monitoring** - Watches entire directory trees
- 🔧 **Terminal Aware** - Colors only appear in terminal, clean output when piped

## Installation

1. Download the script:
```bash
git clone https://github.com/vqt123/tail-folder.git
cd tail-folder
chmod +x tail-folder.sh
```

2. The script will automatically install dependencies if needed:
   - **Linux**: `inotify-tools` package
   - **macOS**: `fswatch` via Homebrew

## Usage

Monitor the current directory:
```bash
./tail-folder.sh
```

Monitor a specific directory:
```bash
./tail-folder.sh /path/to/directory
```

## Output Examples

### File Creation
```
[2025-06-29 13:30:15] CREATE: ./src/components/Button.tsx
--- NEW FILE ---
+ import React from 'react';
+ 
+ export const Button = () => {
+   return <button>Click me</button>;
+ };
```

### File Modification with Diff
```
[2025-06-29 13:31:22] MODIFY: ./src/components/Button.tsx
--- DIFF ---
--- ./src/components/Button.tsx.backup    2025-06-29 13:30:15.000000000 -0400
+++ ./src/components/Button.tsx           2025-06-29 13:31:22.000000000 -0400
@@ -1,5 +1,6 @@
 import React from 'react';
 
-export const Button = () => {
-  return <button>Click me</button>;
+export const Button = ({ label }: { label: string }) => {
+  return <button className="btn">{label}</button>;
 };
```

### File Deletion
```
[2025-06-29 13:32:10] DELETE: ./src/components/OldComponent.tsx
--- FILE DELETED ---
Previous content:
- // This component is no longer needed
- export const OldComponent = () => null;
```

## Color Scheme

- 🟢 **CREATE events** - Green (new files)
- 🟡 **MODIFY events** - Yellow (changed files)
- 🔴 **DELETE events** - Red (removed files)
- 🔵 **Diff headers** - Blue
- 🟢 **Added lines** (+) - Green
- 🔴 **Removed lines** (-) - Red
- 🟣 **Context markers** (@@) - Purple
- 🔘 **File metadata** - Gray

## Smart Filtering

The script automatically ignores common development artifacts:
- `node_modules/` directories
- `.git/` directories  
- `dist/` and `build/` directories
- Files matching these patterns are completely silent (no output)

## Technical Details

### Lazy Backup Mode
Unlike traditional file monitors that create upfront backups of all files (which doesn't scale), this script uses a lazy backup approach:

- Backups are created only when files are **first modified**
- Subsequent changes show actual diffs against the backup
- Much faster startup and lower memory usage
- Scales to projects of any size

### Cross-Platform Compatibility
- **Linux**: Uses `inotifywait` from inotify-tools
- **macOS**: Uses `fswatch` 
- Automatic dependency installation on supported systems

### File Type Support
Shows diffs for common text file types:
- Code: `.js`, `.ts`, `.py`, `.sh`, `.html`, `.css`
- Config: `.json`, `.yml`, `.yaml`, `.xml`
- Documentation: `.md`, `.txt`

Binary files show size and type information instead of content.

## Requirements

- Bash shell
- Linux: `inotify-tools` (auto-installed)
- macOS: `fswatch` (auto-installed via Homebrew)

## Use Cases

- **Development monitoring** - See exactly what your build tools are changing
- **Debugging file changes** - Track down what's modifying unexpected files
- **Code review preparation** - Real-time view of changes as you work
- **Build process analysis** - Monitor what files are generated during builds
- **Configuration debugging** - See how config files change over time

## Exit

Press `Ctrl+C` to stop monitoring. The script automatically cleans up temporary backup files on exit.