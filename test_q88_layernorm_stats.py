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

def golden_layernorm_stats(vec_in):

    sum_val = sum(vec_in)
    mean_val = sum_val >> 6
    

    centered = []
    for x in vec_in:
        diff = x - mean_val
        centered.append(max(min(diff, 32767), -32768))
 
    var_sum = 0
    for c in centered:
        sq = (c * c) >> 8
        var_sum += sq
    
    var_val = var_sum >> 6
    var_val = max(min(var_val, 32767), 0) 
    
    return centered, var_val

@cocotb.test()
async def test_q88_layernorm_stats(dut):
    vector_len = int(dut.VECTOR_LEN.value)
    dut._log.info(f"Testing LayerNorm Stats with VECTOR_LEN = {vector_len}")


    edge_cases = [
        [32767] * vector_len,
        [-32768] * vector_len,
        [32767, -32768] * (vector_len // 2),
        [0] * vector_len,
        [256, -256] * (vector_len // 2) 
    ]
    

    for _ in range(100):
        edge_cases.append([random.randint(-5000, 5000) for _ in range(vector_len)])

    for test_idx, vec_in in enumerate(edge_cases):
        dut.vec_in.value = pack_vector(vec_in)
        await Timer(1, units="ns")
        

        expected_centered, expected_var = golden_layernorm_stats(vec_in)

        actual_centered_packed = dut.vec_centered_out.value
        actual_centered = unpack_vector(actual_centered_packed, vector_len)
        actual_var = dut.variance_out.value.to_signed()
        

        assert actual_centered == expected_centered, \
            f"FAIL at Test {test_idx} | Centered mismatch.\nExpected: {expected_centered[:4]}...\nGot: {actual_centered[:4]}..."
            
        assert actual_var == expected_var, \
            f"FAIL at Test {test_idx} | Variance mismatch. Expected: {expected_var}, Got: {actual_var}"

    dut._log.info(f"Successfully passed {len(edge_cases)} LayerNorm stat tests.")