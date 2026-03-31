import cocotb
from cocotb.triggers import Timer
import random

def golden_dot_product(vec_a, vec_b):

    acc = 0
    for a, b in zip(vec_a, vec_b):

        mult = (int(a) * int(b)) >> 8

        mult_sat = max(min(mult, 32767), -32768)

        acc += mult_sat
        

    return max(min(acc, 32767), -32768)

def pack_vector(vec):

    packed = 0
    for i, val in enumerate(vec):

        uval = val & 0xFFFF
        packed |= (uval << (i * 16))
    return packed

@cocotb.test()
async def test_q88_dot_product(dut):
    """Test the parameterized dot-product tree."""
    

    vector_len = int(dut.VECTOR_LEN.value)
    dut._log.info(f"Testing dot-product with VECTOR_LEN = {vector_len}")

    dut._log.info("Running extreme saturation edge cases...")
    
    edge_cases = [

        ([32767] * vector_len, [32767] * vector_len),

        ([-32768] * vector_len, [-32768] * vector_len),

        ([32767] * vector_len, [-32768] * vector_len),

        ([32767, -32768] * (vector_len // 2), [-32768, 32767] * (vector_len // 2))
    ]

    for vec_a, vec_b in edge_cases:
        dut.vec_a.value = pack_vector(vec_a)
        dut.vec_b.value = pack_vector(vec_b)
        await Timer(1, units="ns")
        
        expected = golden_dot_product(vec_a, vec_b)
        actual = dut.dot_out.value.signed_integer
        assert actual == expected, f"FAIL on Edge Case | Expected: {expected}, Got: {actual}"

    dut._log.info("Edge cases passed. Moving to random vectors...")

    for test_idx in range(500):

        vec_a = [random.randint(-1000, 1000) for _ in range(vector_len)]
        vec_b = [random.randint(-1000, 1000) for _ in range(vector_len)]


        dut.vec_a.value = pack_vector(vec_a)
        dut.vec_b.value = pack_vector(vec_b)


        await Timer(1, units="ns")
        expected = golden_dot_product(vec_a, vec_b)
        actual = dut.dot_out.value.signed_integer

        assert actual == expected, (
            f"FAIL at Test {test_idx} | Expected: {expected}, Got: {actual}"
        )

    dut._log.info("Successfully passed 500 vector dot-product tests.")