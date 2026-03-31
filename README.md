# FPGA Implementation of a Tiny Large Language Model

**Author:** Abdullah Al Sajid
**Course:** DCPS Lab, University of Missouri (Spring 2026)

## Project Overview
This repository contains a complete, inference-only hardware accelerator for the pre-trained **TinyStories-1M** transformer model, implemented entirely in Verilog. 

The design executes forward-pass token generation without floating-point units or external software intervention. All PyTorch weights have been extracted and quantized to a custom **Q8.8 fixed-point format**. The architecture features custom fixed-point multipliers, pipelined adder trees, and a hardware-friendly Max-Subtract-Shift Softmax approximation.

## Prerequisites & Toolchain
This project is built and simulated using 100% open-source EDA tools. 
* **[OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)** (Provides Icarus Verilog and Yosys)
* **Python 3.11+** (Bundled with OSS CAD Suite via `tabbypy3`)
* **Cocotb** (For automated hardware/software co-simulation)

# Disclosure regarding use of AI : Various LLMS themselves were used for help with ideation, summarising theoretical concepts and code generation (how ironic that we are using LLMs to accelerate LLMs). This crutch was used in part as a learning tool, as this was my first time undertaking a project of this scale in such a timeframe. I treat this as an assisted learning experience that will accelerate my future iterations on LLM acceleration. To be clearn, all underlying concepts were learned along the way, and my previous experience with RTL and HLS helped me transition to a project of this scale, especially for switching to cocotb and yosys instead of relying on Vivado and Vitis HLS.  

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


