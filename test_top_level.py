import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_28_token_generation(dut):

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())


    dut.rst_n.value = 0
    dut.start_gen.value = 0
    dut.prompt_token_id.value = 1  # Start token
    
    await Timer(100, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut._log.info("--- STARTING TOKEN AUTOREGRESSIVE GENERATION ---")

    dut.start_gen.value = 1
    await RisingEdge(dut.clk)
    dut.start_gen.value = 0

    timeout_limit = 2_000_000 
    tokens_found = [1]
    last_count = 0  

    for cycle in range(timeout_limit):
        await RisingEdge(dut.clk)
        
        current_count = int(dut.gen_token_count.value)
        
        if current_count > last_count:
            try:
                new_token = int(dut.current_token_id.value)
                tokens_found.append(new_token)
                dut._log.info(f"*** TOKEN {len(tokens_found)} GENERATED: ID {new_token} ***")
            except ValueError:
                dut._log.info("Token generated but value was 'x'!")
            
            last_count = current_count

        if dut.gen_complete.value == 1:
            break
            
    dut._log.info(f"Generated Sequence: {tokens_found}")
    
    assert len(tokens_found) >= 27, f"Incomplete sequence! Found only {len(tokens_found)} tokens."
    dut._log.info("SUCCESS: 28-Token Generation Task Complete!")