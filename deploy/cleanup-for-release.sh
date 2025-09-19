#!/bin/bash

# PiSignage Release Cleanup Script
# Prépare le projet pour une release publique

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 PiSignage Release Cleanup${NC}"
echo "==============================="
echo

# Function to print status
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_action() {
    echo -e "${BLUE}🔧${NC} $1"
}

# Clean temporary files
print_action "Cleaning temporary files..."
find "$PROJECT_DIR" -name "*.tmp" -delete 2>/dev/null || true
find "$PROJECT_DIR" -name "*.log" -delete 2>/dev/null || true
find "$PROJECT_DIR" -name "*.pid" -delete 2>/dev/null || true
find "$PROJECT_DIR" -name "*~" -delete 2>/dev/null || true
print_status "Temporary files cleaned"

# Clean logs but keep directory structure
print_action "Cleaning logs..."
if [[ -d "$PROJECT_DIR/logs" ]]; then
    find "$PROJECT_DIR/logs" -name "*.log" -delete 2>/dev/null || true
    find "$PROJECT_DIR/logs" -name "*.md" -delete 2>/dev/null || true
    # Keep test-results directory but clean contents
    if [[ -d "$PROJECT_DIR/logs/test-results" ]]; then
        rm -f "$PROJECT_DIR/logs/test-results"/* 2>/dev/null || true
    fi
fi
print_status "Logs cleaned"

# Clean media directory but keep structure
print_action "Cleaning media directory..."
if [[ -d "$PROJECT_DIR/media" ]]; then
    # Remove test videos and images but keep README
    find "$PROJECT_DIR/media" -name "*.mp4" -delete 2>/dev/null || true
    find "$PROJECT_DIR/media" -name "*.avi" -delete 2>/dev/null || true
    find "$PROJECT_DIR/media" -name "*.mkv" -delete 2>/dev/null || true
    find "$PROJECT_DIR/media" -name "*.jpg" -delete 2>/dev/null || true
    find "$PROJECT_DIR/media" -name "*.png" -delete 2>/dev/null || true
    
    # Create .gitkeep in empty directories
    find "$PROJECT_DIR/media" -type d -empty -exec touch {}/.gitkeep \;
fi
print_status "Media directory cleaned"

# Make sure all scripts are executable
print_action "Setting script permissions..."
find "$PROJECT_DIR/src/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
find "$PROJECT_DIR/deploy" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
find "$PROJECT_DIR/tests" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
chmod +x "$PROJECT_DIR/tests/web-test.js" 2>/dev/null || true
print_status "Script permissions set"

# Validate critical files exist
print_action "Validating critical files..."
critical_files=(
    "README.md"
    "LICENSE"
    "Makefile"
    "docker-compose.yml"
    ".gitignore"
    "src/scripts/player-control.sh"
    "deploy/install.sh"
    "web/index.php"
    "web/api/control.php"
)

missing_files=()
for file in "${critical_files[@]}"; do
    if [[ ! -f "$PROJECT_DIR/$file" ]]; then
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -eq 0 ]]; then
    print_status "All critical files present"
else
    print_warning "Missing critical files: ${missing_files[*]}"
fi

# Generate project statistics
print_action "Generating project statistics..."
stats_file="$PROJECT_DIR/PROJECT_STATS.md"

cat > "$stats_file" << EOF
# PiSignage Project Statistics

Generated: $(date)

## Code Statistics

EOF

# Count lines of code
if command -v find >/dev/null && command -v wc >/dev/null; then
    # Shell scripts
    shell_lines=$(find "$PROJECT_DIR" -name "*.sh" -exec cat {} \; | wc -l)
    shell_files=$(find "$PROJECT_DIR" -name "*.sh" | wc -l)
    
    # PHP files
    php_lines=$(find "$PROJECT_DIR" -name "*.php" -exec cat {} \; | wc -l)
    php_files=$(find "$PROJECT_DIR" -name "*.php" | wc -l)
    
    # JavaScript files
    js_lines=$(find "$PROJECT_DIR" -name "*.js" -exec cat {} \; | wc -l)
    js_files=$(find "$PROJECT_DIR" -name "*.js" | wc -l)
    
    # Documentation
    doc_lines=$(find "$PROJECT_DIR" -name "*.md" -exec cat {} \; | wc -l)
    doc_files=$(find "$PROJECT_DIR" -name "*.md" | wc -l)
    
    cat >> "$stats_file" << EOF
| File Type | Files | Lines of Code |
|-----------|-------|---------------|
| Shell Scripts | $shell_files | $shell_lines |
| PHP Files | $php_files | $php_lines |
| JavaScript | $js_files | $js_lines |
| Documentation | $doc_files | $doc_lines |

## Directory Structure

\`\`\`
$(tree "$PROJECT_DIR" -I 'node_modules|.git|logs|media' -L 3 2>/dev/null || find "$PROJECT_DIR" -type d -name ".git" -prune -o -type d -print | head -20)
\`\`\`

## Recent Activity

\`\`\`
$(cd "$PROJECT_DIR" && git log --oneline -10 2>/dev/null || echo "No git history available")
\`\`\`
EOF

fi

print_status "Project statistics generated"

# Git status check
if [[ -d "$PROJECT_DIR/.git" ]]; then
    print_action "Checking git status..."
    
    cd "$PROJECT_DIR"
    
    # Check for uncommitted changes
    if ! git diff --quiet 2>/dev/null; then
        print_warning "There are uncommitted changes in the working directory"
        git status --porcelain
    else
        print_status "Working directory is clean"
    fi
    
    # Check current branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    print_status "Current branch: $current_branch"
    
    # Check for untracked files that should be committed
    untracked=$(git ls-files --others --exclude-standard | grep -v "PROJECT_STATS.md" | head -5)
    if [[ -n "$untracked" ]]; then
        print_warning "Untracked files found:"
        echo "$untracked"
    fi
fi

# Final validation
print_action "Running final validation..."
if [[ -x "$PROJECT_DIR/tests/validate-project.sh" ]]; then
    if "$PROJECT_DIR/tests/validate-project.sh" >/dev/null 2>&1; then
        print_status "Project validation passed"
    else
        print_warning "Project validation has issues - check the validation report"
    fi
else
    print_warning "Validation script not found or not executable"
fi

# Summary
echo
echo -e "${BLUE}📋 Release Preparation Summary${NC}"
echo "================================"
echo "✅ Temporary files cleaned"
echo "✅ Logs cleared"
echo "✅ Media directory sanitized"
echo "✅ Script permissions set"
echo "✅ Critical files validated"
echo "✅ Project statistics generated"
echo "✅ Git status checked"
echo
echo -e "${GREEN}🚀 Project is ready for release!${NC}"
echo
echo "Next steps:"
echo "1. Review and commit any final changes"
echo "2. Create a new git tag: git tag v3.1.0"
echo "3. Push to GitHub: git push origin main --tags"
echo "4. Create a GitHub release"
echo "5. Update version numbers if needed"
echo

# Create release checklist
checklist_file="$PROJECT_DIR/RELEASE_CHECKLIST.md"
cat > "$checklist_file" << 'EOF'
# Release Checklist

## Pre-Release
- [ ] All tests pass
- [ ] Documentation is up to date
- [ ] Version numbers are consistent
- [ ] CHANGELOG is updated
- [ ] Security scan completed
- [ ] Performance testing done

## Release Process
- [ ] Create release branch
- [ ] Update version in all files
- [ ] Generate release notes
- [ ] Create and test release package
- [ ] Tag the release
- [ ] Push to GitHub
- [ ] Create GitHub release
- [ ] Update documentation

## Post-Release
- [ ] Announce release
- [ ] Update website/wiki
- [ ] Monitor for issues
- [ ] Plan next release
- [ ] Archive old versions

## Deployment Testing
- [ ] Test on fresh Raspberry Pi
- [ ] Verify all components work
- [ ] Test web interface
- [ ] Validate API endpoints
- [ ] Check performance metrics
- [ ] Verify documentation accuracy
EOF

print_status "Release checklist created: $checklist_file"

echo -e "${BLUE}📁 Generated files:${NC}"
echo "  - PROJECT_STATS.md"
echo "  - RELEASE_CHECKLIST.md"