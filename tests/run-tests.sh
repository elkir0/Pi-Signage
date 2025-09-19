#!/bin/bash

# PiSignage Test Suite
# Comprehensive testing for installation, configuration, and functionality

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_RESULTS_DIR="$PROJECT_DIR/logs/test-results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"

log_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$result" == "PASS" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}[PASS]${NC} $test_name: $message"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}[FAIL]${NC} $test_name: $message"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$result] $test_name: $message" >> "$TEST_RESULTS_DIR/test-run-$(date '+%Y%m%d-%H%M%S').log"
}

test_file_exists() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        log_test_result "FILE_EXISTS" "PASS" "$description: $file"
        return 0
    else
        log_test_result "FILE_EXISTS" "FAIL" "$description: $file not found"
        return 1
    fi
}

test_directory_exists() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "$dir" ]]; then
        log_test_result "DIR_EXISTS" "PASS" "$description: $dir"
        return 0
    else
        log_test_result "DIR_EXISTS" "FAIL" "$description: $dir not found"
        return 1
    fi
}

test_script_executable() {
    local script="$1"
    local description="$2"
    
    if [[ -x "$script" ]]; then
        log_test_result "EXECUTABLE" "PASS" "$description: $script"
        return 0
    else
        log_test_result "EXECUTABLE" "FAIL" "$description: $script not executable"
        return 1
    fi
}

test_script_syntax() {
    local script="$1"
    local description="$2"
    
    if bash -n "$script" 2>/dev/null; then
        log_test_result "SYNTAX" "PASS" "$description: $script"
        return 0
    else
        log_test_result "SYNTAX" "FAIL" "$description: $script has syntax errors"
        return 1
    fi
}

test_php_syntax() {
    local php_file="$1"
    local description="$2"
    
    if php -l "$php_file" >/dev/null 2>&1; then
        log_test_result "PHP_SYNTAX" "PASS" "$description: $php_file"
        return 0
    else
        log_test_result "PHP_SYNTAX" "FAIL" "$description: $php_file has syntax errors"
        return 1
    fi
}

echo -e "${BLUE}=== PiSignage Test Suite ===${NC}"
echo "Starting comprehensive tests..."
echo

# Test project structure
echo -e "${YELLOW}Testing project structure...${NC}"
test_directory_exists "$PROJECT_DIR/src" "Source directory"
test_directory_exists "$PROJECT_DIR/deploy" "Deployment directory"
test_directory_exists "$PROJECT_DIR/docs" "Documentation directory"
test_directory_exists "$PROJECT_DIR/web" "Web interface directory"
test_directory_exists "$PROJECT_DIR/tests" "Tests directory"

# Test essential files
echo -e "${YELLOW}Testing essential files...${NC}"
test_file_exists "$PROJECT_DIR/README.md" "Main README"
test_file_exists "$PROJECT_DIR/LICENSE" "License file"
test_file_exists "$PROJECT_DIR/Makefile" "Makefile"
test_file_exists "$PROJECT_DIR/docker-compose.yml" "Docker Compose file"
test_file_exists "$PROJECT_DIR/.gitignore" "Git ignore file"

# Test deployment scripts
echo -e "${YELLOW}Testing deployment scripts...${NC}"
for script in "$PROJECT_DIR"/deploy/*.sh; do
    if [[ -f "$script" ]]; then
        test_script_executable "$script" "Deployment script executable"
        test_script_syntax "$script" "Deployment script syntax"
    fi
done

# Test source scripts
echo -e "${YELLOW}Testing source scripts...${NC}"
for script in "$PROJECT_DIR"/src/scripts/*.sh; do
    if [[ -f "$script" ]]; then
        test_script_executable "$script" "Source script executable"
        test_script_syntax "$script" "Source script syntax"
    fi
done

# Test web interface PHP files
echo -e "${YELLOW}Testing web interface...${NC}"
if [[ -d "$PROJECT_DIR/web" ]]; then
    find "$PROJECT_DIR/web" -name "*.php" | while read -r php_file; do
        test_php_syntax "$php_file" "PHP file syntax"
    done
fi

# Test systemd service files
echo -e "${YELLOW}Testing systemd services...${NC}"
if [[ -d "$PROJECT_DIR/src/systemd" ]]; then
    for service_file in "$PROJECT_DIR"/src/systemd/*.service; do
        if [[ -f "$service_file" ]]; then
            test_file_exists "$service_file" "Systemd service file"
            # Basic systemd syntax check
            if grep -q "^\[Unit\]" "$service_file" && grep -q "^\[Service\]" "$service_file"; then
                log_test_result "SYSTEMD_SYNTAX" "PASS" "Valid systemd service: $(basename "$service_file")"
            else
                log_test_result "SYSTEMD_SYNTAX" "FAIL" "Invalid systemd service: $(basename "$service_file")"
            fi
        fi
    done
fi

# Test configuration files
echo -e "${YELLOW}Testing configuration files...${NC}"
if [[ -d "$PROJECT_DIR/src/config" ]]; then
    for config_file in "$PROJECT_DIR"/src/config/*; do
        if [[ -f "$config_file" ]]; then
            test_file_exists "$config_file" "Configuration file"
        fi
    done
fi

# Test Docker configuration
echo -e "${YELLOW}Testing Docker configuration...${NC}"
if command -v docker >/dev/null 2>&1; then
    if docker-compose -f "$PROJECT_DIR/docker-compose.yml" config >/dev/null 2>&1; then
        log_test_result "DOCKER_COMPOSE" "PASS" "Docker Compose configuration valid"
    else
        log_test_result "DOCKER_COMPOSE" "FAIL" "Docker Compose configuration invalid"
    fi
else
    log_test_result "DOCKER_COMPOSE" "FAIL" "Docker not available for testing"
fi

# Summary
echo
echo -e "${BLUE}=== Test Results Summary ===${NC}"
echo "Total tests: $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Check the logs for details.${NC}"
    exit 1
fi