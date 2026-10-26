# 4-bit Array Multiplier: RTL to GDSII (SKY130)

| Name | Roll number |
|------|-------------|
| Vidvathama R | 2024122002 |
| Anay Rungta | 2024102050 |

Part A example: the last digit of Vidvathama R's roll number (2024122002) is 2, so A = 2 + 5 = 7.
Since A = 7, B = 9, and 7 × 9 = 63.

Tools: Icarus Verilog 13.0, GTKWave 3.3.121, Yosys 0.69, OpenSTA 2.7.0, LibreLane 3.0.16,
SKY130 PDK (open_pdks `8afc8346`).

## Setup

Our Ubuntu 22.04 machine has no Docker or root access, so we installed the tools without root
instead of using IIC-OSIC-TOOLS:

```bash
micromamba create -n eda -c conda-forge -c litex-hub iverilog yosys gtkwave python=3.11
micromamba run -n eda pip install ciel
ciel enable --pdk-family sky130 8afc8346a57fe1ab7934ba5a6056ea8b43078e71
export PDK_ROOT=$HOME/.ciel PDK=sky130A
nix develop github:librelane/librelane/3.0.16    # LibreLane, OpenROAD, OpenSTA, Magic, Netgen, KLayout
```

All commands below are run from the repository root unless a `cd` is shown.

## Part A: RTL simulation

```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim                      # PASS: 256 vectors checked, 0 errors
gtkwave mult.vcd             # a=7, b=9 applied at 2440 ns, p=63 registered at 2455 ns

# error-injection test: change sum to a ^ b, run, then undo
sed -i 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim                      # FAIL: 256 vectors checked, 95 errors
sed -i 's/assign sum  = a ^ b;/assign sum  = a ^ b ^ cin;/' rtl/full_adder.v
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim                      # PASS again
```

## Part B: synthesis

```bash
yosys -c synth/synth.tcl
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls                      # PASS: 256 vectors checked, 0 errors
```

## Part C: static timing analysis

`sta/sta.tcl` reads the clock period from `CLK_PERIOD` (default 2.61 ns).

```bash
CLK_PERIOD=10 sta sta/sta.tcl     # worst slack 7.396 -> Tmin = 2.604 ns, Fmax = 384.0 MHz
CLK_PERIOD=2.60 sta sta/sta.tcl   # worst slack -0.004
sta sta/sta.tcl                   # T = 2.61 ns, slack +0.006, writes sta/mult_array_timing.rpt
```

## Part D: place and route

CLOCK_PERIOD = 1.2 × 2.604 = 3.125 ns, rounded up to 3.5 ns. `STA_CORNERS` limits sign-off to
the typical corner (`min/nom/max_tt_025C_1v80`), the same corner as Part C.

```bash
cd pnr
librelane --manual-pdk --pdk-root $PDK_ROOT --run-tag final_3.5 config.json
cp runs/final_3.5/final/metrics.json .
cp runs/final_3.5/final/gds/mult_array.gds .
klayout -l $PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyp mult_array.gds
```

### Run log

Runs 1–9 used LibreLane's default nine sign-off corners (tt/ss/ff × min/nom/max parasitics), each
run as `librelane --manual-pdk --pdk-root $PDK_ROOT --run-tag clk_<T> <config with CLOCK_PERIOD = T>`.
Only the slow-slow corner (1.60 V, 100 °C) failed. Run 10 is the final run with `config.json`.

| Run | CLOCK_PERIOD (ns) | Sign-off corners | setup__ws (ns) | nom_tt slack (ns) | DRC | LVS | Result |
|-----|------|---------|--------|--------|---|---|--------|
| 1   | 3.5  | all 9   | -2.093 | +0.493 | 0 | 0 | fail (ss) |
| 2   | 4.0  | all 9   | -1.593 | +0.993 | 0 | 0 | fail (ss) |
| 3   | 4.5  | all 9   | -1.093 | +1.493 | 0 | 0 | fail (ss) |
| 4   | 5.0  | all 9   | -0.596 | +1.991 | 0 | 0 | fail (ss) |
| 5   | 5.5  | all 9   | -0.104 | +2.487 | 0 | 0 | fail (ss) |
| 6   | 6.0  | all 9   | -0.043 | +2.795 | 0 | 0 | fail (ss) |
| 7   | 6.5  | all 9   | -0.155 | +3.050 | 0 | 0 | fail (ss) |
| 8   | 7.0  | all 9   | -0.046 | +3.317 | 0 | 0 | fail (ss) |
| 9   | 7.5  | all 9   | +0.454 | +3.817 | 0 | 0 | pass |
| 10  | 3.5  | tt only | +0.036 | +0.050 | 0 | 0 | **pass (final)** |

Final run: 4829 cells, 2513 µm wirelength, hold slack +0.307 ns.
Post-route Fmax = 1000 / (3.5 − 0.036) = 288.7 MHz (Part C: 384.0 MHz).
