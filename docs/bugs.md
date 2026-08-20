# Bug log

Bugs that took real work to find, and what each one taught. Typos and syntax
slips are not listed — only things where the code looked right and wasn't.

---

## B1 — The destuffer forgot the SOF bit

**Found:** 2026-08-20, first run of `tb_can_frame_fsm.v`
**Files:** `rtl/can_destuffer.v`

### What it looked like

The testbench decoded **336** frames when the stimulus only contains **310**.
The first four frames came out perfect. Frame 5 was garbage, and every frame
after it was garbage too.

More frames than exist means the decoder lost its place and started mistaking
ordinary data bits for the start of a new frame.

### What was actually wrong

CAN never allows more than 5 identical bits in a row. After 5, the sender jams
in one opposite bit, and the receiver has to delete it. So the destuffer keeps a
counter: how many identical bits in a row have I seen?

That counter has to start at the SOF bit, because SOF is part of the run:

```
SOF  ID bits →
 0   0 0 0 0  [1]  0 0 0 0 0  [1] ...
 └──5 zeros──┘ ↑
               added by the sender, must be deleted
```

The counter was being wiped one clock after SOF arrived, so it started over at
the first ID bit instead. From then on it was always one short:

```
             should be      actually was
SOF              1            (wiped)
ID bit 1         2                1
ID bit 2         3                2
ID bit 3         4                3
ID bit 4         5                4
next bit    reached 5 →      only 4 →
            DELETE it        KEEP it
```

The extra bit got decoded as data. The identifier came out as `00001000000`
instead of eleven zeros, and every field after it was shifted by one bit — DLC
read 4 instead of 8, the data field was half the right length, the CRC landed in
the wrong place.

### Why the first four frames were fine

They all used identifier `0x123`, which on the wire starts `0 0 1 0 0 1 ...`.
Counting SOF that is only two zeros before a one — it never reaches five, so no
stuff bit is inserted near the start and being one short made no difference.

Frame 5 is `maxStuff`, identifier `0x000`. Twelve zeros in a row counting SOF.
The first frame in the whole stimulus where the bug could show itself.

### The cause

The FSM tells the destuffer to clear its counter while it is hunting for the
start of a frame. That signal is a register, so it turns off **one clock after**
the thing that causes it. It was still on for one clock after SOF had arrived,
and on that clock no bit was present, so this branch ran:

```verilog
if (i_flush) begin
    if (i_bit_valid) begin ... run_len <= 3'd1; end
    else begin
        prev    <= 1'b0;
        run_len <= 3'd0;   // wiped the count SOF had just set
    end
end
```

### The fix

Delete the `else`. It was never needed — reset already sets both registers to
zero, and every bit arriving while flush is on sets the counter to 1 anyway. Its
only real effect was erasing the SOF.

### Why it could not be fixed in the FSM instead

Tried that first. Turning flush off inside the SOF state does not help, because
that assignment also lands one clock later.

The underlying reason: **the FSM is always one clock behind the destuffer.** The
destuffer handles a bit at one clock edge; the FSM does not see that bit until
the next one. So the FSM can never change the destuffer's behaviour on the clock
the bit actually arrives — the information has not reached it yet.

### The lesson

When two blocks are a clock apart, do not build something that needs one of them
to react instantly. Make the in-between clocks do nothing instead.

---

## B2 — The test could not pass even with the design correct

**Found:** 2026-08-20, same run
**Files:** `model/gen_frame_stim.py`

### What it looked like

Every decoded frame matched, and `diff` still failed on all 310 lines:

```
expected:  123 0 8 1111111111111111 589C 000
actual:    123 0 8 1111111111111111 589c 000
```

### What was wrong

Verilog's `%h` only ever prints lowercase hex. There is no uppercase option. The
Python model was writing uppercase, so the two files could never match no matter
how correct the hardware was.

### The fix

Switched the model to lowercase (`{x:03x}` instead of `{x:03X}`). The choice of
case is arbitrary — what matters is that both sides agree, and only one of them
had a choice.

### The lesson

A test that cannot pass is worse than no test: it costs the same time to run and
teaches nothing. Worth checking that a *known-good* result actually produces a
pass before trusting a failure.
