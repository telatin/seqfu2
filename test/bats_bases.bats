#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
    # Load test helpers
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'

    # Set data directory relative to test file
    DATA_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/../data"
}

@test "seqfu bases shows help with --help" {
    run ./bin/seqfu bases --help
    assert [ $status -eq 0 ]
    assert_output --partial "Usage: bases [options]"
}

@test "seqfu bases handles single A sequence" {
    run ./bin/seqfu bases "$DATA_DIR/base_a.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "base_a.fa[[:space:]]+5[[:space:]]+100\.00[[:space:]]+0\.00[[:space:]]+0\.00[[:space:]]+0\.00[[:space:]]+0\.00[[:space:]]+0\.00[[:space:]]+0\.00"
}

@test "seqfu bases handles CG rich sequence" {
    run ./bin/seqfu bases "$DATA_DIR/base_cg.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "base_cg.fa[[:space:]]+25[[:space:]]+0\.00[[:space:]]+52\.00[[:space:]]+48\.00[[:space:]]+0\.00[[:space:]]+0\.00[[:space:]]+0\.00[[:space:]]+100\.00"
}

@test "seqfu bases handles lowercase sequences" {
    run ./bin/seqfu bases "$DATA_DIR/bases_lower.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "bases_lower.fa[[:space:]]+15[[:space:]]+33\.33[[:space:]]+26\.67[[:space:]]+20\.00[[:space:]]+13\.33[[:space:]]+6\.67[[:space:]]+0\.00[[:space:]]+46\.67"
}

@test "seqfu bases prints raw counts with -c" {
    run ./bin/seqfu bases -c "$DATA_DIR/base_at.fa"
    assert [ $status -eq 0 ]
    # Total length is 33, with 14 A's and 19 T's
    assert_output --regexp "base_at.fa[[:space:]]+33[[:space:]]+14[[:space:]]+0[[:space:]]+0[[:space:]]+19[[:space:]]+0[[:space:]]+0"
}

@test "seqfu bases prints header with -H" {
    run ./bin/seqfu bases -H "$DATA_DIR/base.fa"
    assert [ $status -eq 0 ]
    assert_line --index 0 --regexp "#Filename[[:space:]]+Total[[:space:]]+A[[:space:]]+C[[:space:]]+G[[:space:]]+T[[:space:]]+N[[:space:]]+Other[[:space:]]+%GC"
}

@test "seqfu bases handles non-standard bases" {
    run ./bin/seqfu bases "$DATA_DIR/base_extra.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "base_extra.fa[[:space:]]+20[[:space:]]+50\.00[[:space:]]+0\.00[[:space:]]+0\.00[[:space:]]+0\.00[[:space:]]+0\.00[[:space:]]+50\.00[[:space:]]+0\.00"
}

@test "seqfu bases with -b strips directory path" {
    # First test with full path
    run ./bin/seqfu bases "$DATA_DIR/base_a.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "$DATA_DIR/base_a\.fa[[:space:]]"

    # Then test with -b to see directory stripped
    run ./bin/seqfu bases -b "$DATA_DIR/base_a.fa"
    assert [ $status -eq 0 ]
    # Should show bare filename with path stripped
    assert_output --regexp "^base_a\.fa[[:space:]]"
    # Make sure full path is not present
    refute_output --regexp "$DATA_DIR"
}

# You might also want to verify multiple files maintain order
@test "seqfu bases with -b maintains file order" {
    run ./bin/seqfu bases -b "$DATA_DIR/base.fa" "$DATA_DIR/base_at.fa"
    assert [ $status -eq 0 ]
    assert_line --index 0 --regexp "^base\.fa[[:space:]]"
    assert_line --index 1 --regexp "^base_at\.fa[[:space:]]"
}

 

@test "seqfu bases handles multiple input files" {
    run ./bin/seqfu bases "$DATA_DIR/base_a.fa" "$DATA_DIR/base_t.fa"
    assert [ $status -eq 0 ]
    
    # Check that both files' data appears somewhere in the output
    assert_output --partial "100.00	0.00	0.00	0.00"  # base_a.fa has 100% A
    assert_output --partial "0.00	0.00	0.00	100.00"  # base_t.fa has 100% T
    
    # Check that both filenames appear in the output
    assert_output --partial "base_a.fa"
    assert_output --partial "base_t.fa"
}

@test "seqfu bases fails gracefully with non-existent file" {
    run ./bin/seqfu bases nonexistent.fa
    assert [ $status -eq 0 ]
}

