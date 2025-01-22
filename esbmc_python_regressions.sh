#!/bin/bash

# Array of test cases with file paths and expected results
declare -a test_cases=(
    "diff/annotate-function.py:pass"
    # "diff/annotate-method.py:pass"
    # "diff/arith-ops-fail.py:fail"
    # "diff/assert-arith.py:pass"
    # "diff/assert-fail.py:fail"
    # "diff/assert-string.py:pass"
    # "diff/assert.py:pass"
    # "diff/assign-fail.py:fail"
    # "diff/binary-ops.py:pass"
    # "diff/bitwise-fail.py:fail"
    # "diff/built-in-functions.py:pass"
    # "diff/bytes-assert-fail.py:fail"
    # "diff/bytes-bounds-fail.py:fail"
    # "diff/bytes-neg-index.py:pass"
    # "diff/bytes.py:pass"
    # "diff/chained-comparison-fail.py:fail"
    # "diff/chained-comparison.py:pass"
    # "diff/class-attributes.py:pass"
    # "diff/class-methods-fail.py:fail"
    # "diff/class-methods.py:pass"
    # "diff/classes-fail.py:fail"
    # "diff/classes.py:pass"
    # "diff/compound-assign-fail.py:fail"
    # "diff/compound-assign.py:pass"
    # "diff/constants-fail.py:fail"
    # "diff/constants.py:pass"
    # "diff/dynamic-typing.py:pass"
    # "diff/esbmc-assume-fail.py:fail"
    # "diff/esbmc-assume.py:pass"
    # "diff/exception.py:pass"
    # "diff/float-fail.py:fail"
    # "diff/float.py:pass"
    # "diff/for-loop-fail.py:fail"
    # "diff/for-loop.py:pass"
    # "diff/function-call-fail.py:fail"
    # "diff/function-call-mult-params.py:pass"
    # "diff/function-option-fail.py:fail"
    # "diff/function-option.py:pass"
    # "diff/function-params-fail.py:fail"
    # "diff/function-return-fail.py:fail"
    # "diff/function-return-if.py:pass"
    # "diff/function-return.py:pass"
    # "diff/function-undef.py:pass"
    # "diff/github_2224.py:pass"
    # "diff/global.py:pass"
    # "diff/if-else-fail.py:fail"
    # "diff/if-else.py:pass"
    # "diff/if-global-var.py:pass"
    # "diff/import-as-fail.py:fail"
    # "diff/import-as.py:pass"
    # "diff/import-from-all.py:pass"
    # "diff/import-from-class-fail.py:fail"
    # "diff/import-from-class.py:pass"
    # "diff/import-from-function-fail.py:fail"
    # "diff/import-from-function.py:pass"
    # "diff/import-from-multiple-fail.py:fail"
    # "diff/import-from-multiple.py:pass"
    # "diff/import-math.py:pass"
    # "diff/import-os.py:pass"
    # "diff/import.py:pass"
    # "diff/inheritance-fail.py:fail"
    # "diff/inheritance.py:pass"
    # "diff/int_bit_length.py:pass"
    # "diff/int_bit_length_fail.py:fail"
    # "diff/int_from_bytes.py:pass"
    # "diff/int_from_bytes_fail.py:fail"
    # "diff/len-fail.py:fail"
    # "diff/len.py:pass"
    # "diff/len2-fail.py:fail"
    # "diff/len2.py:pass"
    # "diff/list-fail.py:fail"
    # "diff/list.py:pass"
    # "diff/list2.py:pass"
    # "diff/logical-and-success.py:pass"
    # "diff/logical-and.py:pass"
    # "diff/logical-not-fail.py:fail"
    # "diff/logical-not-success.py:pass"
    # "diff/logical-or-success.py:pass"
    # "diff/logical-or.py:pass"
    # "diff/mod-fail.py:fail"
    # "diff/nondet-fail.py:fail"
    # "diff/nondet-verifier-fail.py:fail"
    # "diff/nondet-verifier.py:pass"
    # "diff/nondet.py:pass"
    # "diff/pass.py:pass"
    # "diff/range-fail.py:fail"
    # "diff/range.py:pass"
    # "diff/recursion-fail.py:fail"
    # "diff/recursion.py:pass"
    # "diff/strings-bounds-fail.py:fail"
    # "diff/strings-concat-fail.py:fail"
    # "diff/strings-concat.py:pass"
    # "diff/strings-eq-fail.py:fail"
    # "diff/strings.py:pass"
    # "diff/ternary_operator.py:pass"
    # "diff/try-fail.py:fail"
    # "diff/var-declarations.py:pass"
    # "diff/verifier-assume-fail.py:fail"
    # "diff/verifier-assume.py:pass"
    # "diff/while-break-fail.py:fail"
    # "diff/while-break.py:pass"
    # "diff/while-continue-fail.py:fail"
    # "diff/while-continue.py:pass"
    # "diff/while-fail.py:fail"
    # "diff/while-fail_GtE.py:fail"
    # "diff/while-fail_LtE.py:fail"
    # "diff/while.py:pass"
    # "diff/while_GtE.py:pass"
    # "diff/while_LtE.py:pass"
)

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
    ./verify.sh "$file" 2>/dev/null
    actual_result=$?

    # Get results in text form
    if [ $actual_result -eq 0 ]; then
        actual_text="pass"
        ((passed_tests++))
    else
        actual_text="fail"
        failed_tests_array+=("$(basename "$file")")
        ((failed_tests++))
    fi

    # Check if result matches expectation
    if [ $actual_result -eq $expected_result ]; then
        match_symbol="✓"
    else
        match_symbol="✗"
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
if [ ${#unexpected_results_array[@]} -ne 0 ]; then
    echo -e "\n${YELLOW}Unexpected Results:${NC}"
    for result in "${unexpected_results_array[@]}"; do
        echo "  • $result"
    done
fi

# Print detailed results table
echo -e "\n${BOLD}Detailed Results:${NC}"
echo "+--------------------------------+-----------+-----------+--------+"
echo "| Test Name                      | Expected  | Actual    | Status |"
echo "+--------------------------------+-----------+-----------+--------+"

for row in "${table_rows[@]}"; do
    IFS='|' read -r test_name expected actual match <<< "$row"
    printf "| %-30s | %-9s | %-9s | %-6s   |\n" "$test_name" "$expected" "$actual" "$match"
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