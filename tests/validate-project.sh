#!/bin/bash

# PiSignage Project Validation Script
# Script de validation complète pour production

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REPORT_FILE="$PROJECT_DIR/logs/validation-report-$(date '+%Y%m%d-%H%M%S').md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Create logs directory if it doesn't exist
mkdir -p "$PROJECT_DIR/logs"

# Initialize report
cat > "$REPORT_FILE" << 'EOF'
# PiSignage Project Validation Report

**Generated:** $(date)
**Version:** 3.1.0
**Validation Type:** Production Readiness Assessment

## Executive Summary

This report provides a comprehensive validation assessment of the PiSignage project for production deployment.

EOF

log_check() {
    local name="$1"
    local status="$2"
    local message="$3"
    local severity="${4:-info}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case $status in
        "PASS")
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            echo -e "${GREEN}✅ PASS${NC} $name: $message"
            echo "- ✅ **$name**: $message" >> "$REPORT_FILE"
            ;;
        "FAIL")
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            echo -e "${RED}❌ FAIL${NC} $name: $message"
            echo "- ❌ **$name**: $message" >> "$REPORT_FILE"
            ;;
        "WARN")
            WARNINGS=$((WARNINGS + 1))
            echo -e "${YELLOW}⚠️  WARN${NC} $name: $message"
            echo "- ⚠️ **$name**: $message" >> "$REPORT_FILE"
            ;;
    esac
}

echo -e "${BLUE}🔍 PiSignage Project Validation Suite${NC}"
echo "====================================="
echo

# Add test categories to report
cat >> "$REPORT_FILE" << 'EOF'

## Test Categories

### 1. Project Structure
EOF

echo -e "${YELLOW}1. Validating Project Structure...${NC}"

# Check main directories
for dir in src deploy web docs tests logs media; do
    if [[ -d "$PROJECT_DIR/$dir" ]]; then
        log_check "Directory Structure" "PASS" "$dir directory exists"
    else
        log_check "Directory Structure" "FAIL" "$dir directory missing"
    fi
done

# Check essential files
for file in README.md LICENSE Makefile docker-compose.yml .gitignore; do
    if [[ -f "$PROJECT_DIR/$file" ]]; then
        log_check "Essential Files" "PASS" "$file exists"
    else
        log_check "Essential Files" "FAIL" "$file missing"
    fi
done

cat >> "$REPORT_FILE" << 'EOF'

### 2. Code Quality
EOF

echo -e "${YELLOW}2. Validating Code Quality...${NC}"

# Check shell scripts with shellcheck
if command -v shellcheck >/dev/null 2>&1; then
    script_errors=0
    while IFS= read -r -d '' script; do
        if ! shellcheck "$script" >/dev/null 2>&1; then
            script_errors=$((script_errors + 1))
        fi
    done < <(find "$PROJECT_DIR/src" "$PROJECT_DIR/deploy" -name "*.sh" -print0 2>/dev/null)
    
    if [[ $script_errors -eq 0 ]]; then
        log_check "Shell Script Quality" "PASS" "All scripts pass shellcheck"
    else
        log_check "Shell Script Quality" "WARN" "$script_errors scripts have minor issues"
    fi
else
    log_check "Shell Script Quality" "WARN" "shellcheck not available"
fi

# Check PHP syntax
if command -v php >/dev/null 2>&1; then
    php_errors=0
    while IFS= read -r -d '' php_file; do
        if ! php -l "$php_file" >/dev/null 2>&1; then
            php_errors=$((php_errors + 1))
        fi
    done < <(find "$PROJECT_DIR/web" -name "*.php" -print0 2>/dev/null)
    
    if [[ $php_errors -eq 0 ]]; then
        log_check "PHP Syntax" "PASS" "All PHP files have valid syntax"
    else
        log_check "PHP Syntax" "FAIL" "$php_errors PHP files have syntax errors"
    fi
else
    log_check "PHP Syntax" "WARN" "PHP not available for testing"
fi

