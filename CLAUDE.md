# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a simple utility repository containing a single bash script for monitoring file system changes recursively in a directory.

- `tail-folder.sh` - Main script that monitors file changes using platform-specific tools (inotifywait on Linux, fswatch on macOS)

## Usage

Run the script to monitor the current directory:
```bash
./tail-folder.sh
```

Or specify a directory to monitor:
```bash
./tail-folder.sh /path/to/directory
```

## Script Architecture

The script automatically detects the operating system and uses the appropriate file monitoring tool:
- **Linux**: Uses `inotifywait` from inotify-tools package
- **macOS**: Uses `fswatch` (installed via Homebrew if needed)

The script includes automatic dependency installation for supported package managers and will exit gracefully if dependencies cannot be installed.

## Testing the Script

To test functionality:
1. Run the script in one terminal
2. In another terminal, create/modify/delete files in the monitored directory
3. Verify that changes are detected and displayed with timestamps