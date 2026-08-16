"""
  SOF ID(11) RTR IDE r0 DLC(4) DATA(0-64) CRC(15) | CRCdel ACK ACKdel EOF(7) IFS(3)
  |<-------------- stuffed region -------------->| |<------- fixed form ------->|
  The bus idles recessive 1.
"""

from crc15 import bits_from_int, crc15, int_from_bits
from stuffing import destuff, stuff

# Field widths, in bits
W_ID = 11
W_DLC = 4
W_CRC = 15
W_EOF = 7
W_IFS = 3

DOMINANT = 0
RECESSIVE = 1


def data_length(dlc, rtr):
    if rtr == 1: 
        return 0
    return min(8, dlc)

def build_covered_bits(can_id, rtr, ide, r0, dlc, data):
    expected = data_length(dlc, rtr)
    assert len(data) == expected, (
        f"dlc={dlc} rtr={rtr} expects {expected} data bytes, got {len(data)}"
    )

    data_bits = []
    for byte in data:
        data_bits += bits_from_int(byte, 8)

    return ([DOMINANT]
            + bits_from_int(can_id, W_ID)
            + [rtr] + [ide] + [r0]
            + bits_from_int(dlc, W_DLC)
            + data_bits)


def build_frame(can_id, dlc, data, rtr=DOMINANT, ide=DOMINANT, r0=DOMINANT, ack=DOMINANT):
    covered = build_covered_bits(can_id, rtr, ide, r0, dlc, data)

    crc = crc15(covered)

    covered += bits_from_int(crc, 15)

    stuffed = stuff(covered)

    unS = stuffed + [RECESSIVE] + [ack] + [RECESSIVE] + [RECESSIVE] * W_EOF + [RECESSIVE] * W_IFS

    return unS

    

def parse_frame(bits):
    pos = 0
    prev = None
    run_len = 0 
    stuffing = True
    stuff_error = False

    def next_bit(): 
        nonlocal pos, prev, run_len, stuffing, stuff_error

        while True:
            b = bits[pos]
            pos +=1

            if not stuffing: 
                return b

            if run_len == 5: 
                if b == prev: 
                    stuff_error = True
                prev, run_len = b,1
                continue

            if b == prev: 
                run_len +=1
            else: 
                prev, run_len = b, 1
            return b

    sof = next_bit()
    id_bits = [next_bit() for i in range (W_ID)]
    rtr = next_bit()
    ide = next_bit()
    r0 = next_bit()
    dlc_bits = [next_bit() for i in range (W_DLC)]

    dlc = int_from_bits(dlc_bits)
    can_id = int_from_bits(id_bits)

    data = []
    data_bits = []
    nbytes = data_length(dlc, rtr)

    for i in range(nbytes): 
      bb = [next_bit() for i in range (8)]
      data_bits += bb
      data.append(int_from_bits(bb))
    
    

    crc = [next_bit() for i in range (W_CRC)]


    crc_del = next_bit()
    stuffing = False
    ack = next_bit()
    ack_del = next_bit()
    eof = [next_bit() for i in range (W_EOF)]


    crc_covered  = [sof]+ id_bits + [rtr, ide, r0] + dlc_bits + data_bits
    crc_comp = crc15(crc_covered)


    crc_received = int_from_bits(crc)

    crc_error = crc_comp != crc_received

    form_error = (sof!= DOMINANT or crc_del != RECESSIVE or ack_del != RECESSIVE or any(b!=RECESSIVE for b in eof))
    valid = not(crc_error or form_error or stuff_error)

    return {
        'can_id' : can_id, 
        'rtr' : rtr, 
        'ide' : ide, 
        'r0' : r0, 
        'dlc': dlc, 
        'data': data, 
        'crc_received': crc_received, 
        'crc_computed': crc_comp, 
        'crc_error': crc_error, 
        'stuff_error': stuff_error, 
        'form_error': form_error, 
        'valid': valid, 
    }




FIXED_TAIL = 1 + 1 + 1 + W_EOF + W_IFS      # CRCdel ACK ACKdel EOF IFS = 13


