//=======================================================================
// RISCV, A Simple As Possible Core
// Watson Huang
// Jan 2, 2018
// 
// Combine a core and a magic ram (mram) into a tile
// 
// Change Log:
//  01/02, 2018: Initial release
//  01/25, 2018: Remove Unit-Test interface
//  02/05, 2018: Move memory out of core as external memory
//=======================================================================
package rvtile

import chisel3._
import chisel3.util._
import rvcommon._
import rvcore._

class tile_io extends Bundle {
    val dmi = Flipped(new dmi_io())
    val ext_mem = Flipped(new rvextmemif_io())
}

class rvtile extends Module {

    val io = IO(new tile_io)

    val dm = Module(new rvdm())
    val core = Module(new rvcore())
    //val amem = Module(new mram_async())
    val memarb = Module(new rvmemarb())

    //core.io.imem <> amem.io.inst_port
    //core.io.dmem <> amem.io.data_port

    core.io.imem <> memarb.io.inst_port
    core.io.dmem <> memarb.io.data_port

    //Debug Module
    dm.io.dmi <> io.dmi
    core.io.dcpath <> dm.io.dcpath
    core.io.ddpath <> dm.io.ddpath
    //amem.io.dm_port <> dm.io.ddmem
    memarb.io.dm_port <> dm.io.ddmem

    //External memory
    io.ext_mem <> memarb.io.ext_mem

    //Keep core in reset state before push all operations to memory
    //Ref: https://github.com/ucb-bar/riscv-sodor/blob/master/src/rv32_1stage/tile.scala

    val dmi_rst = dm.io.rstcore
    core.reset := dmi_rst | reset.toBool

}