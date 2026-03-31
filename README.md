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

### Python Dependencies
Ensure your simulation environment has the required Python packages:
```bash
If using OSS CAD Suite, install using its isolated Python interpreter:
tabbypy3 -m pip install numpy torch transformers cocotb
# Disclosure regarding use of AI.

