//=======================================================================
// RISCV, A Simple As Possible Core
// Watson Huang
// 
// Combine control path (cpath) and data path (dpath) into a core
// 
// Change Log:
//  01/02, 2018: Initial release
//  01/25, 2018: Remove direct Unit-Test interface
//=======================================================================
package rvcore

import chisel3._
import chisel3.util._
import rvcommon._

class core_io extends Bundle {
    val imem = new mram_io(rvspec.xlen)
    val dmem = new mram_io(rvspec.xlen)

    val dcpath = Flipped(new dcpath_io())
    val ddpath = Flipped(new ddpath_io())
}

class rvcore extends Module {
    val io = IO(new core_io)

    val cpath = Module(new rvcpath())
    val dpath = Module(new rvdpath())

    cpath.io.imem <> io.imem
    cpath.io.dmem <> io.dmem

    dpath.io.imem <> io.imem
    dpath.io.dmem <> io.dmem

    cpath.io.c2d <> dpath.io.c2d
    dpath.io.d2c <> cpath.io.d2c

    //Debug Module 
    cpath.io.dcpath <> io.dcpath
    dpath.io.ddpath <> io.ddpath

}