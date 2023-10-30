#!/bin/bash
ghdl compile --std=08 pipeline_sqrt.vhd tb_pipeline_sqrt.vhd -r tb_pipeline_sqrt -gG_EXTRA_BITS=0 --stop-time=50ms --wave=pipeline_sqrt.ghw
ghdl compile --std=08 pipeline_sqrt.vhd tb_pipeline_sqrt.vhd -r tb_pipeline_sqrt -gG_EXTRA_BITS=1 --stop-time=50ms --wave=pipeline_sqrt.ghw
ghdl compile --std=08 pipeline_sqrt.vhd tb_pipeline_sqrt.vhd -r tb_pipeline_sqrt -gG_EXTRA_BITS=2 --stop-time=50ms --wave=pipeline_sqrt.ghw
ghdl compile --std=08 pipeline_sqrt.vhd tb_pipeline_sqrt.vhd -r tb_pipeline_sqrt -gG_EXTRA_BITS=3 --stop-time=50ms --wave=pipeline_sqrt.ghw
ghdl compile --std=08 pipeline_sqrt.vhd tb_pipeline_sqrt.vhd -r tb_pipeline_sqrt -gG_EXTRA_BITS=4 --stop-time=50ms --wave=pipeline_sqrt.ghw

