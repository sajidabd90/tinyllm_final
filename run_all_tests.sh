#!/bin/bash
# Exit immediately if any test fails
set -e 

echo "========================================"
echo "Starting Task 2 Unit Tests..."
echo "========================================"

# 1. Test Multiplier
echo "--> Testing Q8.8 Multiplier"
make clean
make TOPLEVEL=q88_mult COCOTB_TEST_MODULES=test_q88_mult VERILOG_SOURCES="$(pwd)/q88_mult.v"

# 2. Test Dot Product
echo "--> Testing Dot Product Unit"
make clean
make TOPLEVEL=q88_dot_product COCOTB_TEST_MODULES=test_q88_dot_product VERILOG_SOURCES="$(pwd)/q88_mult.v $(pwd)/q88_dot_product.v"

# 3. Test LayerNorm Stats
echo "--> Testing LayerNorm Stats"
make clean
make TOPLEVEL=q88_layernorm_stats COCOTB_TEST_MODULES=test_q88_layernorm_stats VERILOG_SOURCES="$(pwd)/q88_layernorm_stats.v"

# 4. Test Softmax Max-Finder
echo "--> Testing Softmax Max-Finder"
make clean
make TOPLEVEL=q88_max_finder COCOTB_TEST_MODULES=test_q88_max_finder VERILOG_SOURCES="$(pwd)/q88_max_finder.v"

# 5. Test Softmax Sub-Shift
echo "--> Testing Softmax Sub-Shift"
make clean
make TOPLEVEL=q88_sub_shift COCOTB_TEST_MODULES=test_q88_sub_shift VERILOG_SOURCES="$(pwd)/q88_sub_shift.v"

# 6. Test Softmax Normalizer
echo "--> Testing Softmax Normalizer"
make clean
make TOPLEVEL=q88_softmax_norm COCOTB_TEST_MODULES=test_q88_softmax_norm VERILOG_SOURCES="$(pwd)/q88_softmax_norm.v"

echo "========================================"
echo "ALL TASK 2 TESTS PASSED SUCCESSFULLY!"
echo "========================================"