def _self_test():
    import random

    random.seed(0)

    def round_trip(can_id, dlc, data, rtr=DOMINANT, label=""):
        """Build a frame, parse it back, require every field to survive."""
        frame = build_frame(can_id, dlc, data, rtr=rtr)
        p = parse_frame(frame)
        assert p["can_id"] == can_id, f"{label}: id {p['can_id']:#x} != {can_id:#x}"
        assert p["rtr"] == rtr, f"{label}: rtr {p['rtr']} != {rtr}"
        assert p["dlc"] == dlc, f"{label}: dlc {p['dlc']} != {dlc} (RAW value)"
        assert p["data"] == data, f"{label}: data {p['data']} != {data}"
        assert not p["crc_error"], f"{label}: unexpected crc_error"
        assert not p["stuff_error"], f"{label}: unexpected stuff_error"
        assert not p["form_error"], f"{label}: unexpected form_error"
        assert p["valid"], f"{label}: frame should be valid"
        return frame, p

    for _ in range(2000):
        can_id = random.randint(0, 0x7FF)
        dlc = random.randint(0, 8)
        data = [random.randint(0, 255) for _ in range(dlc)]
        round_trip(can_id, dlc, data, label="random")

    f0, _ = round_trip(0x123, 0, [], label="dlc=0")
    f8, _ = round_trip(0x123, 8, [0x11] * 8, label="dlc=8")
    assert len(f0) >= 19 + W_CRC + FIXED_TAIL, "dlc=0 frame is too short"
    assert len(f8) >= 83 + W_CRC + FIXED_TAIL, "dlc=8 frame is too short"


    round_trip(0x000, 8, [0x00] * 8, label="all zeros")
    round_trip(0x7FF, 8, [0xFF] * 8, label="all ones")


    remote = build_frame(0x123, 5, [], rtr=RECESSIVE)
    p = parse_frame(remote)
    assert p["rtr"] == RECESSIVE, "remote: rtr should be recessive"
    assert p["dlc"] == 5, "remote: dlc should still be reported"
    assert p["data"] == [], "remote frames carry no data bytes"
    assert p["valid"], "remote: frame should be valid"
    assert len(remote) < len(build_frame(0x123, 5, [0] * 5)), \
        "remote frame should be shorter than the equivalent data frame"


    over = build_frame(0x123, 12, [0x5A] * 8)
    p = parse_frame(over)
    assert p["dlc"] == 12, f"D2: dlc should be the RAW 12, got {p['dlc']}"
    assert len(p["data"]) == 8, f"D2: length should clamp to 8, got {len(p['data'])}"

    good = build_frame(0x123, 2, [0xAB, 0xCD])

    covered = build_covered_bits(0x123, DOMINANT, DOMINANT, DOMINANT, 2, [0xAB, 0xCD])
    bad_crc = crc15(covered) ^ 1
    bad = stuff(covered + bits_from_int(bad_crc, W_CRC))
    bad += [RECESSIVE, DOMINANT, RECESSIVE] + [RECESSIVE] * W_EOF + [RECESSIVE] * W_IFS
    p = parse_frame(bad)
    assert p["crc_error"], "corrupted CRC should set crc_error"
    assert not p["stuff_error"], "corrupted CRC should not look like a stuff error"
    assert not p["valid"], "corrupted CRC frame must not be valid"

    f = list(good)
    f[len(f) - FIXED_TAIL] = DOMINANT
    p = parse_frame(f)
    assert p["form_error"], "dominant CRC delimiter should set form_error"
    assert not p["valid"]

    f = list(good)
    f[len(f) - (W_EOF + W_IFS)] = DOMINANT          # first EOF bit
    p = parse_frame(f)
    assert p["form_error"], "dominant EOF bit should set form_error"
    assert not p["valid"]


    z = build_frame(0x000, 0, [])
    assert z[5] == RECESSIVE, "expected a stuff bit at index 5 of an all-zero frame"
    f = list(z)
    f[5] = DOMINANT
    p = parse_frame(f)
    assert p["stuff_error"], "flipped stuff bit should set stuff_error"
    assert not p["valid"]


    p = parse_frame(build_frame(0x123, 2, [0xAB, 0xCD], ack=RECESSIVE))
    assert p["valid"], "a recessive ACK slot must not invalidate a frame"


    for dlc in range(9):
        p = parse_frame(build_frame(0x7FF, dlc, [0xFF] * dlc))
        assert not p["stuff_error"], f"EOF tripped the destuffer at dlc={dlc}"


    p = parse_frame(build_frame(0x222, 5, [0x00, 0x11, 0x22, 0x33, 0x44]))
    assert p["crc_computed"] == 0x66DA, \
        f"external anchor: computed {p['crc_computed']:#06x}, expected 0x66DA"
    assert p["crc_received"] == 0x66DA
    assert p["can_id"] == 0x222 and p["dlc"] == 5
    assert p["data"] == [0x00, 0x11, 0x22, 0x33, 0x44]
    assert p["valid"]


if __name__ == "__main__":
    _self_test()
    print("frame self-test PASSED")
