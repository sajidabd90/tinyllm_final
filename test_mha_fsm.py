import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_mha_fsm(dut):

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())


    dut.rst_n.value = 0
    dut.mha_start.value = 0

    dut.current_seq_pos.value = 2 
    dut.softmax_done.value = 0


    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut._log.info("Firing mha_start pulse...")
    

    dut.mha_start.value = 1
    await RisingEdge(dut.clk)
    dut.mha_start.value = 0


    score_latches = 0
    context_accums = 0
    softmax_triggers = 0
    heads_processed = set()

    timeout_cycles = 500
    cycles = 0

    while cycles < timeout_cycles:

        await Timer(1, unit="ns") 


        if dut.latch_score.value == 1:
            score_latches += 1
        if dut.accumulate_context.value == 1:
            context_accums += 1
        if dut.clear_context_acc.value == 1:
            heads_processed.add(int(dut.head_select.value))


        if dut.softmax_start.value == 1:
            softmax_triggers += 1
            dut._log.info(f"Softmax triggered for Head {int(dut.head_select.value)}. Mocking delay...")
            

            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            

            dut.softmax_done.value = 1
            await RisingEdge(dut.clk)
            

            dut.softmax_done.value = 0
            cycles += 3
            continue 


        if dut.mha_done.value == 1:
            dut._log.info("MHA FSM asserted mha_done!")
            break


        await RisingEdge(dut.clk)
        cycles += 1


    assert cycles < timeout_cycles, "FAIL: Simulation timed out! FSM is stuck in a loop."

    assert score_latches == 12, f"FAIL: Expected 12 score latches, got {score_latches}"
    assert context_accums == 12, f"FAIL: Expected 12 context accums, got {context_accums}"
    assert softmax_triggers == 4, f"FAIL: Expected 4 softmax triggers, got {softmax_triggers}"
    assert len(heads_processed) == 4, f"FAIL: Expected 4 distinct heads to be processed, got {len(heads_processed)}"

    dut._log.info("Successfully verified MHA Sub-FSM loop architecture!")