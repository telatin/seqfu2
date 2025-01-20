#!/usr/bin/env bats

#bats_require_minimum_version 1.5.0

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    # Print debug info to file descriptor 3 to see it in test output
    FILT="./data/filt.fa.gz"
    PATH="../bin:$PATH"
    export FILT
}

@test "Run seqfu" {
    run seqfu
    assert [ $status -eq 0 ]
}

@test "Run accessory tools" {

    run fu-cov -h
    assert [ $status -eq 0 ]

    run fu-16Sregion -h
    assert [ $status -eq 0 ]
}
@test "Run accessory scripts (fu-readtope, fu-split)" {
    run fu-readtope -h
    assert [ $status -eq 0 ]
    run fu-split -h
    assert [ $status -eq 0 ]
}



@test "Get version" {
    # Run seqfu version and capture output
    run ./bin/seqfu version
    
    # Assert command succeeded
    assert [ $status -eq 0 ]
    
    # Assert output matches semantic version pattern
    assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "can run stats with FILT" {
    # Print the actual command we're trying to run
    run ./bin/seqfu stats "$FILT"
    [ "$status" -eq 0 ]
}
