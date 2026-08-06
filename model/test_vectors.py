"""
proving crc15 is correct
"""

import sys

from crc15 import bits_from_int, crc15


def bits_from_bytes(data):
    out = []
    for byte in data:
        out += bits_from_int(byte, 8)
    return out


def build_covered_bits(can_id, rtr, ide, r0, dlc, data):
    """

    SOF(1, dominant) + ID(11) + RTR(1) + IDE(1) + r0(1) + DLC(4) + data.
    All fields MSB-first; data is byte 0 first, bit 7 first.

    D7: a remote frame (RTR recessive) carries a DLC but ZERO data bytes
    """
    assert rtr == 1 or len(data) == dlc, f"dlc = {dlc} but {len(data)} data bytes"

    data_bits = []

    if rtr == 0:
        for byte in data:
            data_bits += bits_from_int(byte, 8)

    return [0] + bits_from_int(can_id, 11) + [rtr] + [ide] + [r0] + bits_from_int(dlc, 4) + data_bits


# Externally-sourced vectors. Format:
#   (description, source_citation, covered_bits, expected_crc)
#
# Coverage rule: SOF + ID(11) + RTR + IDE + r0 + DLC(4) + data


VECTORS = [
    # VECTOR 1  the standard CRC catalogue "check" value
    (
        'CRC-15/CAN catalogue check value: ASCII "123456789"',
        "RevEng CRC catalogue, entry CRC-15/CAN --- width=15 poly=0x4599 "
        "init=0x0000 refin=false refout=false xorout=0x0000 check=0x059e "
        "residue=0x0000, citing the Bosch CAN 2.0 specification (Sept 1991). "
        "https://reveng.sourceforge.io/crc-catalogue/1-15.htm  ||  "
        "Independently confirmed by pwntools: crc_15_can(b'123456789') == 1438 "
        "== 0x059E. https://docs.pwntools.com/en/stable/util/crc.html",
        bits_from_bytes(b"123456789"),
        0x059E,
    ),
    # VECTOR 2  a complete CAN frame, captured off real hardware
    (
        "Real MCP2515 capture: ID=0x222 std data frame, DLC=5, "
        "data 00 11 22 33 44 -> CRC 0x66DA",
        "sigrok-test regression suite, expected output of the sigrok CAN "
        "decoder on a logic-analyser capture of an MCP2515 CAN controller demo "
        "board at 125 kbit/s. File: decoder/test/can/"
        "mcp2515dm-bm-125kbits_msg_222_5bytes.output --- decodes to "
        "id=546 (0x222), IDE=standard, RTR=data frame, r0=0, DLC=5, "
        "DB0..DB4 = 00 11 22 33 44, CRC-15 sequence = 0x66da. "
        "https://github.com/sigrokproject/sigrok-test/tree/master/decoder/test/can",
        build_covered_bits(0x222, 0, 0, 0, 5, [0x00, 0x11, 0x22, 0x33, 0x44]),
        0x66DA,
    ),
]


def main():
    if not VECTORS:
        print("FAIL: no vectors. Phase 0 is not done until this list is filled.")
        return 1

    failures = 0
    for desc, source, bits, expected in VECTORS:
        got = crc15(bits)
        ok = got == expected
        failures += not ok
        print(f"[{'PASS' if ok else 'FAIL'}] {desc}")
        print(f"       source: {source}")
        if not ok:
            print(f"       expected 0x{expected:04X}, got 0x{got:04X}")

    print(f"\n{len(VECTORS) - failures}/{len(VECTORS)} vectors passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
