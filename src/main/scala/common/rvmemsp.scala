//=======================================================================
// RISCV, A Simple As Possible Core
// Watson Huang
// Jan 29, 2018
// 
// Single Port Memory for Behavior Simulation
//=======================================================================
package rvcommon

import chisel3._
import chisel3.util._

class rvmemsp_io extends Bundle {
    val wen = Input(Bool())
    val waddr = Input(UInt(32.W))
    val wdata = Input(UInt(32.W))
    val wmask = Input(UInt(4.W))
    val wrdy = Output(Bool())
    val ren = Input(Bool())
    val raddr = Input(UInt(32.W))
    val rdata = Output(UInt(32.W))
    val rvld = Output(Bool())
    val rrdy = Output(Bool())
}

class rvmemsp extends Module {
    val io = IO(new rvmemsp_io())
    io <> DontCare

    val mem_size = 0x40000 //in bytes

    val mem = Mem(mem_size>>2, Vec(4, UInt(8.W)))

    val reg_rdata = Reg(UInt(32.W))
    val reg_rvld = Reg(Bool())

    val addr_lo = log2Up(32/8)
    val addr_hi = log2Up(mem_size) + addr_lo - 1
    //println("addr_hi:%d, addr_lo:%d".format(addr_hi, addr_lo))

    io.wrdy := true.B
    io.rrdy := true.B

    when(io.wen) {
        val addr = io.waddr(addr_hi, addr_lo)
        val dv = Vec(   io.wdata(8*1-1,8*0), 
                        io.wdata(8*2-1,8*1), 
                        io.wdata(8*3-1,8*2), 
                        io.wdata(8*4-1,8*3))
        val dms = io.wmask
        val dm = dms.toBools
        mem.write(addr, dv, dm)
    }

    //io.rdata := 0.U
    //io.rvld := false.B

    io.rdata := reg_rdata
    io.rvld := reg_rvld

    reg_rvld := false.B

    when(io.ren) {
        val addr = io.raddr(addr_hi, addr_lo)
        val dv = Wire(Vec(4, UInt(8.W)))
        dv := mem.read(addr)
        val data = dv
        //io.rdata := data.asUInt
        //io.rvld := true.B
        reg_rdata := data.asUInt
        reg_rvld := true.B
    }

    when(reset.toBool()) {
        io.wrdy := false.B
        io.rrdy := false.B
        //io.rdata := 0.U
        //io.rvld := false.B
        reg_rdata := 0.U
        reg_rvld := false.B
    }
}