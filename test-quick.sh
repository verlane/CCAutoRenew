#!/bin/bash

# Quick test script for Claude Auto-Renewal
# Validates all functionality in under 1 minute

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

print_test() {
    echo -e "\n${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}        Claude Auto-Renewal Quick Test   ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Test 1: Check required script files
print_test "Checking script files"
scripts=(
    "claude-daemon-manager.sh"
    "claude-auto-renew-daemon.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        print_pass "$script exists and is executable"
    else
        print_fail "$script missing or not executable"
    fi
done

# Test 2: Check basic dependencies
print_test "Checking dependencies"

if command -v claude &> /dev/null; then
    print_pass "Claude CLI found"
else
    print_info "Claude CLI not found (installation required)"
fi

# Test 3: Test daemon manager
print_test "Testing daemon manager"
if ./claude-daemon-manager.sh --help 2>&1 | grep -q "Usage"; then
    print_pass "Daemon manager help working"
else
    print_fail "Daemon manager help error"
fi

# Test 4: Check fixed schedule
print_test "Checking fixed schedule logic"
if grep -q "06:00.*11:00.*16:00.*21:00" ./claude-auto-renew-daemon.sh; then
    print_pass "Fixed schedule (06:00, 11:00, 16:00, 21:00) implemented"
else
    print_fail "Fixed schedule logic missing"
fi

# Test 5: Check blackout period
print_test "Checking blackout period feature"
if grep -q "blackout\|01:00-05:59" ./claude-auto-renew-daemon.sh; then
    print_pass "Blackout period (01:00-05:59) implemented"
else
    print_fail "Blackout period logic missing"
fi

# Test 6: Check retry mechanism
print_test "Checking retry mechanism"
if grep -q "max_retries=10" ./claude-auto-renew-daemon.sh; then
    print_pass "Retry mechanism (max 10) implemented"
else
    print_fail "Retry mechanism missing"
fi

# Test 7: Check smart check intervals
print_test "Checking smart check intervals"
if grep -q "sleep_duration=60" ./claude-auto-renew-daemon.sh && grep -q "sleep_duration=1800" ./claude-auto-renew-daemon.sh; then
    print_pass "Smart check intervals (1min/30min) implemented"
else
    print_fail "Smart check interval logic missing"
fi

# Test 8: Bash syntax check
print_test "Checking script syntax"
bash -n ./claude-auto-renew-daemon.sh 2>/dev/null
if [ $? -eq 0 ]; then
    print_pass "Daemon script syntax OK"
else
    print_fail "Daemon script syntax error"
fi

bash -n ./claude-daemon-manager.sh 2>/dev/null
if [ $? -eq 0 ]; then
    print_pass "Manager script syntax OK"
else
    print_fail "Manager script syntax error"
fi

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}             TEST RESULTS SUMMARY        ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total Tests: ${BLUE}$((TESTS_PASSED + TESTS_FAILED))${NC}"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 Quick test passed! Auto-renewal is properly configured.${NC}"
    echo ""
    echo "Next steps:"
    echo "  • Start daemon: ./claude-daemon-manager.sh start"
    echo "  • Check status: ./claude-daemon-manager.sh status"
    echo "  • View logs: tail -f ~/.claude-auto-renew-daemon.log"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed. Please check the issues above.${NC}"
    exit 1
fi