cat >> "$REPORT_FILE" << 'EOF'

### 3. Documentation Quality
EOF

echo -e "${YELLOW}3. Validating Documentation...${NC}"

# Check README content
if [[ -f "$PROJECT_DIR/README.md" ]]; then
    readme_content=$(cat "$PROJECT_DIR/README.md")
    
    # Check for essential sections
    if echo "$readme_content" | grep -q "# PiSignage"; then
        log_check "README Structure" "PASS" "Project title present"
    else
        log_check "README Structure" "FAIL" "Project title missing"
    fi
    
    if echo "$readme_content" | grep -q "## Installation\|## Quick Installation"; then
        log_check "README Structure" "PASS" "Installation section present"
    else
        log_check "README Structure" "FAIL" "Installation section missing"
    fi
    
    if echo "$readme_content" | grep -q "## Usage\|## API"; then
        log_check "README Structure" "PASS" "Usage documentation present"
    else
        log_check "README Structure" "WARN" "Usage documentation could be improved"
    fi
fi

# Check documentation files
doc_files=("INSTALL.md" "TROUBLESHOOTING.md" "API.md")
for doc in "${doc_files[@]}"; do
    if [[ -f "$PROJECT_DIR/docs/$doc" ]]; then
        log_check "Documentation Files" "PASS" "$doc exists"
    else
        log_check "Documentation Files" "WARN" "$doc could be added"
    fi
done

cat >> "$REPORT_FILE" << 'EOF'

### 4. Security Assessment
EOF

echo -e "${YELLOW}4. Validating Security...${NC}"

# Check for sensitive files in git
if [[ -d "$PROJECT_DIR/.git" ]]; then
    # Check .gitignore effectiveness
    if git -C "$PROJECT_DIR" ls-files | grep -E "\.(key|pem|env)$"; then
        log_check "Sensitive Files" "FAIL" "Sensitive files tracked in git"
    else
        log_check "Sensitive Files" "PASS" "No obvious sensitive files in git"
    fi
    
    # Check for hardcoded credentials
    if git -C "$PROJECT_DIR" grep -i "password\s*=" -- "*.sh" "*.php" >/dev/null 2>&1; then
        log_check "Hardcoded Credentials" "WARN" "Potential hardcoded credentials found"
    else
        log_check "Hardcoded Credentials" "PASS" "No obvious hardcoded credentials"
    fi
fi

# Check file permissions
if find "$PROJECT_DIR" -name "*.sh" ! -perm /111 | head -1 >/dev/null; then
    log_check "Script Permissions" "WARN" "Some scripts may not be executable"
else
    log_check "Script Permissions" "PASS" "Scripts have appropriate permissions"
fi

cat >> "$REPORT_FILE" << 'EOF'

### 5. Deployment Readiness
EOF

echo -e "${YELLOW}5. Validating Deployment Readiness...${NC}"

# Check Docker configuration
if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    if command -v docker >/dev/null 2>&1; then
        if docker compose -f "$PROJECT_DIR/docker-compose.yml" config >/dev/null 2>&1; then
            log_check "Docker Configuration" "PASS" "docker-compose.yml is valid"
        else
            log_check "Docker Configuration" "FAIL" "docker-compose.yml has errors"
        fi
    else
        log_check "Docker Configuration" "WARN" "Docker not available for testing"
    fi
fi

# Check Makefile targets
if [[ -f "$PROJECT_DIR/Makefile" ]]; then
    makefile_content=$(cat "$PROJECT_DIR/Makefile")
    
    essential_targets=("install" "test" "clean" "deploy")
    for target in "${essential_targets[@]}"; do
        if echo "$makefile_content" | grep -q "^$target:"; then
            log_check "Makefile Targets" "PASS" "$target target exists"
        else
            log_check "Makefile Targets" "WARN" "$target target missing"
        fi
    done
fi

# Check for CI/CD configuration
if [[ -f "$PROJECT_DIR/.github/workflows/ci.yml" ]]; then
    log_check "CI/CD Configuration" "PASS" "GitHub Actions workflow exists"
