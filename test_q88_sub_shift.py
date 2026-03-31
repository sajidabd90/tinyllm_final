import cocotb
from cocotb.triggers import Timer
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

def golden_sub_shift(vec_in, max_val):
    out_vec = []
    for x in vec_in:
        diff = x - max_val
        # Get absolute integer part
        shift_amt = abs(diff) >> 8
        
        if shift_amt >= 8:
            out_vec.append(0)
        else:
            out_vec.append(256 >> shift_amt)
    return out_vec

@cocotb.test()
async def test_q88_sub_shift(dut):
    vector_len = int(dut.VECTOR_LEN.value)
    dut._log.info(f"Testing Sub-Shift with VECTOR_LEN = {vector_len}")

    for test_idx in range(100):
        vec_in = [random.randint(-10000, 10000) for _ in range(vector_len)]
        max_val = max(vec_in) + random.randint(0, 1000) 
        vec_in[random.randint(0, vector_len-1)] = max_val
        dut.vec_in.value = pack_vector(vec_in)
        dut.max_in.value = max_val
        await Timer(1, unit="ns")
        expected = golden_sub_shift(vec_in, max_val)
        actual_packed = dut.vec_out.value
        actual = unpack_vector(actual_packed, vector_len)
        
        assert actual == expected, \
            f"FAIL at Test {test_idx} | Expected: {expected[:5]}... Got: {actual[:5]}..."

    dut._log.info("Successfully passed 100 Sub-Shift tests.")