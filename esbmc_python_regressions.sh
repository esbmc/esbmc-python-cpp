#!/bin/bash

# Array of test cases with file paths and expected results
declare -a test_cases=(
    "regressions/annotate_function.py:pass"
    "regressions/annotate_method.py:pass"
    "regressions/arith_ops_fail.py:fail"
    "regressions/assert_arith.py:pass"
    "regressions/assert_fail.py:fail"
    "regressions/assert_string.py:pass"
    "regressions/assert.py:pass"
    "regressions/assign_fail.py:fail"
    "regressions/binary_ops.py:pass"
    "regressions/bitwise_fail.py:fail"
    "regressions/built_in_functions.py:pass"
    "regressions/bytes_assert_fail.py:fail"
    "regressions/bytes_bounds_fail.py:fail"
    "regressions/bytes_neg_index.py:pass"
    "regressions/bytes.py:pass"
    "regressions/chained_comparison_fail.py:fail"
    "regressions/chained_comparison.py:pass"
    "regressions/class_attributes.py:pass"
    "regressions/class_methods_fail.py:fail"
    "regressions/class_methods.py:pass"
    "regressions/classes_fail.py:fail"
    "regressions/classes.py:pass"
    "regressions/compound_assign_fail.py:fail"
    "regressions/compound_assign.py:pass"
    "regressions/constants_fail.py:fail"
    "regressions/constants.py:pass"
    "regressions/dynamic_typing.py:pass"
    "regressions/esbmc_assume_fail.py:fail"
    "regressions/esbmc_assume.py:pass"
    "regressions/exception.py:pass"
    "regressions/float_fail.py:fail"
    "regressions/float.py:pass"
    "regressions/for_loop_fail.py:fail"
    "regressions/for_loop.py:pass"
    "regressions/function_call_fail.py:fail"
    "regressions/function_call_mult_params.py:pass"
    "regressions/function_option_fail.py:fail"
    "regressions/function_option.py:pass"
    "regressions/function_params_fail.py:fail"
    "regressions/function_return_fail.py:fail"
    "regressions/function_return_if.py:pass"
    "regressions/function_return.py:pass"
    "regressions/function_undef.py:pass"
    "regressions/github_2224.py:pass"
    "regressions/global.py:pass"
    "regressions/if_else_fail.py:fail"
    "regressions/if_else.py:pass"
    "regressions/if_global_var.py:pass"
    "regressions/import_as_fail.py:fail"
    "regressions/import_as.py:pass"
    "regressions/import_from_all.py:pass"
    "regressions/import_from_class_fail.py:fail"
    "regressions/import_from_class.py:pass"
    "regressions/import_from_function_fail.py:fail"
    "regressions/import_from_function.py:pass"
    "regressions/import_from_multiple_fail.py:fail"
    "regressions/import_from_multiple.py:pass"
    "regressions/import_math.py:pass"
    "regressions/import_os.py:pass"
    "regressions/import.py:pass"
    "regressions/inheritance_fail.py:fail"
    "regressions/inheritance.py:pass"
    "regressions/int_bit_length.py:pass"
    "regressions/int_bit_length_fail.py:fail"
    "regressions/int_from_bytes.py:pass"
    "regressions/int_from_bytes_fail.py:fail"
    "regressions/len_fail.py:fail"
    "regressions/len.py:pass"
    "regressions/len2_fail.py:fail"
    "regressions/len2.py:pass"
    "regressions/list_fail.py:fail"
    "regressions/list.py:pass"
    "regressions/list2.py:pass"
    "regressions/logical_and_success.py:pass"
    "regressions/logical_and.py:pass"
    "regressions/logical_not_fail.py:fail"
    "regressions/logical_not_success.py:pass"
    "regressions/logical_or_success.py:pass"
    "regressions/logical_or.py:pass"
    "regressions/mod_fail.py:fail"
    "regressions/nondet_fail.py:fail"
    "regressions/nondet_verifier_fail.py:fail"
    "regressions/nondet_verifier.py:pass"
    "regressions/nondet.py:pass"
    "regressions/pass.py:pass"
    "regressions/range_fail.py:fail"
    "regressions/range.py:pass"
    "regressions/recursion_fail.py:fail"
    "regressions/recursion.py:pass"
    "regressions/strings_bounds_fail.py:fail"
    "regressions/strings_concat_fail.py:fail"
    "regressions/strings_concat.py:pass"
    "regressions/strings_eq_fail.py:fail"
    "regressions/strings.py:pass"
    "regressions/ternary_operator.py:pass"
    "regressions/try_fail.py:fail"
    "regressions/var_declarations.py:pass"
    "regressions/verifier_assume_fail.py:fail"
    "regressions/verifier_assume.py:pass"
    "regressions/while_break_fail.py:fail"
    "regressions/while_break.py:pass"
    "regressions/while_continue_fail.py:fail"
    "regressions/while_continue.py:pass"
    "regressions/while_fail.py:fail"
    "regressions/while_fail_GtE.py:fail"
    "regressions/while_fail_LtE.py:fail"
    "regressions/while.py:pass"
    "regressions/while_GtE.py:pass"
    "regressions/while_LtE.py:pass"
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
    printf "| %-30s | %-9s | %-9s | %-8s |\n" "$test_name" "$expected" "$actual" "$match"
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