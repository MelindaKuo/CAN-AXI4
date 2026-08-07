"""
    sim/destuff_stim.txt      stuffed bits, one per line   -> DUT input
    sim/destuff_expected.txt  destuffed bits, one per line -> diff target
"""

import os
import random
import sys

from stuffing import destuff, stuff

SIM_DIR = os.path.join(os.path.dirname(__file__), "..", "sim")


def write_bits(path, bits):
    with open(path, "w") as f:
        f.write("".join(f"{b}\n" for b in bits))


def make_cases(seed=0):

    random.seed(seed)

    cases = [
        ("alternating", [1,0] *10), 
        ("all_ones", [1]*10), 
        ("all_zeros", [0]*10), 
        ("rule3_zeros", [0,0,0,0,0, 1,1,1,1]), 
        ("rule3_ones", [1,1,1,1,1,0,0,0,0]), 
    ]

    for i in range(20):
        n = random.randint(10,80)
        cases.append((f"random_{i}", [random.randint(0,1) for i in range(n)]))

    return cases



def main():
    os.makedirs(SIM_DIR, exist_ok=True)

    cases = make_cases()

    all_bits = []
    for name, bits in cases:
        start = len(all_bits)
        all_bits += bits
        print(f"  {name:14s} bits {start:5d} - {len(all_bits)-1:5d}  ({len(bits)} bits)")

    stim = stuff(all_bits)
    expected = all_bits


    back, err = destuff(stim)
    assert back == expected, "model round-trip failed"
    assert not err, "model reported a false stuff error"

    write_bits(os.path.join(SIM_DIR, "destuff_stim.txt"), stim)
    write_bits(os.path.join(SIM_DIR, "destuff_expected.txt"), expected)

    print(f"\nstimulus : {len(stim):5d} bits  -> sim/destuff_stim.txt")
    print(f"expected : {len(expected):5d} bits  -> sim/destuff_expected.txt")
    print(f"stuff bits inserted: {len(stim) - len(expected)}")


if __name__ == "__main__":
    sys.exit(main() or 0)
