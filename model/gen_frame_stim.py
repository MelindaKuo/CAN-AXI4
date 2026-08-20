
import os
import random
import sys

from frame import (DOMINANT, RECESSIVE, FIXED_TAIL, W_CRC, W_EOF, W_IFS,
                   build_covered_bits, build_frame, data_length,
                   parse_frame)
from crc15 import bits_from_int, crc15
from stuffing import stuff

SIM_DIR = os.path.join(os.path.dirname(__file__), "..", "sim")

IFS_MIN = 3


def write_bits(path, bits):
    with open(path, "w") as f:
        f.write("".join(f"{b}\n" for b in bits))


def format_expected(p):
    exp= ""

    exp += f"{p['can_id']:03x} {p['rtr']} {p['dlc']:x} "

    data_changed = (p['data'] + [0] * 8)[:8]

    data_str = ""

    for i in data_changed: 
        data_str += f"{i:02x}"


    exp += data_str + " " + f"{p['crc_received']:04x}" 

    crc_flag = int(p['crc_error'])
    stuff_flag = int(p['stuff_error'])
    form_flag = int(p['form_error'])
    flags_str = f"{crc_flag}{stuff_flag}{form_flag}"

    exp += " " + flags_str

    return exp



def make_frame_cases(seed=0):
    """
      - dlc = 0                      valid, no data bytes
      - dlc = 8                      valid, full payload
      - dlc = 12                     length clamps to 8 (D2)
      - remote frame                 dlc set, zero data bytes (D7)
      - id = 0x000, data all 0x00    maximum stuffing
      - id = 0x7FF, data all 0xFF    maximum stuffing, other polarity
      - corrupted CRC                crc_error, frame rejected
      - dominant CRC delimiter       form_error
      - dominant bit in EOF          form_error
      - six identical bits           stuff_error

    """
    random.seed(seed)
    cases = []

    def add(name, bits):
        cases.append((name, bits, parse_frame(bits)))

    add("dlc0", build_frame(0x123, 0, []))
    add("dlc8", build_frame(0x123, 8, [0x11] *8))
    add("dlc12" , build_frame(0x123, 12, [0x11]*8))
    add("remoteFrame", build_frame(0x123, 5, [], rtr=RECESSIVE))
    add("maxStuff", build_frame(0x000, 8, [0x0]*8))
    add("maxStuffOnes", build_frame(0x7FF, 8, [0xFF] * 8))


    covered = build_covered_bits(0x123, DOMINANT, DOMINANT, DOMINANT, 2, [0xAB, 0xCD])
    bad_crc = crc15(covered) ^ 1
    bad = stuff(covered + bits_from_int(bad_crc, W_CRC))
    bad += [RECESSIVE, DOMINANT, RECESSIVE] + [RECESSIVE] * W_EOF + [RECESSIVE] * W_IFS
    add("crcError", bad)

    f = list(build_frame(0x123, 2, [0xAB, 0xCD]))
    f[len(f) - FIXED_TAIL] = DOMINANT
    add("formCrcDelim", f)


    f = list(build_frame(0x123, 2, [0xAB, 0xCD]))
    f[len(f) - (W_EOF + W_IFS)] = DOMINANT      # first EOF bit
    add("formEof", f)


    f = list(build_frame(0x000, 0, []))
    assert f[5] == RECESSIVE, "expected a stuff bit at index 5 of an all-zero frame"
    f[5] = DOMINANT
    add("stuffError", f)


    for i in range(300):
        can_id = random.randint(0, 0x7FF)
        dlc = random.randint(0, 8)
        data = [random.randint(0, 255) for _ in range(dlc)]
        add(f"random_{i}", build_frame(can_id, dlc, data))

    return cases


def main():
    os.makedirs(SIM_DIR, exist_ok=True)
    cases = make_frame_cases()

    all_bits = [RECESSIVE] * 16
    lines = []

    for name, bits, p in cases: 
        start = len(all_bits)
        all_bits += bits

        gap = random.randint(0, 20)

        all_bits += [RECESSIVE] * gap

        lines.append(format_expected(p))

        print(f"  {name:14s} bits {start:6d} - {start + len(bits) - 1:6d}")

    write_bits(os.path.join(SIM_DIR, "frame_stim.txt"), all_bits)

    with open(os.path.join(SIM_DIR, "frame_expected.txt"), "w") as f:
        for line in lines:
            print(line, file=f)

    print(f"\n{len(cases)} frames, {len(all_bits)} bits")

if __name__ == "__main__":
    sys.exit(main() or 0)
