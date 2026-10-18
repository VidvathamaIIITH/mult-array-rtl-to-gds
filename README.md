# 4-bit Array Multiplier: RTL to GDSII (SKY130)

Digital VLSI Design team assignment: a 4-bit × 4-bit unsigned array multiplier (16 AND gates,
12 full adders, 16 flip-flops, 2-cycle latency), taken from Verilog RTL to a routed
GDSII layout on the SkyWater SKY130 process (`sky130_fd_sc_hd`) with open-source tools.

## Team

| Name | Roll number |
|------|-------------|
| Vidvathama R | 2024122002 |
| Anay Rungta | 2024102050 |

Example used for Part A, task 5: the last digit of Vidvathama R's roll number (2024122002)
is 2, so **A = 2 + 5 = 7**. Because A = 7, the rule gives **B = 9**. 7 × 9 = **63**.

## Repository layout

```
README.md
rtl/full_adder.v              full adder (assign statements)
rtl/mult_array.v              array multiplier, 12 full_adder instances, no '*'
tb/tb_mult.v                  exhaustive self-checking testbench (256 vectors)
synth/synth.tcl               Yosys script
synth/mult_array_netlist.v    gate-level netlist           (generated)
synth/mult_array_stat.rpt     cell / area report           (generated)
sta/sta.tcl                   OpenSTA script
sta/mult_array_timing.rpt     critical-path report         (generated)
pnr/config.json               LibreLane configuration
pnr/metrics.json              from runs/<tag>/final/        (copied)
pnr/mult_array.gds            from runs/<tag>/final/gds/    (copied)
report/report.pdf             results tables, screenshots, answers
```

## Tool versions

| Tool | Version |
|------|---------|
| Icarus Verilog | 13.0 |
| Yosys (Parts A/B) | 0.69 |
| OpenSTA | 2.7.0 |
| LibreLane | 3.0.16 (bundles OpenROAD 2026-02-17, Yosys 0.62, Magic 8.3.623, Netgen 1.5.316, KLayout 0.30.7) |
| SKY130 PDK | open_pdks `8afc8346a57fe1ab7934ba5a6056ea8b43078e71` (the revision pinned by LibreLane 3.0.16), installed with `ciel` |

## Environment

The assignment recommends the IIC-OSIC-TOOLS Docker image. Our machine (Ubuntu 22.04) has no
Docker and no root access, so we installed the same tools without root:

```bash
# conda environment for iverilog / yosys / gtkwave (micromamba, conda-forge + litex-hub)
micromamba create -n eda -c conda-forge -c litex-hub iverilog yosys gtkwave python=3.11
micromamba run -n eda pip install ciel

# SKY130 PDK at the revision LibreLane 3.0.16 expects
ciel enable --pdk-family sky130 8afc8346a57fe1ab7934ba5a6056ea8b43078e71
export PDK_ROOT=$HOME/.ciel PDK=sky130A

# LibreLane + OpenROAD + OpenSTA + Magic + Netgen + KLayout from the official LibreLane Nix flake,
# run through nix-portable (no root needed)
nix develop github:librelane/librelane/3.0.16
```

Checks (Section 4.2):

```bash
iverilog -V | head -1      # Icarus Verilog version 13.0 (stable)
yosys -V                   # Yosys 0.69
sta -version               # 2.7.0
echo $PDK_ROOT $PDK        # /home/<user>/.ciel sky130A
```

All commands below are run from the repository root unless a `cd` is shown.

## Part A: RTL design and verification

```bash
# 1-4. simulate the RTL with the exhaustive testbench
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
#   -> PASS: 256 vectors checked, 0 errors
gtkwave mult.vcd

# 6. error-injection test: temporarily change sum in rtl/full_adder.v to  a ^ b
sed -i 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
#   -> MISMATCH at 1060 ns: a=3 b=3 p=5 expected=9   (95 mismatch lines)
#   -> FAIL: 256 vectors checked, 95 errors
# undo the change
sed -i 's/assign sum  = a ^ b;/assign sum  = a ^ b ^ cin;/' rtl/full_adder.v
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
#   -> PASS: 256 vectors checked, 0 errors
```

The example a = 7, b = 9 is applied at 2440 ns. It is captured into `a_r`/`b_r` at the
2445 ns edge, and p = 63 appears at the 2455 ns edge, two clock cycles later.

## Part B: logic synthesis

