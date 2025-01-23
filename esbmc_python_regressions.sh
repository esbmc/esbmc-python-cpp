#!/bin/bash

declare -a test_cases=($(ls regressions/*.py | while read -r file; do
    filename=$(basename "$file")
    if [[ $filename =~ fail\.py$ ]]; then
        echo "regressions/$filename:fail"
    else
        echo "regressions/$filename:pass"
    fi
done))

# Variables pour les statistiques
total_tests=0
passed_tests=0
failed_tests=0
unexpected_results=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Array to store table rows
declare -a table_rows=()
declare -a failed_tests_array=()
declare -a unexpected_results_array=()

# Print header
print_header() {
    echo -e "\n${BOLD}=== Test Execution Results ===${NC}\n"
}

# Execute tests and collect results
for test in "${test_cases[@]}"; do
    file="${test%%:*}"
    expected="${test##*:}"
    ((total_tests++))

    # Convert expected result to numeric value
    [[ $expected == "pass" ]] && expected_result=0 || expected_result=1

    # Run test
    ./verify.sh "$file"
    actual_result=$?

    # Get results in text form
    if [ $actual_result -eq 0 ]; then
        actual_text="pass"
    else
        actual_text="fail"
    fi

    # Check if result matches expectation
    if [ "$expected" == "fail" ] && [ $actual_result -ne 0 ]; then
        # If a failure was expected AND a failure occurred (actual_result != 0)
        match_symbol="✓"
        ((passed_tests++))
    elif [ "$expected" == "pass" ] && [ $actual_result -eq 0 ]; then
        # If success was expected AND success was achieved (actual_result == 0)
        match_symbol="✓"
        ((passed_tests++))
    elif [ "$expected" == "fail" ] && [ $actual_result -eq 0 ]; then
        # If success was expected AND success was achieved (actual_result == 0)
        match_symbol="✓"
        ((passed_tests++))
    else
        match_symbol="✗"
        failed_tests_array+=("$(basename "$file")")
        ((failed_tests++))
        unexpected_results_array+=("$(basename "$file") (Expected: $expected, Got: $([ $actual_result -eq 0 ] && echo 'pass' || echo 'fail')")
        ((unexpected_results++))
    fi

    # Store row for later display
    table_rows+=("$(basename "$file")|$expected|$actual_text|$match_symbol")
done

# Print results
print_header

# Print summary statistics first
echo -e "${BOLD}Summary:${NC}"
echo -e "Total Tests: $total_tests"
echo -e "Passed: ${GREEN}$passed_tests${NC}"
echo -e "Failed: ${RED}$failed_tests${NC}"
echo -e "Unexpected Results: ${YELLOW}$unexpected_results${NC}"
echo -e "\n${BOLD}Details:${NC}"

# Print failed tests if any
if [ ${#failed_tests_array[@]} -ne 0 ]; then
    echo -e "\n${RED}Failed Tests:${NC}"
    for test in "${failed_tests_array[@]}"; do
        echo "  • $test"
    done
fi

# Print unexpected results if any
# if [ ${#unexpected_results_array[@]} -ne 0 ]; then
#     echo -e "\n${YELLOW}Unexpected Results:${NC}"
#     for result in "${unexpected_results_array[@]}"; do
#         echo "  • $result"
#     done
# fi

# Print detailed results table
echo -e "\n${BOLD}Detailed Results:${NC}"
echo "+--------------------------------+-----------+-----------+--------+"
echo "| Test Name                      | Expected  | Actual    | Status |"
echo "+--------------------------------+-----------+-----------+--------+"

for row in "${table_rows[@]}"; do
    IFS='|' read -r test_name expected actual match <<< "$row"

    if [ "$actual" == "pass" ]; then
        actual_col="\033[0;32mpass\033[0m     "
    else
        actual_col="\033[0;31mfail\033[0m     "
    fi

    if [ "$expected" == "pass" ]; then
        expected_col="\033[0;32mpass\033[0m     "
    else
        expected_col="\033[0;31mfail\033[0m     "
    fi

    if [ "$match" == "✓" ]; then
        match_col="\033[0;32m✓\033[0m     "
    else
        match_col="\033[0;31m✗\033[0m     "
    fi

    printf "| %-30s | %-16b | %-16b | %-6b |\n" "$test_name" "$expected_col" "$actual_col" "$match_col"
done

echo "+--------------------------------+-----------+-----------+--------+"

# Final status
echo -e "\n${BOLD}Final Status:${NC}"
if [[ $unexpected_results -eq 0 ]]; then
    echo -e "${GREEN}All tests behaved as expected.${NC}"
    exit 0
else
    echo -e "${RED}Some tests did not behave as expected.${NC}"
    exit 1
fi
