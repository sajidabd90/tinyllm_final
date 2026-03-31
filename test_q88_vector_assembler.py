import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

def unpack_vector(packed_val, length):
    vec = []
    val = int(packed_val)
    for i in range(length - 1, -1, -1):
        chunk = (val >> (i * 16)) & 0xFFFF
        if chunk & 0x8000:
            chunk -= 0x10000
        vec.append(chunk)
    return vec

@cocotb.test()
async def test_q88_vector_assembler(dut):
    vector_len = int(dut.VECTOR_LEN.value)
    dut._log.info(f"Testing Vector Assembler for length {vector_len}")
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rst_n.value = 0
    dut.shift_en.value = 0
    dut.data_in.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    expected_array = [i for i in range(1, vector_len + 1)]

    dut._log.info("Shifting in 64 consecutive values...")
    for val in expected_array:
        dut.data_in.value = val
        dut.shift_en.value = 1
        
        await RisingEdge(dut.clk)
        dut.shift_en.value = 0
        await Timer(1, unit="ns") 
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    actual_packed = dut.vector_out.value
    actual_array = unpack_vector(actual_packed, vector_len)

    assert actual_array == expected_array, \
        f"FAIL: Vector ordering is wrong!\nExpected: {expected_array[:5]}... \nGot: {actual_array[:5]}..."

    dut._log.info("Successfully shifted and packed 1024 bits in perfect order!")