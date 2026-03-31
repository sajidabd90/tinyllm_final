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

def get_recip(sum_val):
    if sum_val == 0: return 0
    val = int(round(65536 / sum_val))
    return min(val, 32767)

def golden_norm(vec_in):
    sum_val = sum(vec_in)
    recip = get_recip(sum_val)
    out_vec = []
    for x in vec_in:
        mult = (x * recip) >> 8
        out_vec.append(min(mult, 32767))
    return out_vec

@cocotb.test()
async def test_q88_softmax_norm(dut):
    vector_len = int(dut.VECTOR_LEN.value)
    dut._log.info(f"Testing Softmax Norm with VECTOR_LEN = {vector_len}")

    test_cases = [
        [256] + [0] * (vector_len - 1),  # One clear winner (100% prob)
        [128] * vector_len,              # Uniform distribution
        [0] * vector_len,                # Complete underflow
    ]
    
    for _ in range(100):
        test_cases.append([random.randint(0, 256) for _ in range(vector_len)])

    for test_idx, vec_in in enumerate(test_cases):
        dut.vec_in.value = pack_vector(vec_in)
        await Timer(1, unit="ns")
        
        expected = golden_norm(vec_in)
        actual = unpack_vector(dut.vec_out.value, vector_len)
        
        assert actual == expected, \
            f"FAIL at Test {test_idx} | Expected: {expected[:4]}... Got: {actual[:4]}..."

    dut._log.info("Successfully passed all Softmax Normalizer tests.")