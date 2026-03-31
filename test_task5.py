import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np
import os

def verilog_to_q88_array(verilog_value, vector_len=64):
    binary_str = verilog_value.binstr
    if 'x' in binary_str or 'z' in binary_str:
        return np.zeros(vector_len) # Failsafe
    
    chunks = [binary_str[i:i+16] for i in range(0, len(binary_str), 16)]
    floats = []
    for chunk in reversed(chunks):
        val = int(chunk, 2)
        if val > 32767:
            val -= 65536
        floats.append(val / 256.0)
    return np.array(floats)

def calculate_errors(hw_array, sw_array):
    errors = np.abs(hw_array - sw_array)
    return np.mean(errors), np.max(errors)

@cocotb.test()
async def validate_25_prompts(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    prompts = [12, 45, 102, 300, 345, 678]
    
    total_token_matches = 0
    total_tokens_checked = 0
    
    print("\n" + "="*60)
    print("TASK 5: AUTOMATED VALIDATION SUITE (FP32 vs Q8.8)")
    print("="*60)

    for i, prompt_id in enumerate(prompts):
        sw_l0 = np.load(f"golden_data/p{i}_l0.npy")
        sw_l3 = np.load(f"golden_data/p{i}_l3.npy")
        sw_tokens = np.loadtxt(f"golden_data/p{i}_tokens.txt", dtype=int)
        dut.rst_n.value = 0
        await Timer(20, units="ns")
        dut.rst_n.value = 1
        

        dut.prompt_token_id.value = prompt_id
        dut.start_gen.value = 1
        await RisingEdge(dut.clk)
        dut.start_gen.value = 0
        
        while dut.l0_done.value != 1:
            await RisingEdge(dut.clk)
        hw_l0 = verilog_to_q88_array(dut.l0_out.value)
        mae_l0, max_l0 = calculate_errors(hw_l0, sw_l0)
        
        while dut.l3_done.value != 1:
            await RisingEdge(dut.clk)
        hw_l3 = verilog_to_q88_array(dut.l3_out.value)
        mae_l3, max_l3 = calculate_errors(hw_l3, sw_l3)
        
        hw_tokens = []
        while dut.gen_complete.value == 0:
            if dut.state.value == 8: 
                hw_tokens.append(int(dut.current_token_id.value))
            await RisingEdge(dut.clk)
        
        check_len = min(len(hw_tokens), len(sw_tokens))
        matches = sum(1 for j in range(check_len) if hw_tokens[j] == sw_tokens[j])
        
        total_token_matches += matches
        total_tokens_checked += check_len
        
        print(f"Prompt {i+1}/25 [ID {prompt_id}]")
        print(f"  -> L0 MAE: {mae_l0:.4f} | L3 MAE: {mae_l3:.4f}")
        print(f"  -> Tokens Matched: {matches}/{check_len}")

    print("="*60)
    print(f"FINAL TOKEN MATCH RATE: {(total_token_matches/total_tokens_checked)*100:.2f}%")
    print("="*60)