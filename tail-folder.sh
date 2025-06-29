#!/bin/bash

# tail-folder.sh - Version 2.0
# Script to tail all changes in a folder recursively with diff output
# Works on both Linux (inotifywait) and macOS (fswatch)

FOLDER="${1:-.}"
TEMP_DIR="/tmp/tail-folder-$$"
mkdir -p "$TEMP_DIR"

if [[ ! -d "$FOLDER" ]]; then
    echo "Error: Directory '$FOLDER' does not exist"
    exit 1
fi

# Function to install dependencies
install_dependencies() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Installing inotify-tools for Linux..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y inotify-tools
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y inotify-tools
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y inotify-tools
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S inotify-tools
        else
            echo "Unable to detect package manager. Please install inotify-tools manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Installing fswatch for macOS..."
        if command -v brew >/dev/null 2>&1; then
            brew install fswatch
        else
            echo "Homebrew not found. Installing Homebrew first..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew install fswatch
        fi
    else
        echo "Unsupported operating system"
        exit 1
    fi
}

# Function to show file changes
show_changes() {
    local filepath="$1"
    local event="$2"
    local timestamp="$3"
    
    echo "[$timestamp] $event: $filepath"
    
    if [[ "$event" == *"CREATE"* ]] || [[ "$event" == *"MOVED_TO"* ]]; then
        echo "--- NEW FILE ---"
        if [[ -f "$filepath" ]]; then
            local file_size=$(wc -c < "$filepath" 2>/dev/null || echo 1000000)
            local line_count=$(wc -l < "$filepath" 2>/dev/null || echo 1000)
            local mime_type=$(file -b --mime-type "$filepath" 2>/dev/null || echo "unknown")
            
            if [[ $file_size -gt 50000 ]]; then
                echo "+ [Large file: $(($file_size / 1024))KB]"
            elif [[ $line_count -gt 500 ]]; then
                echo "+ [Many lines: $line_count lines]"  
            elif [[ "$mime_type" == text/* ]] || [[ "$filepath" == *.txt ]] || [[ "$filepath" == *.md ]] || [[ "$filepath" == *.sh ]] || [[ "$filepath" == *.py ]] || [[ "$filepath" == *.js ]] || [[ "$filepath" == *.json ]] || [[ "$filepath" == *.yml ]] || [[ "$filepath" == *.yaml ]] || [[ "$filepath" == *.xml ]] || [[ "$filepath" == *.html ]] || [[ "$filepath" == *.css ]]; then
                head -20 "$filepath" | sed 's/^/+ /'
                if [[ $line_count -gt 20 ]]; then
                    echo "+ ... ($(( $line_count - 20 )) more lines)"
                fi
            else
                echo "+ [Binary file: $mime_type, $(($file_size / 1024))KB]"
            fi
        else
            echo "+ [File not found or removed]"
        fi
        echo
    elif [[ "$event" == *"DELETE"* ]] || [[ "$event" == *"MOVED_FROM"* ]]; then
        echo "--- FILE DELETED ---"
        local backup_file="$TEMP_DIR/$(basename "$filepath").backup"
        if [[ -f "$backup_file" ]]; then
            echo "Previous content:"
            cat "$backup_file" | sed 's/^/- /'
            rm -f "$backup_file"
        fi
        echo
    elif [[ "$event" == *"MODIFY"* ]] && [[ -f "$filepath" ]]; then
        local backup_file="$TEMP_DIR/$(echo "$filepath" | sed 's|/|_|g').backup"
        
        # Check if file is text and reasonable size
        local file_size=$(wc -c < "$filepath" 2>/dev/null || echo 1000000)
        local line_count=$(wc -l < "$filepath" 2>/dev/null || echo 1000)
        local mime_type=$(file -b --mime-type "$filepath" 2>/dev/null || echo "unknown")
        
        if [[ $file_size -gt 50000 ]]; then
            echo "--- LARGE FILE MODIFIED ($(($file_size / 1024))KB) ---"
            echo "File too large to show diff, but modification detected"
        elif [[ $line_count -gt 500 ]]; then
            echo "--- MANY LINES MODIFIED ($line_count lines) ---"
            echo "File has too many lines to show diff, but modification detected"
        elif [[ "$mime_type" == text/* ]] || [[ "$filepath" == *.txt ]] || [[ "$filepath" == *.md ]] || [[ "$filepath" == *.sh ]] || [[ "$filepath" == *.py ]] || [[ "$filepath" == *.js ]] || [[ "$filepath" == *.json ]] || [[ "$filepath" == *.yml ]] || [[ "$filepath" == *.yaml ]] || [[ "$filepath" == *.xml ]] || [[ "$filepath" == *.html ]] || [[ "$filepath" == *.css ]]; then
            if [[ -f "$backup_file" ]]; then
                echo "--- DIFF ---"
                local diff_output=$(diff -u "$backup_file" "$filepath" 2>/dev/null)
                if [[ -n "$diff_output" ]]; then
                    echo "$diff_output" | head -50
                    local diff_lines=$(echo "$diff_output" | wc -l)
                    if [[ $diff_lines -gt 50 ]]; then
                        echo "... ($(($diff_lines - 50)) more diff lines truncated)"
                    fi
                else
                    echo "File modified but no diff detected (possibly timestamp/metadata change)"
                    echo "Current content (first 10 lines):"
                    head -10 "$filepath" | sed 's/^/  /'
                fi
            else
                echo "--- MODIFIED FILE (no previous backup) ---"
                echo "Current content (first 20 lines):"
                head -20 "$filepath" | sed 's/^/  /'
                if [[ $line_count -gt 20 ]]; then
                    echo "  ... ($(( $line_count - 20 )) more lines)"
                fi
            fi
            
            # Always update backup for next comparison
            cp "$filepath" "$backup_file" 2>/dev/null
        else
            echo "--- BINARY FILE MODIFIED ($(($file_size / 1024))KB, type: $mime_type) ---"
            echo "Binary file changed, cannot show diff"
        fi
        echo
    fi
}

# Function to create initial backups
create_initial_backups() {
    echo "Creating initial backups for diff comparison..."
    find "$FOLDER" -type f 2>/dev/null | while read -r file; do
        local file_size=$(wc -c < "$file" 2>/dev/null || echo 1000000)
        local line_count=$(wc -l < "$file" 2>/dev/null || echo 1000)
        
        # Only backup text files under 50KB and 500 lines
        local mime_type=$(file -b --mime-type "$file" 2>/dev/null || echo "unknown")
        if [[ $file_size -le 50000 ]] && [[ $line_count -le 500 ]] && ([[ "$mime_type" == text/* ]] || [[ "$file" == *.txt ]] || [[ "$file" == *.md ]] || [[ "$file" == *.sh ]] || [[ "$file" == *.py ]] || [[ "$file" == *.js ]] || [[ "$file" == *.json ]] || [[ "$file" == *.yml ]] || [[ "$file" == *.yaml ]] || [[ "$file" == *.xml ]] || [[ "$file" == *.html ]] || [[ "$file" == *.css ]]); then
            cp "$file" "$TEMP_DIR/$(echo "$file" | sed 's|/|_|g').backup" 2>/dev/null
        fi
    done
}

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"
    exit 0
}

trap cleanup EXIT INT TERM

create_initial_backups

echo "tail-folder.sh v2.0 - File Change Monitor"
echo "Monitoring changes in: $FOLDER"
echo "Press Ctrl+C to stop"
echo "Temporary files stored in: $TEMP_DIR"
echo "----------------------------------------"

# Detect OS and use appropriate tool
if command -v inotifywait >/dev/null 2>&1; then
    # Linux - using inotify-tools
    inotifywait -m -r -e modify,create,delete,move --format '%T %w%f %e' --timefmt '%Y-%m-%d %H:%M:%S' "$FOLDER" | while read timestamp filepath event; do
        show_changes "$filepath" "$event" "$timestamp"
    done
elif command -v fswatch >/dev/null 2>&1; then
    # macOS - using fswatch
    fswatch -r "$FOLDER" | while read filepath; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        if [[ -f "$filepath" ]]; then
            show_changes "$filepath" "MODIFY" "$timestamp"
        elif [[ ! -e "$filepath" ]]; then
            show_changes "$filepath" "DELETE" "$timestamp"
        else
            show_changes "$filepath" "CREATE" "$timestamp"
        fi
    done
else
    echo "Required tools not found. Installing dependencies..."
    install_dependencies
    echo "Dependencies installed. Please run the script again."
    exit 0
fi