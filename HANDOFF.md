# Handoff: Makefiles and READMEs for the fast_* and pipeline_sqrt folders

Delete this file before merging the branch.

## Context
Branch `makefiles-and-readmes` of github.com/MJoergen/math. The folders
`fast_divide`, `fast_sqrt`, `fast_sqrt2`, and `fast_sincos` are done:
* Each `sim.sh` is replaced by a Makefile modelled on `booth/Makefile`, with
  the targets `help`, `sim`, `debug`, `show_debug`, and `clean`.
* Each folder has a `.gitignore` and an expanded README.md.
* The cycle counts in the VHDL headers are corrected.
* The resource and timing numbers in the READMEs are measured with Vivado
  2025.1. It is installed in `/opt/Xilinx/2025.1/Vivado`, but is not in the
  PATH, so run `source /opt/Xilinx/2025.1/Vivado/settings64.sh` first.
* The clock constraints in `fast_sqrt.xdc` (now 4.1 ns) and `fast_sqrt2.xdc`
  (now 12.4 ns) are relaxed so that they meet timing.

## Task in progress: do the same for pipeline_sqrt
1. **Makefile:** Replace `ghdl.sh` with a Makefile in the same style.
   * The testbench needs `-gG_EXTRA_BITS=n`. Run it for n = 0 to 4 in a
     loop, like `DESIGNS` in `booth/Makefile`, with
     `--stop-time=50ms --assert-level=error`. Each run takes 3 to 4 minutes.
   * `debug` should be a short run with G_EXTRA_BITS=2, writing about 25 us
     of waveform.
   * Also add a `.gitignore`.
2. **Simulation (already verified):** All five runs reproduce the error
   tables in the current README.md exactly. GHDL prints a few "metavalue
   detected" warnings at 5 ns and 15 ns.
3. **Header:** There is no cycle count in the VHDL header. The design is a
   2-stage pipeline: one result per clock cycle, available 2 clock cycles
   after the input.
4. **No `.xdc` file:** There is none, and the `.xpr` has an empty constraints
   set. It synthesizes out of context with `G_EXTRA_BITS=2`, part
   xc7a200tfbg484-2.
5. **Vivado, the open issue:**
   * With an out-of-context build and a 4 ns clock, all n miss timing by
     0.06 to 0.13 ns.
   * More importantly, the ROMs end up as about 750 to 860 LUTs with 0 BRAM,
     although README.md says 2 BRAM and 1 DSP.
   * The synthesis log's preliminary report maps `stage1_sqrt_low_reg` and
     `stage1_inv_sqrt_reg` to Block RAM. So the tight clock probably made
     timing optimization move them into LUTs. This is not confirmed.
6. **Next steps:**
   * Try clock periods of 5, 6, 8, and 10 ns with G_EXTRA_BITS=2. Find a
     period where the ROMs stay in BRAM and timing is met.
   * Add a `pipeline_sqrt.xdc` with that clock, and add it to the `constrs_1`
     file set in the `.xpr`.
   * Update the "Synthesis report" numbers in README.md for each
     `G_EXTRA_BITS`.
   * If the ROMs never stay in BRAM, ask the user before changing the design
     (for example with a `rom_style` attribute).
7. **README.md:** Keep the existing content. Add sections on files,
   interface, running, and simulation, in the style of
   `fast_sqrt/README.md`.
8. **Finish:** Commit on the same branch with a message like
   `pipeline_sqrt: ...`, ending with the Co-Authored-By line. Delete this
   file.
