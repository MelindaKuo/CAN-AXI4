"""
  polynomial : x^15 + x^14 + x^10 + x^8 + x^7 + x^4 + x^3 + 1  ==  0x4599
  width      : 15 bits
  init       : 0
  reflection : none (CAN is MSB-first throughout)
  final xor  : none
  coverage   : SOF, ID, RTR, IDE, r0, DLC, and data field  destuffed bits
               only, stuff bits excluded. Every bit preceding the CRC sequence.
"""

CRC15_POLY = 0x4599
CRC15_WIDTH = 15
CRC15_MASK = (1 << CRC15_WIDTH) - 1


def crc15(bits, init=0):
    crc = init

    for bit in bits:
        fits  = bit ^ ((crc >> CRC15_WIDTH-1) &1)
        crc = (crc << 1) & CRC15_MASK

        if fits: 
            crc ^= CRC15_POLY

    return crc


def bits_from_int(value, width):
    intToBits = []
    for i in range(width-1, -1, -1):
        intToBits.append((value >> i )& 1)

    return intToBits


def int_from_bits(bits):

    value = 0

    for bit in bits: 
        value = (value << 1) | bit


    return value
