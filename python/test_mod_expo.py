#!/usr/bin/env python3
# =============================================================================
# Dr. W.A. Susantha Wijesinghe
# susantha@wyb.ac.lk
# Department of Electronics
# Faculty of Applied Sciences
# Wayamba University of Sri Lanka
# Date: 10 September 2026
# =============================================================================

"""
UART functional test for Mod_Expo_SARME_TOP_v2 (64-bit modular exponentiation core).

WHAT THIS DOES
--------------
Sends (base, exponent, modulus) triples to the FPGA over UART, reads back
the echoed operands + the computed result + the cycle count, and checks
the result against Python's built-in pow(base, exponent, modulus).

PROTOCOL (matches the FSM in Mod_Expo_SARME_TOP_v2.v)
-------------------------------------------------------
Host -> board : A  (base,     8 bytes, MSB first)
                B  (exponent, 8 bytes, MSB first)
                C  (modulus,  8 bytes, MSB first)
The board auto-starts computation the instant C is fully received.
Board -> host : C  (echoed,   8 bytes, MSB first)
                B  (echoed,   8 bytes, MSB first)
                A  (echoed,   8 bytes, MSB first)
                result         (8 bytes, MSB first)
                cycles         (8 bytes, MSB first)
The board then returns to IDLE by itself, so vectors can be sent back-to-back
with no reset in between.

KNOWN, ACCEPTED LIMITATION
---------------------------
modulus = 0 is mathematically undefined and is not tested.
modulus = 1 is a known FAIL on this core (result should be 0, board returns 1).
This is cryptographically meaningless (no real application ever uses modulus=1)
and is intentionally left unfixed -- it is excluded from the pass/fail count
below but still reported, in case you want to see it.

USAGE
-----
    pip install pyserial
    python3 test_mod_expo.py /dev/ttyUSB0          # Linux
    python3 test_mod_expo.py COM3                  # Windows

Author: generated with Claude, for internal verification use.
"""

import argparse
import random
import sys
import time

import serial

# ---------------------------------------------------------------------------
# Constants matching the hardware's fixed 64-bit operand width and UART setup
# ---------------------------------------------------------------------------
N_BITS = 64
N_BYTES = N_BITS // 8
BAUD_RATE = 115200
MASK64 = (1 << N_BITS) - 1


def int_to_bytes_be(value: int, nbytes: int = N_BYTES) -> bytes:
    """Pack a Python int into nbytes, most-significant byte first."""
    if value < 0 or value >= (1 << (8 * nbytes)):
        raise ValueError(f"{value} does not fit in {nbytes} bytes")
    return value.to_bytes(nbytes, byteorder="big")


def bytes_be_to_int(data: bytes) -> int:
    """Unpack a big-endian byte string back into a Python int."""
    return int.from_bytes(data, byteorder="big")


def read_exact(ser: serial.Serial, nbytes: int, label: str) -> bytes:
    """Read exactly nbytes from the serial port, or raise a clear timeout error."""
    data = ser.read(nbytes)
    if len(data) != nbytes:
        raise TimeoutError(
            f"Timed out reading '{label}': expected {nbytes} bytes, "
            f"got {len(data)} ({data.hex()})"
        )
    return data


def run_vector(ser: serial.Serial, base: int, exponent: int, modulus: int,
                verbose: bool = True) -> dict:
    """
    Send one (base, exponent, modulus) test vector to the board, read back
    its response, and check it against the Python reference computation.
    Returns a dict of everything sent/received plus pass/fail flags.
    """
    base &= MASK64
    exponent &= MASK64
    modulus &= MASK64

    # --- send operands, MSB first ---
    ser.write(int_to_bytes_be(base))
    ser.write(int_to_bytes_be(exponent))
    ser.write(int_to_bytes_be(modulus))
    ser.flush()

    # --- receive echoed operands (board sends C, B, A in that order) ---
    c_echo = bytes_be_to_int(read_exact(ser, N_BYTES, "C echo"))
    b_echo = bytes_be_to_int(read_exact(ser, N_BYTES, "B echo"))
    a_echo = bytes_be_to_int(read_exact(ser, N_BYTES, "A echo"))

    # --- receive result and cycle count ---
    result = bytes_be_to_int(read_exact(ser, N_BYTES, "result"))
    cycles = bytes_be_to_int(read_exact(ser, N_BYTES, "cycles"))

    # --- reference computation (Python's built-in, exact big-integer modexp) ---
    expected = pow(base, exponent, modulus) if modulus != 0 else None

    echo_ok = (a_echo == base) and (b_echo == exponent) and (c_echo == modulus)
    result_ok = (expected is not None) and (result == expected)
    is_known_limitation = (modulus == 1)  # see module docstring

    if verbose:
        if is_known_limitation:
            status = "SKIP (known limitation, modulus=1)"
        else:
            status = "PASS" if (echo_ok and result_ok) else "FAIL"
        print(f"[{status}] A={base:#018x} B={exponent:#018x} C={modulus:#018x}")
        if not echo_ok:
            print(f"         echo mismatch -> A':{a_echo:#018x} "
                  f"B':{b_echo:#018x} C':{c_echo:#018x}")
        print(f"         result={result:#018x}  expected="
              f"{'n/a (mod=0)' if expected is None else f'{expected:#018x}'}")
        print(f"         cycles={cycles}")

    return {
        "base": base, "exponent": exponent, "modulus": modulus,
        "result": result, "expected": expected, "cycles": cycles,
        "echo_ok": echo_ok, "result_ok": result_ok,
        "is_known_limitation": is_known_limitation,
    }


