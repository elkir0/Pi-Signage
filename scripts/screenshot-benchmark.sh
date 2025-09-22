#!/bin/bash
# PiSignage v0.8.0 - Screenshot Performance Benchmark
# Tests performance of different screenshot methods

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BENCHMARK_DIR="/tmp/pisignage-benchmark"
ITERATIONS=5
TIMEOUT=30

print_header() {
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC} ${CYAN}$1${NC} ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_result() {
    local method="$1"
    local status="$2"
    local time="$3"
    local size="$4"
    local details="$5"

    printf "%-15s " "$method"

    if [[ "$status" == "success" ]]; then
        printf "${GREEN}✓${NC} "
    elif [[ "$status" == "warning" ]]; then
        printf "${YELLOW}⚠${NC} "
    else
        printf "${RED}✗${NC} "
    fi

    printf "%-8s %-10s %s\n" "$time" "$size" "$details"
}

get_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        if [[ $size -gt 1048576 ]]; then
            echo "$((size / 1048576))MB"
        elif [[ $size -gt 1024 ]]; then
            echo "$((size / 1024))KB"
        else
            echo "${size}B"
        fi
    else
        echo "0B"
    fi
}

benchmark_method() {
    local method="$1"
    local total_time=0
    local success_count=0
    local total_size=0
    local error_msg=""

    print_header "Testing $method (${ITERATIONS} iterations)"

    for ((i=1; i<=ITERATIONS; i++)); do
        local test_file="$BENCHMARK_DIR/test-${method}-${i}.png"
        local start_time=$(date +%s.%3N)

        case "$method" in
            "raspi2png")
                if command -v raspi2png >/dev/null 2>&1; then
                    if timeout $TIMEOUT raspi2png -p "$test_file" 2>/dev/null; then
                        success_count=$((success_count + 1))
                    else
                        error_msg="Command failed or timed out"
                    fi
                else
                    error_msg="raspi2png not installed"
                    break
                fi
                ;;
            "scrot")
                if command -v scrot >/dev/null 2>&1; then
                    if timeout $TIMEOUT env DISPLAY=:0 scrot "$test_file" 2>/dev/null; then
                        success_count=$((success_count + 1))
                    else
                        error_msg="Command failed (may need X11)"
                    fi
                else
                    error_msg="scrot not installed"
                    break
                fi
                ;;
            "import")
                if command -v import >/dev/null 2>&1; then
                    if timeout $TIMEOUT env DISPLAY=:0 import -window root "$test_file" 2>/dev/null; then
                        success_count=$((success_count + 1))
                    else
                        error_msg="Command failed (may need X11)"
                    fi
                else
                    error_msg="ImageMagick not installed"
                    break
                fi
                ;;
            "fbgrab")
                if command -v fbgrab >/dev/null 2>&1; then
                    if timeout $TIMEOUT fbgrab "$test_file" 2>/dev/null; then
                        success_count=$((success_count + 1))
                    else
                        error_msg="Command failed"
                    fi
                else
                    error_msg="fbgrab not installed"
                    break
                fi
                ;;
        esac

        local end_time=$(date +%s.%3N)
        local iteration_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        total_time=$(echo "$total_time + $iteration_time" | bc -l 2>/dev/null || echo "$total_time")

        if [[ -f "$test_file" ]] && [[ -s "$test_file" ]]; then
            local file_size=$(stat -c%s "$test_file" 2>/dev/null || echo "0")
            total_size=$((total_size + file_size))
            echo "  Iteration $i: ${iteration_time}s, $(get_file_size "$test_file")"
        else
            echo "  Iteration $i: Failed - no valid file generated"
        fi
    done

    if [[ $success_count -gt 0 ]]; then
        local avg_time=$(echo "scale=3; $total_time / $success_count" | bc -l 2>/dev/null || echo "0")
        local avg_size=$((total_size / success_count))
        local avg_size_str=$(echo "$avg_size" | while read size; do
            if [[ $size -gt 1048576 ]]; then
                echo "$((size / 1048576))MB"
            elif [[ $size -gt 1024 ]]; then
                echo "$((size / 1024))KB"
            else
                echo "${size}B"
            fi
        done)

        if [[ $success_count -eq $ITERATIONS ]]; then
            print_result "$method" "success" "${avg_time}s" "$avg_size_str" "$success_count/$ITERATIONS successful"
        else
            print_result "$method" "warning" "${avg_time}s" "$avg_size_str" "$success_count/$ITERATIONS successful"
        fi
    else
        print_result "$method" "fail" "N/A" "N/A" "$error_msg"
    fi

    echo ""
}