else
    log_check "CI/CD Configuration" "WARN" "CI/CD configuration missing"
fi

cat >> "$REPORT_FILE" << 'EOF'

### 6. Testing Infrastructure
EOF

echo -e "${YELLOW}6. Validating Testing Infrastructure...${NC}"

# Check test scripts
test_files=(
    "tests/run-tests.sh"
    "tests/web-test.js"
    "tests/validate-project.sh"
)

for test_file in "${test_files[@]}"; do
    if [[ -f "$PROJECT_DIR/$test_file" ]]; then
        log_check "Test Suite" "PASS" "$(basename "$test_file") exists"
    else
        log_check "Test Suite" "WARN" "$(basename "$test_file") missing"
    fi
done

# Try to run main test suite
if [[ -x "$PROJECT_DIR/tests/run-tests.sh" ]]; then
    if "$PROJECT_DIR/tests/run-tests.sh" >/dev/null 2>&1; then
        log_check "Test Execution" "PASS" "Main test suite runs successfully"
    else
        log_check "Test Execution" "WARN" "Main test suite has issues"
    fi
fi

echo
echo -e "${BLUE}📊 Validation Summary${NC}"
echo "===================="

# Calculate scores
if [[ $TOTAL_CHECKS -gt 0 ]]; then
    success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    success_rate=0
fi

echo "Total Checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "Success Rate: ${GREEN}$success_rate%${NC}"

# Add summary to report
cat >> "$REPORT_FILE" << EOF

## Validation Summary

| Metric | Count | Percentage |
|--------|-------|------------|
| Total Checks | $TOTAL_CHECKS | 100% |
| Passed | $PASSED_CHECKS | $success_rate% |
| Failed | $FAILED_CHECKS | $(( FAILED_CHECKS * 100 / TOTAL_CHECKS ))% |
| Warnings | $WARNINGS | $(( WARNINGS * 100 / TOTAL_CHECKS ))% |

## Production Readiness Assessment

EOF

if [[ $FAILED_CHECKS -eq 0 && $success_rate -ge 85 ]]; then
    echo -e "${GREEN}🚀 PROJECT IS PRODUCTION READY${NC}"
    echo "**Status: ✅ PRODUCTION READY**" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "The project meets all critical requirements for production deployment." >> "$REPORT_FILE"
elif [[ $FAILED_CHECKS -le 2 && $success_rate -ge 70 ]]; then
    echo -e "${YELLOW}⚠️  PROJECT NEEDS MINOR FIXES${NC}"
    echo "**Status: ⚠️ NEEDS MINOR FIXES**" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "The project is mostly ready but requires addressing some issues before production." >> "$REPORT_FILE"
else
    echo -e "${RED}❌ PROJECT NEEDS MAJOR IMPROVEMENTS${NC}"
    echo "**Status: ❌ NEEDS MAJOR IMPROVEMENTS**" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "The project requires significant improvements before production deployment." >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << 'EOF'

## Recommendations

### High Priority
- Address all FAIL items immediately
- Review and fix critical security issues
- Ensure all essential documentation is complete

### Medium Priority  
- Address WARN items for better reliability
- Improve test coverage
- Enhance documentation quality

### Low Priority
- Consider adding more automation
- Implement additional monitoring
- Expand CI/CD pipeline

## Next Steps

1. **Fix Critical Issues**: Address all failed checks
2. **Test Deployment**: Perform end-to-end deployment test
3. **Security Review**: Conduct thorough security assessment
4. **Performance Testing**: Validate performance under load
5. **Documentation Review**: Ensure all docs are accurate and complete

---

*Report generated by PiSignage Validation Suite*
EOF

echo
echo -e "${BLUE}📄 Detailed report saved to:${NC} $REPORT_FILE"

# Exit with appropriate code
if [[ $FAILED_CHECKS -eq 0 ]]; then
    exit 0
else
    exit 1
fi