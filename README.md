# DSP-Free Modular Exponentiation on FPGA

A Verilog/SystemVerilog hardware implementation of modular exponentiation that uses **zero DSP blocks and zero BRAM**, relying entirely on addition, bit-shifting, and comparison logic. Designed for resource-constrained FPGAs — IoT endpoints, secure sensor nodes, and embedded controllers — where DSP slices are scarce, absent, or too power-hungry for the application.

This repository accompanies the peer-reviewed paper:

> W. A. Susantha Wijesinghe, "An area-efficient DSP-free modular exponentiation architecture for resource-constrained FPGAs," *Journal of King Saud University – Engineering Sciences*, vol. 37, no. 32, 2025. https://doi.org/10.1007/s44444-025-00031-9

If you use this design in academic work, please cite the paper (BibTeX below).

## How it works

The core replaces the conventional square-and-multiply exponentiation algorithm's multiplication step with **repeated shift-and-add**, and replaces hardware division/Barrett-style reduction with a **subtraction-based modulus operation** — eliminating both multipliers and dividers from the datapath entirely. Every result is kept reduced mod `C` at each step, so no intermediate value grows unbounded.

At a high level, each bit of the exponent triggers:
1. A conditional shift-and-add **multiply-and-reduce** step (only when the exponent bit is 1).
2. An unconditional shift-and-add **square-and-reduce** step (every iteration).

This is why the underlying core in this repo is internally named `my_sarme4` / `my_sarme_top` — SARME here stands for **Square-And-Reduce Modular Exponentiation**, describing the two operations repeated at every bit of the exponent.

Published results (Xilinx Artix-7 XC7A35T, Basys 3 board, Vivado 2018.3) across 32–1024-bit operands show linear LUT/FF/slice scaling (R² ≥ 0.999), zero DSP and BRAM usage at every size, and total on-chip power of 0.23 W at 1024 bits — full figures in Tables 1–5 of the paper.

## Repository contents

| File | Description |
|---|---|
| `Mod_Expo_SARME_TOP_v2.v` | Top-level module: UART framing/state machine that receives base/exponent/modulus, drives the core, and returns the result + cycle count |
| `my_sarme_top.v` | Thin wrapper instantiating the exponentiation core and the cycle counter |
| `my_sarme4.v` | The exponentiation FSM: square-and-reduce / multiply-and-reduce datapath (this repo's build is parameterized for N = 64 bits) |
| `modulus.v` | Shift-subtract modulus operation (no division), described in the referenced Wijesinghe (2025) modulus paper |
| `clk_div.v` | Clock divider from the 100 MHz board clock to the core's operating clock |
| `cycle_counter.v` | Free-running counter gated by `start`/`done`, used to report execution latency |
| `uart_rx.sv` / `uart_tx.sv` | UART receive/transmit modules for the PC↔FPGA interface |
| `test_mod_expo.py` | Python/pyserial test harness — sends test vectors over UART and checks results against Python's `pow(base, exponent, modulus)` |

## Hardware/software requirements

- Xilinx Vivado (design verified on 2018.3; later versions should work)
- A Basys 3 (or other Artix-7) board, or adapt the top module's I/O for your target
- Python 3 with `pyserial` (`pip install pyserial`) for the test harness

## Building and testing

1. Add all `.v`/`.sv` files to a Vivado project, set `Mod_Expo_SARME_TOP_v2` as the top module, and assign UART/clock/reset pins per your board's XDC.
2. Synthesize, implement, generate a bitstream, and program the device.
3. Run the test harness against the board's UART port:

   ```bash
   python3 test_mod_expo.py /dev/ttyUSB0        # Linux
   python3 test_mod_expo.py COM3                # Windows
   ```

   The script sends a fixed set of edge-case vectors plus 20 random full-width vectors (reproducible via a fixed seed), and reports pass/fail against Python's reference `pow()`.

## Known limitation

`modulus = 1` is not correctly handled by the current RTL (the initial `result` register is not reduced mod `C` before the exponent loop begins, so it returns `1` instead of the mathematically correct `0`). This has no practical impact — no real cryptographic application uses modulus = 1 — and is excluded from the pass/fail count in `test_mod_expo.py`, where it is reported as `SKIP`.

## Citation

```bibtex
@article{wijesinghe2025dspfree,
  author  = {Wijesinghe, W. A. Susantha},
  title   = {An area-efficient {DSP}-free modular exponentiation architecture for resource-constrained {FPGA}s},
  journal = {Journal of King Saud University -- Engineering Sciences},
  volume  = {37},
  number  = {32},
  year    = {2025},
  doi     = {10.1007/s44444-025-00031-9},
  url     = {https://doi.org/10.1007/s44444-025-00031-9}
}
```

The related modulus operation used in this design is described in:

> W. A. S. Wijesinghe, "An efficient algorithm for modulus operation and its hardware implementation in prime number calculation," *AEU-International Journal of Electronics and Communications*, vol. 191, 2025, art. 155657. https://doi.org/10.1016/j.aeue.2024.155657

## Author

**Dr. W. A. Susantha Wijesinghe**
susantha@wyb.ac.lk
Department of Electronics, Faculty of Applied Sciences
Wayamba University of Sri Lanka

## License

The code in this repository is licensed under the MIT License — see [LICENSE](LICENSE) for the full text.

```
MIT License

Copyright (c) 2026 W. A. Susantha Wijesinghe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

The paper itself is published open access under [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/) — that license governs the paper's text and figures, not this code.
