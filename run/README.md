# XSim simulation framework

The framework runs directly on the SystemVerilog sources selected by the two
project file lists:

1. `src/rtl/files.f` (compiled first)
2. `src/tb/files.f` (compiled second)

There are no Vivado IP-generation or UVM dependencies. Paths in a file list
are normally relative to the repository root. One source path per line keeps
the lists portable and makes their compilation order explicit. Empty lines,
lines beginning with `#` or `//`, `+incdir+...`, and `+define+...` are also
supported.

For example:

```text
# src/rtl/files.f
src/rtl/rv_fifo.sv
```

```text
# src/tb/files.f
src/tb/fifo_if.sv
src/tb/top_tb.sv
```

## Commands

Run these from the repository root:

```sh
# Compile, elaborate, run to $finish, and save run/sim/simulation.wdb
make -C run sim

# Stop after a fixed amount of simulation time
make -C run sim TIME=100us

# Override the default top-level module (top_tb)
make -C run sim TOP=my_top

# Pass SystemVerilog plusargs
make -C run sim ARGS='+seed=1 +test=smoke'

# Compile and start a live GUI simulation
make -C run gui

# Open the waveform database from the previous run without recompiling
make -C run view

# Remove generated files
make -C run clean
```

The `run_sim` and `batch` targets are aliases for `sim`. Simulation logs are
written to `run/logs/`. Before running, source the Vivado environment so that
`xvlog`, `xelab`, and `xsim` are available on `PATH`.
