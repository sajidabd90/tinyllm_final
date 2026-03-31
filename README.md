# FPGA Implementation of a Tiny Large Language Model

## Project Overview
This project builds an inference-only accelerator for the TinyStories-1M transformer model.
Design is completed in Verilog HDL. Quantization scheme of Q8.8 was followed. Testbenches
were implemented with cocotb and yosys was used for synthesis. To reproduce the results,
the repository needs to me cloned and made with make clean make. All weights and
dummy files are included in the tinystories q88 roms folder. A script has been provided to
run unit tests for the core arithmetic modules (Task 2, script run all scripts.sh)

## Prerequisites & Toolchain
This project is built and simulated using 100% open-source EDA tools. 
* **[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)** (Provides Icarus Verilog and Yosys)
* **Python 3.11+** (Bundled with OSS CAD Suite via `tabbypy3`)
* **Cocotb** (For automated hardware/software co-simulation)

# Disclosure regarding use of AI: 
Various LLMS themselves were used for help with ideation, summarising theoretical concepts and code generation (how ironic that we are using LLMs to accelerate LLMs). This crutch was used in part as a learning tool, as this was my first time undertaking a project of this scale in such a timeframe. I treat this as an assisted learning experience that will accelerate my future iterations on LLM acceleration. To be clearn, all underlying concepts were learned along the way, and my previous experience with RTL and HLS helped me transition to a project of this scale, especially for switching to cocotb and yosys instead of relying on Vivado and Vitis HLS.  

### Python Dependencies
If using OSS CAD Suite, install using its isolated Python interpreter:
tabbypy3 -m pip install numpy torch transformers cocotb

#Repository Structure
* *.v : Core Verilog RTL files (Datapath, FSMs, Arithmetic modules).

* *.hex : Quantized Q8.8 weight ROM files initialized via $readmemh.

* test_top_level.py : Cocotb testbench for Task 4 (Autoregressive Generation).

* test_task5.py : Cocotb validation suite for Task 5 (FP32 vs Q8.8 Error Analysis).

* makefile : Standard Cocotb Makefile for Icarus Verilog simulation.

* golden_data/ : Extracted PyTorch FP32 baseline tensors for validation testing.

## How to Build and Test

### 1. Run the Automated Validation Suite (Task 5)
This testbench runs a subset of 6 prompts through both the Verilog hardware and a PyTorch software reference, calculating the exact Mean Absolute Error (MAE) of the Q8.8 quantization and the final Token Match Rate.
```bash 
make clean && COCOTB_TEST_MODULES=test_task5 COCOTB_TOPLEVEL=top_level_llm make 
```

### 2. Run the Autoregressive Generation Loop (Task 4)
This testbench boots the simulated chip and initiates the hardware greedy-decoding loop, generating a sequence of tokens from a single prompt and outputting a cycle-by-cycle "Hardware X-Ray" of the internal datapath.
```bash
make clean && COCOTB_TEST_MODULES=test_top_level COCOTB_TOPLEVEL=top_level_llm make
```
### 3. Synthesize the Design (Task 6)
To generate the logic cell footprint and analyze the resource utilization of a single Transformer Block (parameterized to VECTOR_LEN=16), use Yosys:
```bash
yosys -p 'read_verilog *.v; synth -top transformer_block; stat
```


