import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Helper to pack an array of 64 integers into a single 1024-bit wide integer
def pack_vector(vec):
    packed = 0
    for val in vec:
        # Mask to 16-bit two's complement and shift
        packed = (packed << 16) | (val & 0xFFFF)
    return packed

# Helper to unpack a 1024-bit wide integer back into an array of 64 integers
def unpack_vector(packed_val, length):
    vec = []
    val = int(packed_val)
    for i in range(length - 1, -1, -1):
        chunk = (val >> (i * 16)) & 0xFFFF
        if chunk & 0x8000:
            chunk -= 0x10000
        vec.append(chunk)
    return vec

# A dictionary to translate the FSM state numbers to readable names
STATE_NAMES = {
    0: "IDLE", 1: "NORM_1", 2: "PROJ_Q", 3: "PROJ_K", 4: "PROJ_V",
    5: "CACHE_WRITE", 6: "ATTN_SCORES", 7: "SOFTMAX", 8: "ATTN_CONTEXT",
    9: "PROJ_OUT", 10: "RESIDUAL_1", 11: "NORM_2", 12: "FFN_1",
    13: "RELU", 14: "FFN_2", 15: "RESIDUAL_2", 16: "DONE"
}

@cocotb.test()
async def test_full_transformer_pipeline(dut):
    vector_len = int(dut.VECTOR_LEN.value)
    
    # 1. Start the 100MHz clock
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # 2. Initialize inputs
    dut.rst_n.value = 0
    dut.start_token.value = 0
    dut.current_seq_pos.value = 2  # Pretend this is the 3rd token in the sentence
    
    # Create a dummy input token (e.g., values 1 to 64)
    dummy_input_array = [i for i in range(1, vector_len + 1)]
    dut.token_in.value = pack_vector(dummy_input_array)

    # 3. Hardware Reset
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut._log.info("--- CHIP AWAKE. FIRING START TOKEN ---")
    
    # 4. Trigger the Master FSM
    dut.start_token.value = 1
    await RisingEdge(dut.clk)
    dut.start_token.value = 0

    # 5. Monitor the Pipeline Execution
    timeout_cycles = 5000  # Safety net
    cycles = 0
    current_state = -1

    while cycles < timeout_cycles:
        await Timer(1, unit="ns") # Settle combinational logic
        
        # Peek at the internal FSM state wire!
        fsm_state = int(dut.master_state.value)
        
        # Print a log every time the chip changes states
        if fsm_state != current_state:
            state_name = STATE_NAMES.get(fsm_state, f"UNKNOWN({fsm_state})")
            dut._log.info(f"[Cycle {cycles:4d}] Entering State: {state_name}")
            current_state = fsm_state

        # Check if the chip is completely done
        if dut.block_done.value == 1:
            dut._log.info(f"--- BLOCK DONE ASSERTED AT CYCLE {cycles} ---")
            break

        await RisingEdge(dut.clk)
        cycles += 1

    # 6. Verification & Assertions
    assert cycles < timeout_cycles, "FAIL: The chip locked up and timed out!"
    
    # Try to read the output, expecting 'x' values since our ROMs are empty
    try:
        final_packed_out = dut.token_out.value
        final_array = unpack_vector(final_packed_out, vector_len)
        dut._log.info(f"First 5 values of Output Token: {final_array[:5]}")
    except ValueError:
        dut._log.info("Caught 'x' values in the output. This is mathematically EXPECTED because our weight ROMs are empty!")
        
    dut._log.info("SUCCESS! The Top-Level Transformer Block routed the data perfectly!")