```bash
yosys -c synth/synth.tcl
#   -> synth/mult_array_netlist.v, synth/mult_array_stat.rpt

# gate-level simulation of the netlist with the same testbench
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
#   -> PASS: 256 vectors checked, 0 errors
```

Result: 63 cells, 16 flip-flops (`sky130_fd_sc_hd__dfrtp_1`), 740.71 µm² total, of which
400.38 µm² (54.05 %) is flip-flops.

## Part C: static timing analysis

`sta/sta.tcl` reads the clock period from the `CLK_PERIOD` environment variable.
The default is the final value, 2.61 ns.

```bash
# run 1: T = 10 ns
CLK_PERIOD=10 sta sta/sta.tcl
#   -> worst slack max 7.40    (7.396 ns in the report)
#   Tmin = 10 - 7.396 = 2.604 ns,  Fmax = 1000 / 2.604 = 384.0 MHz

# run 2: T = Tmin rounded to 0.01 ns
CLK_PERIOD=2.60 sta sta/sta.tcl
#   -> worst slack max -0.00   (-0.004 ns: 2.60 is just below 2.604)
sta sta/sta.tcl                       # T = 2.61 ns (rounded up)
#   -> worst slack max 0.01    (+0.006 ns), written to sta/mult_array_timing.rpt
```

Critical path: `a_r[1]` (launch flip-flop) → `p[6]` (capture flip-flop, the sum of the last
full adder `fa_r3_3`), through 8 combinational cells.

## Part D: physical design with LibreLane

CLOCK_PERIOD = 1.2 × Tmin = 1.2 × 2.604 = 3.125 ns, rounded up to the next 0.5 ns = **3.5 ns**.

```bash
cd pnr
librelane --manual-pdk --pdk-root $PDK_ROOT config.json
# (--manual-pdk uses the PDK already installed with ciel instead of downloading it again)

# copy the results of the successful run
cp runs/<tag>/final/metrics.json .
cp runs/<tag>/final/gds/mult_array.gds .

# view the layout
klayout mult_array.gds
```

### Run log

LibreLane's `setup__ws` metric is the worst setup slack over all 9 signoff corners
(tt / ss / ff × min / nom / max parasitics). We increased CLOCK_PERIOD by 0.5 ns until it was ≥ 0.
Each attempt was run as `librelane --manual-pdk --pdk-root $PDK_ROOT --run-tag clk_<T> <config with CLOCK_PERIOD = T>`.

| # | CLOCK_PERIOD (ns) | setup__ws (ns) | tt setup WS (ns) | DRC | LVS | Result |
|---|------|--------|--------|---|---|--------|
| 1 | 3.5 | -2.093 | +0.493 | 0 | 0 | fail (ss corner) |
| 2 | 4.0 | -1.593 | +0.993 | 0 | 0 | fail (ss corner) |
| 3 | 4.5 | -1.093 | +1.493 | 0 | 0 | fail (ss corner) |
| 4 | 5.0 | -0.596 | +1.991 | 0 | 0 | fail (ss corner) |
| 5 | 5.5 | -0.104 | +2.487 | 0 | 0 | fail (ss corner) |
| 6 | 6.0 | -0.043 | +2.795 | 0 | 0 | fail (ss corner) |
| 7 | 6.5 | -0.155 | +3.050 | 0 | 0 | fail (ss corner) |
| 8 | 7.0 | -0.046 | +3.317 | 0 | 0 | fail (ss corner) |
| 9 | **7.5** | **+0.454** | +3.817 | 0 | 0 | **pass** |

The final `config.json` has `CLOCK_PERIOD = 7.5`. It was run once more as
`librelane --manual-pdk --pdk-root $PDK_ROOT --run-tag final config.json`, which gave the same
result (setup__ws +0.454 ns, hold +0.120 ns, 0 DRC (Magic and KLayout), 0 LVS, 4831 instances,
2516 µm wirelength). `pnr/metrics.json` and `pnr/mult_array.gds` were copied from
`runs/final/final/`.

Post-route Fmax = 1000 / (7.5 - 0.454) = 141.9 MHz (worst corner), or 271.5 MHz using the
tt-corner slack, versus 384.0 MHz from Part C.

Layout screenshots in the report were rendered with KLayout in batch mode:
`klayout -zz -rd gds=pnr/mult_array.gds -rd lyp=$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyp -r render_gds.py`.

## Git history

The work was committed one part at a time (Part A, B, C, D, report). The `runs/` folder is
not committed (see `.gitignore`).
