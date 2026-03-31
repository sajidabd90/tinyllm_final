import cocotb
from cocotb.triggers import Timer
import random

def pack_vector(vec):

    packed = 0
    for i, val in enumerate(vec):
        packed |= ((val & 0xFFFF) << (i * 16))
    return packed

@cocotb.test()
async def test_q88_max_finder(dut):
    vector_len = int(dut.VECTOR_LEN.value)
    dut._log.info(f"Testing Max-Finder with VECTOR_LEN = {vector_len}")


    edge_cases = [
        [32767] * vector_len,
        [-32768] * vector_len,
        [0] * vector_len,

        [32767 if i % 2 == 0 else -32768 for i in range(vector_len)],

        [-32768] * (vector_len - 1) + [1] 
    ]
    

    for _ in range(100):
        edge_cases.append([random.randint(-32768, 32767) for _ in range(vector_len)])


    for vec in edge_cases:
        random.shuffle(vec)

    for test_idx, vec_in in enumerate(edge_cases):
        dut.vec_in.value = pack_vector(vec_in)
        await Timer(1, unit="ns")
        
        expected_max = max(vec_in)

        actual_max = dut.max_out.value.to_signed()

        assert actual_max == expected_max, \
            f"FAIL at Test {test_idx} | Expected Max: {expected_max}, Got: {actual_max}"

    dut._log.info(f"Successfully passed {len(edge_cases)} Max-Finder tests.")