#!/bin/bash

# Array of test cases with file paths and expected results
declare -a test_cases=(
    "diff/annotate_function.py:pass"
    "diff/annotate_method.py:pass"
    "diff/arith_ops_fail.py:fail"
    "diff/assert_arith.py:pass"
    "diff/assert_fail.py:fail"
    "diff/assert_string.py:pass"
    "diff/assert.py:pass"
    "diff/assign_fail.py:fail"
    "diff/binary_ops.py:pass"
    "diff/bitwise_fail.py:fail"
    "diff/built_in_functions.py:pass"
    "diff/bytes_assert_fail.py:fail"
    "diff/bytes_bounds_fail.py:fail"
    "diff/bytes_neg_index.py:pass"
    "diff/bytes.py:pass"
    "diff/chained_comparison_fail.py:fail"
    "diff/chained_comparison.py:pass"
    "diff/class_attributes.py:pass"
    "diff/class_methods_fail.py:fail"
    "diff/class_methods.py:pass"
    "diff/classes_fail.py:fail"
    "diff/classes.py:pass"
    "diff/compound_assign_fail.py:fail"
    "diff/compound_assign.py:pass"
    "diff/constants_fail.py:fail"
    "diff/constants.py:pass"
    "diff/dynamic_typing.py:pass"
    "diff/esbmc_assume_fail.py:fail"
    "diff/esbmc_assume.py:pass"
    "diff/exception.py:pass"
    "diff/float_fail.py:fail"
    "diff/float.py:pass"
    "diff/for_loop_fail.py:fail"
    "diff/for_loop.py:pass"
    "diff/function_call_fail.py:fail"
    "diff/function_call_mult_params.py:pass"
    "diff/function_option_fail.py:fail"
    "diff/function_option.py:pass"
    "diff/function_params_fail.py:fail"
    "diff/function_return_fail.py:fail"
    "diff/function_return_if.py:pass"
    "diff/function_return.py:pass"
    "diff/function_undef.py:pass"
    "diff/github_2224.py:pass"
    "diff/global.py:pass"
    "diff/if_else_fail.py:fail"
    "diff/if_else.py:pass"
    "diff/if_global_var.py:pass"
    "diff/import_as_fail.py:fail"
    "diff/import_as.py:pass"
    "diff/import_from_all.py:pass"
    "diff/import_from_class_fail.py:fail"
    "diff/import_from_class.py:pass"
    "diff/import_from_function_fail.py:fail"
    "diff/import_from_function.py:pass"
    "diff/import_from_multiple_fail.py:fail"
    "diff/import_from_multiple.py:pass"
    "diff/import_math.py:pass"
    "diff/import_os.py:pass"
    "diff/import.py:pass"
    "diff/inheritance_fail.py:fail"
    "diff/inheritance.py:pass"
    "diff/int_bit_length.py:pass"
    "diff/int_bit_length_fail.py:fail"
    "diff/int_from_bytes.py:pass"
    "diff/int_from_bytes_fail.py:fail"
    "diff/len_fail.py:fail"
    "diff/len.py:pass"
    "diff/len2_fail.py:fail"
    "diff/len2.py:pass"
    "diff/list_fail.py:fail"
    "diff/list.py:pass"
    "diff/list2.py:pass"
    "diff/logical_and_success.py:pass"
    "diff/logical_and.py:pass"
    "diff/logical_not_fail.py:fail"
    "diff/logical_not_success.py:pass"
    "diff/logical_or_success.py:pass"
    "diff/logical_or.py:pass"
    "diff/mod_fail.py:fail"
    "diff/nondet_fail.py:fail"
    "diff/nondet_verifier_fail.py:fail"
    "diff/nondet_verifier.py:pass"
    "diff/nondet.py:pass"
    "diff/pass.py:pass"
    "diff/range_fail.py:fail"
    "diff/range.py:pass"
    "diff/recursion_fail.py:fail"
    "diff/recursion.py:pass"
    "diff/strings_bounds_fail.py:fail"
    "diff/strings_concat_fail.py:fail"
    "diff/strings_concat.py:pass"
    "diff/strings_eq_fail.py:fail"
    "diff/strings.py:pass"
    "diff/ternary_operator.py:pass"
    "diff/try_fail.py:fail"
    "diff/var_declarations.py:pass"
    "diff/verifier_assume_fail.py:fail"
    "diff/verifier_assume.py:pass"
    "diff/while_break_fail.py:fail"
    "diff/while_break.py:pass"
    "diff/while_continue_fail.py:fail"
    "diff/while_continue.py:pass"
    "diff/while_fail.py:fail"
    "diff/while_fail_GtE.py:fail"
    "diff/while_fail_LtE.py:fail"
    "diff/while.py:pass"
    "diff/while_GtE.py:pass"
    "diff/while_LtE.py:pass"
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