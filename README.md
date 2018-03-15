A Simple As Possible RISCV-32I on Digilent Arty board
===

This project is porting [learn-rv32i-asap project](https://github.com/watz0n/learn-rv32i-asap) on [Digilent Arty board](https://store.digilentinc.com/arty-a7-artix-7-fpga-development-board-for-makers-and-hobbyists/).

This FPGA RV32I core has the same RISC-V implementation as [learn-rv32i-asap project](https://github.com/watz0n/learn-rv32i-asap), but noticeable changes as below:

* Change 3-port magic memory to 3-to-1 port memory aribter for interfacing external memory 
* Stall instruction fetch to wait memory aribter handle data or debug memory acccess
* Connect on-board DDR3 by Xilinx MIG IP with AXI4 interface
* Apply Xilinx JTAG USER Register to transfter RISC-V Debug Module Interface (DMI) 41-bit commands

The first problem to move RISCV-32I design from ideal simulation to real world is memory interface. From [learn-rv32i-asap project](https://github.com/watz0n/learn-rv32i-asap) design, this core needs 3-port interface form ideal Magic RAM. But, the Xilinx FPGA only support 2-port Block RAM and 1-to-mulit port Distribute RAM. It's sad that total usable RAM in FPGA is about 1.8M bits, but our testbench like qsort/rsort needs about 2M bytes to accommodate the executable code and processing data. Therefore, on-board DDR3 (256MB) is necessary for testbench. The choice of MIG AXI4 interface rather than Native MIG interface is for portability, this external memory could be replace by Block RAM with AXI4 interface with small effort.

The second problem is how to transfer executable code to Arty board from PC. If we minimize the Arty board, there are only 1 USB cable for USB-JTAG and USB-UART through on-board FT2232H bridge chip. In order to save USB-UART for human readable information in future design, the choice will be left with USB-JTAG port, which is Xilix/Digilent official FPGA configuration port, too. By Xilinx FPGA Configuration [(UG470)](https://www.xilinx.com/support/documentation/user_guides/ug470_7Series_Config.pdf) document, the official JTAG has USER1 to USER4 register for tranfering data between FPGA and PC. I choosed USER4 as interface, because USER1 would be allocated by Xilinx Debug ILA core as default.

If you want to know the system internal architecture, please reference the [system overview](https://github.com/watz0n/learn-rv32i-arty/blob/master/doc/RV32I-Arty-DDR3-Overview.png) and blog post: [Port Chisel3 build RV32I Core on Arty Board] (TBD). Adhere, this README would only talk about how to use this project, focus on how to synthesis FPGA with pre-defined IPs and how to transfer data to Xilinx JTAG USER4 register via Xilinx xsdbserver. 

Usage Guide
===

My develope environment based on Windows 10, thus I seperate two workspace:

* Windows 10: Xilinx Vivado and XSCT for FPGA
* Bash on Windows, Ubuntu 16.04 LTS: Verilator and Chisel3/Scala

Because Bash on Windows subsystem couldn't access USB cable hardware, so I host a socket server from XSCT by xsdbserver command, and use emulator as client to transfer DMI command data to FPGA through Xilinx JTAG sequence. This mechanism reference from [riscv-sodor, tilelink2 branch](https://github.com/librecores/riscv-sodor/tree/tilelink2_fpga/fpga), which use [USB-UART path](https://github.com/librecores/riscv-sodor/wiki/arty) which seems from [lowRISC debug interface](http://www.lowrisc.org/docs/debug-v0.3/overview/), and this project use another USB-JTAG path from [arty-xjtag project](https://github.com/watz0n/arty_xjtag).

Prepare the project environment
---
Setup process is the same as [learn-rv32i-asap project](https://github.com/watz0n/learn-rv32i-asap), the appropriate 3-to-1 port Magic RAM is ready for emulator in this project. Please make sure emulator from this project could pass all test by `make run-emulator`.

Synthesis the FPGA
---
Assume project directory is `D:\FPGA\learn-rv32i-arty`.

Open `Xilinx Design Tools`, then select `Vivado 2017.4 Tcl Shell`, and input below commands:
```
Vivado% cd d:/FPGA/learn-rv32i-arty/fpga
Vivado% source vtcl_gen_fpgabs.tcl
...... #synthesis/implementation informations
./fpgabs/fpga_rv32i_arty.bit
```
This process would spent about 40 minutes to generate bitstream at `./fpgabs/fpga_rv32i_arty.bit`.

Configure FPGA and Host xsdbserver
---
Assume project directory is `D:\FPGA\learn-rv32i-arty`.

Open `Xilinx Design Tools`, then select `Xilinx Software Command Line Tool 2017.4`, and input below commands:
```
xsct% cd d:/FPGA/learn-rv32i-arty/fpga
xsct% source xsct_jtagd.tcl
xsct% jtagd_start
...... #Configure bitstream and start xsdbserver
Connect to this XSDB server use host YOUR_PC_NAME and port 3333
```
If you want to know more detail about Xilinx JTAG toolchain, please reference the [arty-xjtag project](https://github.com/watz0n/arty_xjtag).

Build Emulator and Run Testbench
---
Assume project directory is `D:\FPGA\learn-rv32i-arty`, map to Bash on Windows is `/mnt/d/FPGA/learn-rv32i-arty`. And the xsdbserver is host on the same computer.

Open `Bash on Ubuntu on Windows`, and input below commands:
```
cd /mnt/d/FPGA/learn-rv32i-arty/emulator/arty
make dtmxsdb
...... # build information
# run all test, asm-tests and bmarks-test
make port=3333 arty-run
157... [rv32ui-p-simple]:Success
...... # other testbenches
```

If you find anything wrong and want to have more detail, here is an manual execution example:
```
# add +verbose flag to show req/resp actions
./dtmxsdb +verbose +p3333 +loadmem=../../install/riscv-tests/rv32ui-p-simple
req : 0x16 0x00000000 0x1
resp: 0x16 0x1000000c 0x0
...... # request(req)/response(resp) list
req : 0x48 0x00000001 0x2
resp: 0x48 0x00000000 0x0
 [rv32ui-p-simple]:Success, 157
```
From the last line information, status `Success` means pass the return value has been checked by emulator, and the number `157` means this test total req/resp pairs. 

Below is 1 req/resp pair example:
```
      DMI ADDR | DMI DATA   | DMI OP
req : 0x16       0x00000000   0x1 <- READ (req OP==1) DATA at ADDR[0x16]
resp: 0x16       0x1000000c   0x0 <- resp OP==0, previous operation (READ ADDR[0x16]) complete  
```

FPGA Utilization and Timing
===
After generated FPGA bitstream, there are some reports under `fpgabs` directory.

| File Name | Report Content |
| --- | --- |
| post_synth_util.rpt | FPGA Utilization after Synthesis phase |
| post_place_util.rpt | FPGA Utilization after Placement phase |
| post_route_timing_summary.rpt | Overall FPGA Timing Report after Routing phase |

Brief summaries from Xilinx 2017.4 reports
---

From the FPGA utilization after placement, roughly used 65% FPGA CLB area.
```
|          Site Type         |  Used | Fixed | Available | Util% |
+----------------------------+-------+-------+-----------+-------+
| Slice LUTs                 | 13449 |     0 |     20800 | 64.66 |
|   LUT as Logic             | 12685 |     0 |     20800 | 60.99 |
|   LUT as Memory            |   764 |     0 |      9600 |  7.96 |
|     LUT as Distributed RAM |   552 |     0 |           |       |
|     LUT as Shift Register  |   212 |     0 |           |       |
| Slice Registers            | 11149 |    12 |     41600 | 26.80 |
|   Register as Flip Flop    | 11137 |    12 |     41600 | 26.77 |
|   Register as Latch        |     0 |     0 |     41600 |  0.00 |
|   Register as AND/OR       |    12 |     0 |     41600 |  0.03 |
```

For the FPGA max-delay path after route, it's propagation time is 64.222ns. Because this core running at 10MHz (100ns), it's fine for this unpipelined design.
```
Max Delay Paths
--------------------------------------------------------------------------------------
Slack (MET) :             64.222ns  (required time - arrival time)
  Source:                 rv32i/rvtile/memarb/reg_ipvld_reg/C
                            (rising edge-triggered cell FDRE clocked by clk_out1_core_pll  {rise@0.000ns fall@50.000ns period=100.000ns})
  Destination:            rv32i/rvtile/core/dpath/regfile_8_reg[27]/D
                            (rising edge-triggered cell FDRE clocked by clk_out1_core_pll  {rise@0.000ns fall@50.000ns period=100.000ns})
```

Simulation Waveform for Debug
===

Because this project use Non-Project mode to simplify the build process, there are some Project Mode files in [xprj_rv32i_arty project](https://github.com/watz0n/xprj_rv32i_arty) for debug simulation. The project respository has two back-end memory candidates, BRAM and DDR3. The BRAM project is built for quick simulation for RV32I core or JTAG module debug process, the DDR3 project is aimed to simulate overall system for learn-rv32i-arty project. 

TODO List
===
* Document for this design detail, but after draft the learn-rv32i-assp document
* Pipelined RV32I core on FPGA with L1 I/D Cache
* Interfacing peripheral by new UART, SPI, I2C module
* Display graphic information by [Digilent Pmod OLEDrgb](https://store.digilentinc.com/pmod-oledrgb-96-x-64-rgb-oled-display-with-16-bit-color-resolution/) 

Contact Information
===

If you have any questions, corrections, or feedbacks, please email to me or open an issus.

* E-Mail:   watz0n.tw@gmail.com
* Blog:     https://blog.watz0n.tech
* Backup:   https://watz0n.github.io