system_info() {
    print_header "System Information"

    # Raspberry Pi model
    if [[ -f /proc/cpuinfo ]]; then
        local model=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//' | tail -1 || echo "Unknown")
        echo "Pi Model: $model"
    fi

    # GPU memory
    if command -v vcgencmd >/dev/null 2>&1; then
        local gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null | cut -d= -f2 || echo "unknown")
        echo "GPU Memory: $gpu_mem"
    fi

    # Display configuration
    if [[ -f /boot/config.txt ]]; then
        echo "Display driver:"
        if grep -q "dtoverlay=vc4-kms-v3d" /boot/config.txt; then
            echo "  KMS (vc4-kms-v3d)"
        elif grep -q "dtoverlay=vc4-fkms-v3d" /boot/config.txt; then
            echo "  FKMS (vc4-fkms-v3d)"
        else
            echo "  Legacy"
        fi
    fi

    # X11 status
    if [[ -n "${DISPLAY:-}" ]]; then
        echo "X11 Display: $DISPLAY"
    else
        echo "X11 Display: Not set"
    fi

    # Available screenshot tools
    echo ""
    echo "Available tools:"
    command -v raspi2png >/dev/null 2>&1 && echo "  ✓ raspi2png" || echo "  ✗ raspi2png"
    command -v scrot >/dev/null 2>&1 && echo "  ✓ scrot" || echo "  ✗ scrot"
    command -v import >/dev/null 2>&1 && echo "  ✓ import (ImageMagick)" || echo "  ✗ import (ImageMagick)"
    command -v fbgrab >/dev/null 2>&1 && echo "  ✓ fbgrab" || echo "  ✗ fbgrab"

    echo ""
}

run_benchmark() {
    print_header "PiSignage Screenshot Performance Benchmark"

    # Create benchmark directory
    rm -rf "$BENCHMARK_DIR"
    mkdir -p "$BENCHMARK_DIR"

    # Show system info
    system_info

    # Test each available method
    local methods=("raspi2png" "scrot" "import" "fbgrab")

    print_header "Performance Results"
    printf "%-15s %-2s %-8s %-10s %s\n" "Method" "St" "Avg Time" "Avg Size" "Details"
    printf "%-15s %-2s %-8s %-10s %s\n" "------" "--" "--------" "--------" "-------"

    for method in "${methods[@]}"; do
        benchmark_method "$method" | tail -1
    done

    echo ""
}

analyze_results() {
    print_header "Analysis and Recommendations"

    echo -e "${BLUE}Performance Analysis:${NC}"
    echo ""

    # Check for working methods
    local working_methods=()
    for method in raspi2png scrot import fbgrab; do
        if command -v "$method" >/dev/null 2>&1; then
            working_methods+=("$method")
        fi
    done

    if [[ ${#working_methods[@]} -eq 0 ]]; then
        echo -e "${RED}⚠ No screenshot methods available!${NC}"
        echo "Run: sudo /opt/pisignage/scripts/install-screenshot.sh"
        return
    fi

    echo -e "${GREEN}Available methods: ${working_methods[*]}${NC}"
    echo ""

    # Recommendations based on environment
    echo -e "${BLUE}Recommendations:${NC}"

    if command -v raspi2png >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Use raspi2png for production${NC} (fastest, lowest CPU usage)"
    else
        echo -e "${YELLOW}⚠ Install raspi2png for best performance${NC}"
        echo "  Run: sudo /opt/pisignage/scripts/install-screenshot.sh"
    fi

    if [[ -n "${DISPLAY:-}" ]]; then
        echo -e "${GREEN}✓ X11 methods available${NC} (scrot, import)"
    else
        echo -e "${YELLOW}⚠ No X11 display${NC} (scrot/import may not work)"
        echo "  Prefer: raspi2png or fbgrab"
    fi

    # GPU memory check
    if command -v vcgencmd >/dev/null 2>&1; then
        local gpu_mem=$(vcgencmd get_mem gpu 2>/dev/null | cut -d= -f2 | sed 's/M//' || echo "0")
        if [[ ${gpu_mem:-0} -lt 256 ]]; then
            echo -e "${YELLOW}⚠ GPU memory is ${gpu_mem}M${NC} (recommend 256M for raspi2png)"
            echo "  Add to /boot/config.txt: gpu_mem=256"
        else
            echo -e "${GREEN}✓ GPU memory optimized${NC} (${gpu_mem}M)"
        fi
    fi

    echo ""
}

cleanup() {
    print_header "Cleaning up benchmark files"
    rm -rf "$BENCHMARK_DIR"
    echo "Benchmark files removed"
}

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --iterations N    Number of test iterations per method (default: $ITERATIONS)"
    echo "  --timeout N       Timeout per screenshot in seconds (default: $TIMEOUT)"
    echo "  --method METHOD   Test only specific method (raspi2png, scrot, import, fbgrab)"
    echo "  --quick          Quick test (1 iteration)"
    echo "  --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run full benchmark"
    echo "  $0 --quick           # Quick test"
    echo "  $0 --method raspi2png # Test only raspi2png"
    echo "  $0 --iterations 10    # 10 iterations per method"
}

main() {
    local specific_method=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --iterations)
                ITERATIONS="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --method)
                specific_method="$2"
                shift 2
                ;;
            --quick)
                ITERATIONS=1
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Check if bc is available for time calculations
    if ! command -v bc >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: bc not available, time calculations may be inaccurate${NC}"
    fi

    # Run benchmark
    if [[ -n "$specific_method" ]]; then
        print_header "PiSignage Screenshot Benchmark - $specific_method only"
        system_info
        benchmark_method "$specific_method"
    else
        run_benchmark
    fi

    analyze_results
    cleanup

    echo -e "${GREEN}Benchmark completed!${NC}"
    echo "For installation help: /opt/pisignage/scripts/screenshot-help.sh installation"
}

# Handle interrupts
trap 'echo -e "\n${RED}Benchmark interrupted${NC}"; cleanup; exit 1' INT TERM

main "$@"