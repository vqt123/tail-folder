#!/bin/bash

# tail-folder.sh - Version 2.0
# Script to tail all changes in a folder recursively with diff output
# Works on both Linux (inotifywait) and macOS (fswatch)

FOLDER="${1:-.}"
TEMP_DIR="/tmp/tail-folder-$$"
mkdir -p "$TEMP_DIR"

# Color constants
if [[ -t 1 ]]; then  # Only use colors if outputting to terminal
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    GRAY='\033[0;90m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' GRAY='' BOLD='' NC=''
fi

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

# Function to check if file should be ignored based on .gitignore
should_ignore_file() {
    local filepath="$1"
    
    # Simple pattern matching for common ignore patterns (temporary fix)
    if [[ "$filepath" == *"node_modules"* ]] || [[ "$filepath" == *".git/"* ]] || [[ "$filepath" == *"dist/"* ]] || [[ "$filepath" == *"build/"* ]]; then
        return 0  # Should ignore
    fi
    
    return 1  # Should not ignore
}

# Function to show file changes
show_changes() {
    local filepath="$1"
    local event="$2"
    local timestamp="$3"
    
    # Check if file should be ignored - silently skip if so
    if should_ignore_file "$filepath"; then
        return
    fi
    
    # Colorize event types
    local colored_event=""
    case "$event" in
        *CREATE*|*MOVED_TO*) colored_event="${GREEN}$event${NC}" ;;
        *MODIFY*) colored_event="${YELLOW}$event${NC}" ;;
        *DELETE*|*MOVED_FROM*) colored_event="${RED}$event${NC}" ;;
        *) colored_event="$event" ;;
    esac
    
    echo -e "${CYAN}[$timestamp]${NC} $colored_event: ${BOLD}$filepath${NC}"
    
    if [[ "$event" == *"CREATE"* ]] || [[ "$event" == *"MOVED_TO"* ]]; then
        echo -e "${GREEN}${BOLD}--- NEW FILE ---${NC}"
        if [[ -f "$filepath" ]]; then
            local file_size=$(wc -c < "$filepath" 2>/dev/null || echo 1000000)
            local line_count=$(wc -l < "$filepath" 2>/dev/null || echo 1000)
            local mime_type=$(file -b --mime-type "$filepath" 2>/dev/null || echo "unknown")
            
            if [[ $file_size -gt 50000 ]]; then
                echo -e "${GREEN}+ [Large file: $(($file_size / 1024))KB]${NC}"
            elif [[ $line_count -gt 500 ]]; then
                echo -e "${GREEN}+ [Many lines: $line_count lines]${NC}"  
            elif [[ "$mime_type" == text/* ]] || [[ "$filepath" == *.txt ]] || [[ "$filepath" == *.md ]] || [[ "$filepath" == *.sh ]] || [[ "$filepath" == *.py ]] || [[ "$filepath" == *.js ]] || [[ "$filepath" == *.json ]] || [[ "$filepath" == *.yml ]] || [[ "$filepath" == *.yaml ]] || [[ "$filepath" == *.xml ]] || [[ "$filepath" == *.html ]] || [[ "$filepath" == *.css ]]; then
                head -20 "$filepath" | while IFS= read -r line; do
                    echo -e "${GREEN}+ ${line}${NC}"
                done
                if [[ $line_count -gt 20 ]]; then
                    echo -e "${GREEN}+ ... ($(( $line_count - 20 )) more lines)${NC}"
                fi
            else
                echo -e "${GREEN}+ [Binary file: $mime_type, $(($file_size / 1024))KB]${NC}"
            fi
        else
            echo -e "${GREEN}+ [File not found or removed]${NC}"
        fi
        echo
    elif [[ "$event" == *"DELETE"* ]] || [[ "$event" == *"MOVED_FROM"* ]]; then
        echo -e "${RED}${BOLD}--- FILE DELETED ---${NC}"
        local backup_file="$TEMP_DIR/$(basename "$filepath").backup"
        if [[ -f "$backup_file" ]]; then
            echo "Previous content:"
            cat "$backup_file" | while IFS= read -r line; do
                echo -e "${RED}- ${line}${NC}"
            done
            rm -f "$backup_file"
        fi
        echo
    elif ([[ "$event" == *"MODIFY"* ]] || [[ "$event" == "MODIFY" ]]) && [[ -f "$filepath" ]]; then
        local backup_file="$TEMP_DIR/$(echo "$filepath" | sed 's|/|_|g').backup"
        
        # Check if file is text and reasonable size
        local file_size=$(wc -c < "$filepath" 2>/dev/null || echo 1000000)
        local line_count=$(wc -l < "$filepath" 2>/dev/null || echo 1000)
        local mime_type=$(file -b --mime-type "$filepath" 2>/dev/null || echo "unknown")
        
        if [[ $file_size -gt 50000 ]]; then
            echo -e "${YELLOW}${BOLD}--- LARGE FILE MODIFIED ($(($file_size / 1024))KB) ---${NC}"
            echo "File too large to show diff, but modification detected"
        elif [[ $line_count -gt 500 ]]; then
            echo -e "${YELLOW}${BOLD}--- MANY LINES MODIFIED ($line_count lines) ---${NC}"
            echo "File has too many lines to show diff, but modification detected"
        elif [[ "$mime_type" == text/* ]] || [[ "$filepath" == *.txt ]] || [[ "$filepath" == *.md ]] || [[ "$filepath" == *.sh ]] || [[ "$filepath" == *.py ]] || [[ "$filepath" == *.js ]] || [[ "$filepath" == *.json ]] || [[ "$filepath" == *.yml ]] || [[ "$filepath" == *.yaml ]] || [[ "$filepath" == *.xml ]] || [[ "$filepath" == *.html ]] || [[ "$filepath" == *.css ]]; then
            if [[ -f "$backup_file" ]]; then
                echo -e "${BLUE}${BOLD}--- DIFF ---${NC}"
                local diff_output=$(diff -u "$backup_file" "$filepath" 2>/dev/null)
                if [[ -n "$diff_output" ]]; then
                    echo "$diff_output" | head -50 | while IFS= read -r line; do
                        if [[ "$line" =~ ^--- ]]; then
                            echo -e "${GRAY}$line${NC}"
                        elif [[ "$line" =~ ^\+\+\+ ]]; then
                            echo -e "${GRAY}$line${NC}"
                        elif [[ "$line" =~ ^@@ ]]; then
                            echo -e "${PURPLE}$line${NC}"
                        elif [[ "$line" =~ ^\+ ]]; then
                            echo -e "${GREEN}$line${NC}"
                        elif [[ "$line" =~ ^\- ]]; then
                            echo -e "${RED}$line${NC}"
                        else
                            echo "$line"
                        fi
                    done
                    local diff_lines=$(echo "$diff_output" | wc -l)
                    if [[ $diff_lines -gt 50 ]]; then
                        echo -e "${GRAY}... ($(($diff_lines - 50)) more diff lines truncated)${NC}"
                    fi
                else
                    echo -e "${GRAY}File modified but no content changes detected${NC}"
                fi
            else
                echo -e "${YELLOW}${BOLD}--- FIRST CHANGE DETECTED (creating backup) ---${NC}"
                echo "Current content (first 20 lines):"
                head -20 "$filepath" | sed 's/^/  /'
                if [[ $line_count -gt 20 ]]; then
                    echo "  ... ($(( $line_count - 20 )) more lines)"
                fi
            fi
            
            # Create/update backup for next comparison
            cp "$filepath" "$backup_file" 2>/dev/null
        else
            echo -e "${PURPLE}${BOLD}--- BINARY FILE MODIFIED ($(($file_size / 1024))KB, type: $mime_type) ---${NC}"
            echo "Binary file changed, cannot show diff"
        fi
        echo
    fi
}


# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"
    exit 0
}

trap cleanup EXIT INT TERM

echo "tail-folder.sh v2.0 - File Change Monitor (Lazy Backup Mode)"
echo "Monitoring changes in: $FOLDER"
echo "Press Ctrl+C to stop"
echo "Temporary files stored in: $TEMP_DIR"
echo "----------------------------------------"

# Detect OS and use appropriate tool
if command -v inotifywait >/dev/null 2>&1; then
    # Linux - using inotify-tools
    inotifywait -m -r -e modify,create,delete,move --format '%T|%w%f|%e' --timefmt '%Y-%m-%d %H:%M:%S' "$FOLDER" | while IFS='|' read timestamp filepath event; do
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