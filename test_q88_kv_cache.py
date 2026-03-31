import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

def pack_vector(vec):
    packed = 0
    for i, val in enumerate(vec):
        packed |= ((val & 0xFFFF) << (i * 16))
    return packed

def unpack_vector(packed_val, length):
    vec = []
    val = int(packed_val)
    for i in range(length):
        chunk = (val >> (i * 16)) & 0xFFFF
        if chunk & 0x8000:
            chunk -= 0x10000
        vec.append(chunk)
    return vec

@cocotb.test()
async def test_q88_kv_cache(dut):
    vector_len = int(dut.VECTOR_LEN.value)
    max_seq_len = int(dut.MAX_SEQ_LEN.value)
    dut._log.info(f"Testing KV-Cache | VEC_LEN: {vector_len}, MAX_SEQ: {max_seq_len}")


    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())


    dut.we.value = 0
    dut.write_addr.value = 0
    dut.read_addr.value = 0
    dut.data_in.value = 0

    for _ in range(2):
        await RisingEdge(dut.clk)


    dut._log.info("Writing vectors to memory...")
    memory_mirror = {}
    
    dut.we.value = 1
    for addr in range(10):

        vec = [random.randint(-1000, 1000) for _ in range(vector_len)]
        memory_mirror[addr] = vec
        

        dut.write_addr.value = addr
        dut.data_in.value = pack_vector(vec)

        await RisingEdge(dut.clk)
        
    dut.we.value = 0 

# 3. Read back and verify
    dut._log.info("Reading back and verifying...")
    for addr in range(10):

        dut.read_addr.value = addr
        

        await RisingEdge(dut.clk)

        await Timer(1, unit="ns")
        

        expected = memory_mirror[addr]
        actual = unpack_vector(dut.data_out.value, vector_len)
        
        assert actual == expected, f"FAIL at Addr {addr} | Memory corruption detected!"

    dut._log.info("Successfully wrote and verified BRAM persistence.")