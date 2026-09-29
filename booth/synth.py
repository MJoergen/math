#! /usr/bin/env python3

# Estimate the resource usage of booth.vhd (radix 4) and booth_radix2.vhd
# (radix 2), for the tables in README.md.
#
# Each design is synthesized for Xilinx 7-series FPGAs with Yosys
# (https://github.com/YosysHQ/yosys, command synth_xilinx), using the GHDL
# plugin for Yosys (https://github.com/ghdl/ghdl-yosys-plugin) to read the
# VHDL. This prints a Markdown table with, for each design:
# * LUT, FF, CARRY4: The number of cells of each type in the whole design.
# * LUT levels: The largest number of LUTs on any path between two registers
#   (or between a port and a register). This is calculated from the netlist
#   below, since the Yosys command ltp does not skip the Xilinx flip-flops.
#
# Usage: ./synth.py [G_DATA_SIZE ...]    (default: 8 16 32 64)
# The generated files are written to the directory synth/.

import json
import os
import subprocess
import sys

DESIGNS = [("booth_radix2.vhd", "booth_radix2"), ("booth.vhd", "booth")]


def synthesize(path, top, size):
    base = os.path.join("synth", f"{top}_{size}")
    subprocess.run(["yosys", "-q", "-m", "ghdl", "-p",
                    f"ghdl --std=08 -gG_DATA_SIZE={size} {path} -e {top}; "
                    f"synth_xilinx -top {top} -flatten; "
                    f"write_json {base}.json"],
                   check=True, stdout=subprocess.DEVNULL)
    with open(f"{base}.json") as f:
        return json.load(f)["modules"][top]


# The largest number of LUTs on any combinational path. Flip-flops (FD*) and
# ports start and end the paths. Every other cell (LUTs, CARRY4, MUXF7, ...)
# is combinational, and each of its outputs may depend on each of its inputs.
def lut_levels(module):
    driver = {}                                 # bit -> cell that drives it
    for cell in module["cells"].values():
        if cell["type"].startswith("FD"):
            continue
        for port, bits in cell["connections"].items():
            if cell["port_directions"][port] == "output":
                for bit in bits:
                    driver[bit] = cell

    memo = {}

    def level(bit):
        if bit not in driver:                   # Flip-flop, port, or constant
            return 0
        if bit not in memo:
            cell = driver[bit]
            memo[bit] = 0                       # Guard against combinational loops
            inputs = [b for port, bits in cell["connections"].items()
                      if cell["port_directions"][port] == "input" for b in bits]
            memo[bit] = (cell["type"].startswith("LUT")) + max((level(b) for b in inputs), default=0)
        return memo[bit]

    sys.setrecursionlimit(100000)
    return max((level(bit) for bit in driver), default=0)


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    os.makedirs("synth", exist_ok=True)
    sizes = [int(s) for s in sys.argv[1:]] or [8, 16, 32, 64]

    print("| Design | `G_DATA_SIZE` | LUT | FF | CARRY4 | LUT levels |")
    print("| ------ | ------------- | --- | -- | ------ | ---------- |")
    for size in sizes:
        for path, top in DESIGNS:
            module = synthesize(path, top, size)
            count = {}
            for cell in module["cells"].values():
                kind = ("LUT" if cell["type"].startswith("LUT") else
                        "FF" if cell["type"].startswith("FD") else cell["type"])
                count[kind] = count.get(kind, 0) + 1
            print(f"| {top} | {size} | {count.get('LUT', 0)} | {count.get('FF', 0)} | "
                  f"{count.get('CARRY4', 0)} | {lut_levels(module)} |")


if __name__ == "__main__":
    main()
