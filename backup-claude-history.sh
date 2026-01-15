#!/bin/bash
set -e

# Configuration
HISTORY_REPO="git@github.com:xavier-xia-99/claude-history.git"
HISTORY_DIR="$HOME/.cache/claude/history-repo"
DATE=$(date +%Y%m%d)
FORCE_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[Claude Backup]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[Claude Backup]${NC} $1"
}

log_error() {
    echo -e "${RED}[Claude Backup]${NC} $1"
}

# Get current project's git info
get_git_info() {
    if [ ! -d .git ]; then
        log_warn "Not a git repository, using 'non-git-projects/$(basename "$PWD")'"
        echo "non-git-projects/$(basename "$PWD")"
        return
    fi

    # Get the remote URL
    REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")

    if [ -z "$REMOTE_URL" ]; then
        log_warn "No git remote found, using 'no-remote/$(basename "$PWD")'"
        echo "no-remote/$(basename "$PWD")"
        return
    fi

    # Extract org/repo from various URL formats
    # Handles: git@github.com:org/repo.git, https://github.com/org/repo.git, etc.
    ORG_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*[:/]([^/]+/[^/]+)(\.git)?$|\1|' | sed 's|\.git$||')

    echo "$ORG_REPO"
}

# Check if .claude directory exists
if [ ! -d .claude ]; then
    log_error "No .claude directory found in current directory"
    exit 1
fi

log_info "Starting Claude history backup..."

# Get project info
PROJECT_PATH=$(get_git_info)
log_info "Project: $PROJECT_PATH"

# Ensure cache directory exists
mkdir -p "$(dirname "$HISTORY_DIR")"

# Clone or update history repo
if [ ! -d "$HISTORY_DIR" ]; then
    log_info "Cloning history repository..."
    git clone --quiet "$HISTORY_REPO" "$HISTORY_DIR"
else
    log_info "Updating history repository..."
    if [ -d "$HISTORY_DIR/.git" ]; then
        cd "$HISTORY_DIR"
        git pull --quiet origin main 2>/dev/null || git pull --quiet origin master 2>/dev/null || true
        cd - > /dev/null
    else
        log_error "Invalid history repository (missing .git), removing and re-cloning..."
        rm -rf "$HISTORY_DIR"
        git clone --quiet "$HISTORY_REPO" "$HISTORY_DIR"
    fi
fi

# Create target directory structure
TARGET_DIR="$HISTORY_DIR/$PROJECT_PATH/$DATE"
mkdir -p "$TARGET_DIR"

log_info "Backing up to: $PROJECT_PATH/$DATE/"

# Scan for secrets
SECRETS_FOUND=false
EXCLUDE_FILES=()

log_info "Scanning for secrets..."
SECRET_PATTERNS="(api[_-]?key|apikey|API_KEY|secret|SECRET|password|PASSWORD|token|TOKEN|bearer|BEARER|authorization|AUTHORIZATION|private[_-]?key|aws[_-]?access|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36})"

# Scan .claude directory
if [ -d .claude ]; then
    while IFS= read -r line; do
        SECRETS_FOUND=true
        FILE=$(echo "$line" | cut -d: -f1)
        CONTEXT=$(echo "$line" | cut -d: -f2-)
        log_error "Secret found in: $FILE"
        log_error "  Context: $(echo "$CONTEXT" | head -c 100)..."
        EXCLUDE_FILES+=("$FILE")
    done < <(grep -rE "$SECRET_PATTERNS" .claude/ 2>/dev/null || true)
fi

# Scan CLAUDE.md
if [ -f CLAUDE.md ]; then
    if grep -qE "$SECRET_PATTERNS" CLAUDE.md 2>/dev/null; then
        SECRETS_FOUND=true
        MATCHED_LINES=$(grep -nE "$SECRET_PATTERNS" CLAUDE.md | head -n 5)
        log_error "Secret found in: CLAUDE.md"
        echo "$MATCHED_LINES" | while IFS= read -r line; do
            log_error "  Line: $(echo "$line" | head -c 100)..."
        done
        EXCLUDE_FILES+=("CLAUDE.md")
    fi
