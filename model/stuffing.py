"""
CAN bit stuffing / destuffing [INCLUSIVE]
"""


STUFF_RUN = 5       # insert after this many consecutive identical bits
STUFF_ERROR_RUN = 6  # this many identical bits inside the region is an error


def stuff(bits):

    newBits = []
    runLen = 0
    prev = None

    for b in bits: 
        newBits.append(b)

        if b == prev:
            runLen+=1
        else:
            prev = b
            runLen = 1

        if runLen == STUFF_RUN:
            runLen = 1
            newBits.append(b^1)
            prev = b^1

    return newBits


def destuff(bits):

    dBits = []
    runLen = 0 
    prev = None
    stuff_error = False

    for b in bits: 
        if runLen == STUFF_RUN:
            if b == prev:
                stuff_error = True
            prev = b
            runLen = 1
            continue
        dBits.append(b)

        if b== prev:
            runLen +=1
        else:
            prev = b
            runLen = 1

    return dBits, stuff_error

def _self_test():
    import random

    random.seed(0)

    # 1. Round-trip 
    for _ in range(2000):
        n = random.randint(0, 100)
        x = [random.randint(0, 1) for _ in range(n)]

        back, err = destuff(stuff(x))
        assert back == x, f"round-trip mismatch on {x}"
        assert not err, f"false stuff_error on {x}"

    # 2. alt bits
    u = [1, 0] * 10
    assert stuff(u) == u

    # 3. max
    assert stuff([0]*10) == [0,0,0,0,0,1,0,0,0,0,0,1]
    assert stuff([1]*10) == [1,1,1,1,1,0,1,1,1,1,1,0]

    assert len(stuff([0]*15)) == 18   
    assert len(stuff([0]*4))  == 4   

    bits, err = destuff(stuff([0]*10))
    assert bits == [0]*10 and not err

    # 4. rule 3
    assert stuff([0,0,0,0,0, 1,1,1,1]) == [0,0,0,0,0,1, 1,1,1,1, 0]
    assert stuff([1,1,1,1,1, 0,0,0,0]) == [1,1,1,1,1,0, 0,0,0,0, 1]

    #    destuff test
    bits, err = destuff([0,0,0,0,0,1, 1,1,1,1, 0])
    assert bits == [0,0,0,0,0, 1,1,1,1] and not err

    # 5. stuff_error
    _, err = destuff([1]*6)
    assert err, "six ones should be a stuff error"
    _, err = destuff([0]*6)
    assert err, "six zeros should be a stuff error"

    _, err = destuff([1]*5)
    assert not err, "five identical bits is legal"

    #    Fault injection
    wire = stuff([0]*10)              # [0,0,0,0,0,1,0,0,0,0,0,1]
    wire[5] = 0                       # flip the stuff bit -> six zeros in a row
    _, err = destuff(wire)
    assert err, "flipped stuff bit should be detected"



if __name__ == "__main__":
    _self_test()
    print("stuffing self-test PASSED")
