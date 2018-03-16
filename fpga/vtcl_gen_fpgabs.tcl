###################################################################
#      Vivado non-project build procedure
#      Author: Watson Huang
#      Description:
#           A non-project build process with necessary IP (.xci) for 
# 			learn-rv32i-arty project synthesis and implementation
# 			IP (.xci) version is based on Vivado 2017.4
#      Change Log:
#      02/13, 2018: Build ./fpgabs/fpga_rv32i_arty.bit done.
###################################################################

# [VTCL] Setup output directory/project name
set proj_name fpga_rv32i_arty
set output_dir ./fpgabs

if { [ file exists $output_dir ] } {
    file delete -force -- $output_dir
}
file mkdir $output_dir

# [VTCL] Force overwrite .xci file in /xci directory
if { ! [ file exists ./xci ] } {
    file copy -force -- ./src/xci ./
}

# [VTCL] Generate RV32I verilog file from Chisel3
exec bash -c "cd ./.. && sbt \"runMain rvfpga.rv32i_fpga -td ./fpga/gen_vlog\""

# [VTCL] Setup Vivado Project and Xilinx FPGA part (XC7A35T, Digilent Arty Board)
create_project -in_memory -part xc7a35ticsg324-1L -force $proj_name

# [VTCL] Read and Build Xilinx IP
read_ip ./xci/axi_intc/axi_intc.xci
read_ip ./xci/core_pll/core_pll.xci
read_ip ./xci/axi_mig_ddr3/axi_mig_ddr3.xci
read_ip ./xci/ddr3_pll/ddr3_pll.xci
generate_target all [get_files *.xci]
synth_ip [get_files *.xci]

# [VTCL] Read Verilog for FPGA synthesis
read_verilog ./gen_vlog/rv32i_fpga.v
read_verilog [ glob ./src/rtl/*.v ]
read_verilog [ glob ./src/rtl/extmem/*.v ]
read_verilog [ glob ./src/rtl/jtag/*.v ]

# [VTCL] Read Constraint for FPGA Place/Route
read_xdc [ glob ./src/xdc/*.xdc ]

# [VTCL] Synthesis Verilog to FPGA LUT/FF
synth_design -top rv32i_top
report_utilization -file $output_dir/post_synth_util.rpt

# [VTCL] Place FPGA LUT/FF on FPGA physical layout
opt_design
place_design
phys_opt_design
report_utilization -file $output_dir/post_place_util.rpt

# [VTCL] Route FPGA design signal path on FPGA physical layout
route_design
phys_opt_design
report_timing_summary -file $output_dir/post_route_timing_summary.rpt

# [VTCL] Output FPGA bitstream for configuring FPGA part (Digilent Arty Board)
write_bitstream -force $output_dir/$proj_name.bit