fi

# Scan review.md
if [ -f review.md ]; then
    if grep -qE "$SECRET_PATTERNS" review.md 2>/dev/null; then
        SECRETS_FOUND=true
        MATCHED_LINES=$(grep -nE "$SECRET_PATTERNS" review.md | head -n 5)
        log_error "Secret found in: review.md"
        echo "$MATCHED_LINES" | while IFS= read -r line; do
            log_error "  Line: $(echo "$line" | head -c 100)..."
        done
        EXCLUDE_FILES+=("review.md")
    fi
fi

# Handle secrets
if [ "$SECRETS_FOUND" = true ]; then
    if [ "$FORCE_MODE" = false ]; then
        log_error ""
        log_error "⚠️  SECRETS DETECTED! Backup aborted to prevent leaking credentials."
        log_error ""
        log_error "Files with potential secrets:"
        for file in "${EXCLUDE_FILES[@]}"; do
            log_error "  - $file"
        done
        log_error ""
        log_error "Options:"
        log_error "  1. Remove secrets from these files and run again"
        log_error "  2. Run with --force flag to skip files containing secrets"
        log_error ""
        log_error "Command: ~/.claude/scripts/backup-claude-history.sh --force"
        exit 1
    else
        log_warn ""
        log_warn "⚠️  FORCE MODE: Skipping files with secrets"
        for file in "${EXCLUDE_FILES[@]}"; do
            log_warn "  - Excluding: $file"
        done
        log_warn ""
    fi
fi

# Copy .claude directory (excluding secret files if in force mode)
log_info "Copying .claude directory..."
if [ "$FORCE_MODE" = true ] && [ ${#EXCLUDE_FILES[@]} -gt 0 ]; then
    # Create exclude file for rsync
    EXCLUDE_FILE=$(mktemp)
    for file in "${EXCLUDE_FILES[@]}"; do
        # Convert absolute/relative paths to relative from .claude/
        if [[ "$file" == .claude/* ]]; then
            echo "${file#.claude/}" >> "$EXCLUDE_FILE"
        fi
    done
    rsync -av --delete --exclude-from="$EXCLUDE_FILE" .claude/ "$TARGET_DIR/.claude/"
    rm "$EXCLUDE_FILE"
else
    rsync -av --delete .claude/ "$TARGET_DIR/.claude/"
fi

# Copy CLAUDE.md if it exists and not excluded
if [ -f CLAUDE.md ]; then
    if [[ ! " ${EXCLUDE_FILES[@]} " =~ " CLAUDE.md " ]]; then
        log_info "Copying CLAUDE.md..."
        cp CLAUDE.md "$TARGET_DIR/CLAUDE.md"
    else
        log_warn "CLAUDE.md contains secrets (skipped)"
    fi
else
    log_warn "CLAUDE.md not found (skipping)"
fi

# Copy review.md if it exists and not excluded
if [ -f review.md ]; then
    if [[ ! " ${EXCLUDE_FILES[@]} " =~ " review.md " ]]; then
        log_info "Copying review.md..."
        cp review.md "$TARGET_DIR/review.md"
    else
        log_warn "review.md contains secrets (skipped)"
    fi
fi

# Commit and push
cd "$HISTORY_DIR"

# Check if there are changes
if [ -z "$(git status --porcelain)" ]; then
    log_info "No changes to backup"
    exit 0
fi

git add .
git commit -m "Backup: $PROJECT_PATH ($DATE)

Automated backup from Claude Code compaction
Project: $PROJECT_PATH
Date: $DATE
Host: $(hostname)
"

log_info "Pushing to remote..."
git push origin HEAD

log_info "Backup completed successfully!"
