#!/bin/bash

# Array of test cases with file paths and expected results
declare -a test_cases=(
    "examples/list_test.py:pass"
    "examples/assert_test.py:pass"
    "examples/random_test.py:fail"
    "examples/example_1_esbmc.py:fail"
    "examples/example_3_dataclasses.py:pass"
    "examples/test_class_inheritance.py:pass"
    "examples/example_15_dictionary.py:pass"
    "examples/example_13_sleep.py:pass"
    "examples/example_15_dictionary.py:pass"
    "examples/example_19_tuples.py:pass"
    "examples/example_31_for_loop.py:pass"
    "examples/example_32_for_loop2.py:fail"
    "examples/example_35_input.py:pass"
    "examples/example_36_comparison.py:pass"
    "examples/example_4_recursive.py:pass"
    "examples/example_27_list_lambda.py:pass"
    "examples/example_18_list.py:pass"
)

# Variable to track overall success
overall_success=0

# Array to store table rows
declare -a table_rows=()

# Execute tests and collect results
for test in "${test_cases[@]}"; do
    file="${test%%:*}"
    expected="${test##*:}"

    # Convert expected result to numeric value
    [[ $expected == "pass" ]] && expected_result=0 || expected_result=1

    # Run test
    ./verify.sh "$file"
    actual_result=$?

    # Get results in text form
    actual_text=$([ $actual_result -eq 0 ] && echo 'pass' || echo 'fail')
    match_symbol=$([ $actual_result -eq $expected_result ] && echo '✓' || echo '✗')

    # Store row for later display
    table_rows+=("$(basename "$file")|$expected|$actual_text|  $match_symbol ")

    # Track overall success
    [[ $actual_result -ne $expected_result ]] && overall_success=1
done

# Print complete table at end
echo -e "\nTest Results Summary:"
echo "+--------------------------------+-----------+-----------+--------+"
echo "| Test Name                      | Expected  | Actual    | Status |"
echo "+--------------------------------+-----------+-----------+--------+"

# Print all stored results
for row in "${table_rows[@]}"; do
    IFS='|' read -r test_name expected actual match <<< "$row"
    printf "| %-30s | %-9s | %-9s | %s   |\n" "$test_name" "$expected" "$actual" "$match"
done

echo "+--------------------------------+-----------+-----------+--------+"

# Final status
if [[ $overall_success -eq 0 ]]; then
    echo -e "\nAll verifications passed."
    exit 0
else
    echo -e "\nSome verifications failed."
    exit 1
fi
