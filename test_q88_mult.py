import cocotb
from cocotb.triggers import Timer
import random

def golden_model(a, b):
    res = (a * b) >> 8 
    return max(min(res, 32767), -32768)

@cocotb.test()
async def test_q88_mult(dut):

    edges = [32767, -32768, 0, 256, -256, 1, -1]
    test_vectors = [(a, b) for a in edges for b in edges]
    for _ in range(1000):
        test_vectors.append((random.randint(-32768, 32767), random.randint(-32768, 32767)))
    for a, b in test_vectors:
        dut.a.value = a
        dut.b.value = b
        await Timer(1, units="ns")
        expected = golden_model(a, b)
        actual = dut.result.value.signed_integer
        assert actual == expected, f"FAIL: {a} * {b} | Expected: {expected}, Got: {actual}"

    dut._log.info(f"Successfully passed {len(test_vectors)} tests, including saturation boundaries.")