# Command-line build for the Tang Nano 20K port.
# Run from this directory:  gw_sh build.tcl
# Bitstream lands in impl/pnr/poket_animal.fs

set_device GW2AR-LV18QN88C8/I7 -device_version C

add_file src/top.v
add_file ../../src/project.v
add_file src/tangnano20k.cst
add_file src/tangnano20k.sdc

set_option -top_module top
set_option -verilog_std v2001
set_option -output_base_name poket_animal

run all
