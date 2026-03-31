import os


SCALE = 256
MAX_SUM = 64 * SCALE  # 16384

def generate_recip_hex(filename):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    
    with open(filename, 'w') as f:
        for sum_val in range(MAX_SUM + 1):
            if sum_val == 0:

                recip_int = 0 
            else:
                recip_int = int(round((SCALE * SCALE) / sum_val))

                recip_int = min(recip_int, 32767) 
            
            f.write(f"{recip_int & 0xFFFF:04X}\n")

    print(f"Generated {filename} with {MAX_SUM + 1} entries.")

generate_recip_hex("roms/recip_lut.hex")