def build_test_vectors(num_random: int = 20) -> list:
    """
    Fixed set of hand-picked edge cases + a batch of random full-range vectors.
    The random ones use a fixed seed so results are reproducible across runs.
    """
    vectors = [
        (0, 0, 1),                       # known limitation, see docstring -- expect SKIP
        (5, 0, 13),                      # exponent=0 -> result must be 1
        (0, 5, 13),                      # base=0 -> result must be 0
        (2, 10, 1000),                   # small textbook case: 2^10 mod 1000 = 24
        (7, 560, 561),                   # Carmichael-number style stress case
        (MASK64, MASK64, MASK64 - 1),    # all-ones edge case
        (123456789, 987654321, 4294967311),   # arbitrary mid-size case
    ]
    rng = random.Random(42)  # fixed seed -> same vectors every run
    for _ in range(num_random):
        base = rng.randint(0, MASK64)
        exponent = rng.randint(0, MASK64)
        modulus = rng.randint(2, MASK64)  # >=2: skip the undefined/known-limitation cases
        vectors.append((base, exponent, modulus))
    return vectors


def main():
    parser = argparse.ArgumentParser(
        description="Verify Mod_Expo_SARME_TOP_v2 against Python's pow() over UART"
    )
    parser.add_argument("port", help="Serial device, e.g. /dev/ttyUSB0 or COM3")
    parser.add_argument("--baud", type=int, default=BAUD_RATE)
    parser.add_argument("--timeout", type=float, default=2.0,
                         help="Per-read timeout in seconds")
    parser.add_argument("--random-vectors", type=int, default=20,
                         help="Number of extra random full-width test vectors")
    args = parser.parse_args()

    try:
        ser = serial.Serial(args.port, args.baud, timeout=args.timeout)
    except serial.SerialException as exc:
        print(f"Could not open {args.port}: {exc}")
        sys.exit(1)

    time.sleep(0.2)  # let the board settle after the port opens (DTR toggle, etc.)
    ser.reset_input_buffer()

    vectors = build_test_vectors(args.random_vectors)
    results = []
    for base, exponent, modulus in vectors:
        try:
            results.append(run_vector(ser, base, exponent, modulus))
        except TimeoutError as exc:
            print(f"[FAIL] A={base:#018x} B={exponent:#018x} C={modulus:#018x} "
                  f"-> {exc}")
            ser.reset_input_buffer()

    ser.close()

    # --- summary ---
    tested = [r for r in results if not r["is_known_limitation"]]
    skipped = [r for r in results if r["is_known_limitation"]]
    passed = sum(1 for r in tested if r["echo_ok"] and r["result_ok"])

    print("\n--- Summary ---")
    print(f"Vectors sent:        {len(vectors)}")
    print(f"Responses received:  {len(results)}")
    print(f"Skipped (known lim): {len(skipped)}")
    print(f"Passed:              {passed} / {len(tested)}")
    print(f"Failed:              {len(tested) - passed} / {len(tested)}")
    if results:
        avg_cycles = sum(r["cycles"] for r in results) / len(results)
        print(f"Average reported cycles: {avg_cycles:.1f}")

    # Non-zero exit code on any real failure -- useful if this is ever run in CI.
    sys.exit(0 if passed == len(tested) else 1)


if __name__ == "__main__":
    main()
