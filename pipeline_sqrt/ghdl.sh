#!/bin/bash
ghdl compile --std=08 pipeline_sqrt.vhd tb_pipeline_sqrt.vhd -r tb_pipeline_sqrt --stop-time=50ms --wave=pipeline_sqrt.ghw

