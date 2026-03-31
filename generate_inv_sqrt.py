import math
import os

SCALE = 256.0
MAX_VAL = 32767

EPSILON = 1 / SCALE 

def generate_lut_hex(filename):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    
    with open(filename, 'w') as f:

        for var_int in range(MAX_VAL + 1):

            var_float = var_int / SCALE
            

            inv_sqrt_float = 1.0 / math.sqrt(var_float + EPSILON)
            

            inv_sqrt_int = int(round(inv_sqrt_float * SCALE))
            inv_sqrt_int = max(0, min(inv_sqrt_int, MAX_VAL))
            

            f.write(f"{inv_sqrt_int & 0xFFFF:04X}\n")

    print(f"Generated {filename} with {MAX_VAL + 1} entries.")

generate_lut_hex("roms/inv_sqrt_lut.hex")