//=======================================================================
// RISCV, A Simple As Possible Core
// Watson Huang
// 
// Generate Verilog from FIRRTL entry for Verilator simulation
//
// Change Log:
//  01/02, 2018: Initial release
//  01/25, 2018: Remove Unit-Test interface
//  02/05, 2018: Move memory out of core as external memory
//=======================================================================
package rvtop

import chisel3._
import chisel3.util._
import chisel3.iotesters._
import chisel3.experimental._ //For BlockBox Parameter

import rvcommon._
import rvcore._
import rvtile._

//External Memory
//Use Verilog source to simulate memory
//Reference: https://github.com/freechipsproject/chisel3/wiki/BlackBoxes#blackboxes-with-verilog-in-a-resource-file
//Instantiation Parameterization
//Ref: https://github.com/freechipsproject/chisel3/wiki/BlackBoxes#parameterization
class rvmemspv extends BlackBox(Map(
        //require "import chisel3.experimental._" for BlackBox Verilog Parameterization 
        "MEM_SIZE" -> 0x40000,
        "WRITE_DELAY" -> 1,
        "READ_DELAY" -> 1
    )) with HasBlackBoxResource {

    val io = IO(new rvextmemif_io())
    setResource("/rvmemspv.v")
}

//Morphic form Top in riscv-sodor Top.scala
//Ref: https://github.com/ucb-bar/riscv-sodor/blob/master/src/rv32_1stage/top.scala

class rvtop extends Module {
   val io = IO(new Bundle{
      val success = Output(Bool())
    })
    val rvtile = Module(new rvtile)
    val ext_mem = Module(new rvmemspv)
    ext_mem.io <> rvtile.io.ext_mem
    val dtm = Module(new rvsimdtm).connect(clock, reset.toBool, rvtile.io.dmi, io.success)
}

//Ref: https://github.com/freechipsproject/chisel3/wiki/Frequently%20Asked%20Questions#get-me-verilog
object elaborate extends App {
  chisel3.Driver.execute(args, () => new rvtop)
}
