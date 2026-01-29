#!/bin/bash

# Test the trim functionality

# Initial cleanup
rm -f trim_test.fq trim_output.fq

# Create a test FASTQ file with varying quality
cat > trim_test.fq << 'EOF'
@seq1
ACGTACGTACGTACGTACGTACGTACGTACGT
+
IIIIIIIIIIIIIIIIIII6000000000000
@seq2
ACGTACGTACGTACGTACGTACGTACGTACGT
+
IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
@seq3
ACGTACGTACGTACGTACGTACGTACGTACGT
+
IIIIIIIII600000IIIIIIIIIIIIIIIII
EOF

# Run the trim command
echo "Testing trim with default parameters..."
/Users/telatina/git/seqfu2/bin/seqfu trim -v trim_test.fq -o trim_output.fq

# Check the output
echo "Output:"
cat trim_output.fq

# Cleanup
rm -f trim_test.fq trim_output.fq

echo "Test completed."