@test "seqfu bases output is tab-delimited with correct columns" {
    run ./bin/seqfu bases "$DATA_DIR/base.fa"
    assert [ $status -eq 0 ]
    
    # Count number of columns
    line="$( echo "$output" | head -n1 )"
    num_cols="$( echo "$line" | awk -F'\t' '{print NF}' )"
    assert_equal "$num_cols" "10" # 10 columns including filename and uppercase column
}

@test "seqfu bases correctly reports uppercase ratios" {
    run ./bin/seqfu bases "$DATA_DIR/upper-none.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "none.*0\.00$" # Last column (uppercase) should be 0.00
    
    run ./bin/seqfu bases "$DATA_DIR/upper-only.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "only.*100\.00$" # Should be 100% uppercase
    
    run ./bin/seqfu bases "$DATA_DIR/upper-lower.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "lower.*50\.00$" # Should be 50% uppercase
}

@test "seqfu bases -c correctly counts extra bases" {
    run ./bin/seqfu bases -c "$DATA_DIR/base_extra.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "base_extra\.fa.*20.*10.*0.*0.*0.*0.*10" # 10 extra bases of 20 total
}

@test "seqfu bases correctly reports raw counts vs percentages" {
    # First check raw counts
    run ./bin/seqfu bases -c "$DATA_DIR/bases_lower.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "bases_lower\.fa.*15.*5.*4.*3.*2.*1" # Raw counts
    
    # Then check percentages
    run ./bin/seqfu bases "$DATA_DIR/bases_lower.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "bases_lower\.fa.*15.*33\.33.*26\.67.*20\.00.*13\.33.*6\.67" # Percentages
}

@test "seqfu bases handles combinations of uppercase and lowercase files" {
    run ./bin/seqfu bases "$DATA_DIR/base.fa" "$DATA_DIR/bases_lower.fa"
    assert [ $status -eq 0 ]
    
    # Check that first file (base.fa) has correct stats:
    # - 100.00 in last column (uppercase percentage)
    # - 50.00 for A and C content
    assert_output --regexp "base\.fa.*50\.00.*50\.00.*0\.00.*0\.00.*0\.00.*0\.00.*50\.00.*100\.00"
    
    # Check that second file (bases_lower.fa) has:
    # - 0.00 in last column (uppercase percentage)
    # - Correct base percentages
    assert_output --regexp "bases_lower\.fa.*33\.33.*26\.67.*20\.00.*13\.33.*6\.67.*0\.00.*46\.67.*0\.00"
}

@test "seqfu bases preserves floating point precision" {
    run ./bin/seqfu bases "$DATA_DIR/bases_lower.fa"
    assert [ $status -eq 0 ]
    assert_output --regexp "33\.33" # Checks that two decimal places are preserved
}

@test "seqfu bases properly accounts for all bases" {
    run ./bin/seqfu bases "$DATA_DIR/base_extra.fa"
    assert [ $status -eq 0 ]
    # Sum of all percentages (A,C,G,T,N,Other) should add up to 100%
    assert_output --regexp "base_extra\.fa.*20.*50\.00.*0\.00.*0\.00.*0\.00.*0\.00.*50\.00"
}

@test "seqfu bases QUIET mode suppresses progress messages" {
    export SEQFU_QUIET=1 
    run ./bin/seqfu bases "$DATA_DIR/base.fa"
    assert [ $status -eq 0 ]
    
    # Count number of lines in output
    num_lines="$(echo "$output" | wc -l | tr -d ' ')"
    assert_equal "$num_lines" "1" "Expected single line output in quiet mode"
    
    # Verify the line is a data line and not a status message
    assert_output --regexp "^.*base\.fa.*[0-9]+\.[0-9]+.*$"
}

@test "seqfu bases counts match file lengths" {
    for file in "$DATA_DIR"/base*.fa; do
        run ./bin/seqfu bases -c "$file"
        assert [ $status -eq 0 ]
        
        # Get the total count from seqfu output and trim whitespace
        total=$(echo "$output" | cut -f 2 | tr -d ' \t')
        
        # Get actual sequence length by removing headers and whitespace
        actual_length=$(grep -v '^>' "$file" | tr -d '\n\t ' | wc -c | tr -d ' \t')
        
        # Trim both values and compare
        total="${total#"${total%%[![:space:]]*}"}"
        total="${total%"${total##*[![:space:]]}"}"
        actual_length="${actual_length#"${actual_length%%[![:space:]]*}"}"
        actual_length="${actual_length%"${actual_length##*[![:space:]]}"}"
        
        assert_equal "$total" "$actual_length" "File $(basename "$file") length mismatch"
    done
}