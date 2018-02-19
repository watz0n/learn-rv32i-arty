//=======================================================================
// RISCV, A Simple As Possible Core
// Watson Huang
// 
// Generate Verilog for FPGA synthesis (mainly Arty Board)
//
// Change Log:
//  02/05, 2018: Build without DMI simulator and export external memory interface for FPGA top verilog
//=======================================================================
package rvfpga

import chisel3._
import chisel3.util._

import rvcommon._
import rvcore._
import rvtile._

class rv32i_fpga extends Module {
   val io = IO(new Bundle{
      val dmi = Flipped(new dmi_io());
      val ext_mem = Flipped(new rvextmemif_io())
    })
    val rvtile = Module(new rvtile)
    rvtile.io.dmi <> io.dmi
    rvtile.io.ext_mem <> io.ext_mem
}

object rv32i_fpga extends App {
    chisel3.Driver.execute(args, () => new rv32i_fpga)
}
