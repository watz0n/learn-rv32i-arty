//=======================================================================
// RISCV, A Simple As Possible Core
// Watson Huang
// Jan 24, 2018
// 
// Memory Arbiter, for 1 write/read port memory
// Change Log:
//  02/05, 2018: Move memory out of core as external memory
//=======================================================================
package rvcommon

import chisel3._
import chisel3.util._
//import chisel3.experimental._ //For BlockBox Parameter

//Ref: https://github.com/freechipsproject/chisel3/wiki/Memories
//Ref: https://github.com/ucb-bar/riscv-sodor/blob/master/src/common/memory.scala

/*
//Use Magic RAM definitions to reduce refactor labor
trait mram_op {

    val MF_X = UInt(0,1)
    val MF_RD = UInt(0,1)
    val MF_WR = UInt(1,1)

    val MT_X = UInt(3,2)
    val MT_B = UInt(1,2)
    val MT_H = UInt(2,2)
    val MT_W = UInt(3,2)
}

trait mram_def {
    val mram_io_width = 32
    val mram_base_width = 8
    //val mram_size = 8192 //In slots, currently each slot is 32-bit(Word)
    val mram_size = 0x10000 //For qsort.riscv or rsort.riscv large memory test
}

object mram_op extends mram_op
object mram_def extends mram_def

class mram_req(data_width: Int) extends Bundle {
    val addr = Output(UInt(rvspec.xlen.W))
    val data = Output(UInt(data_width.W))
    //Use pre-defined data width
    //Ref: https://github.com/ucb-bar/riscv-sodor/blob/master/src/common/memory.scala
    val mfunc = Output(UInt(mram_op.MF_X.getWidth.W)) 
    val mtype = Output(UInt(mram_op.MT_X.getWidth.W))
    val valid = Output(Bool())
    val ready = Input(Bool())

    //Solve cloneType Error!?
    //Ref: https://github.com/ucb-bar/riscv-sodor/blob/master/src/common/memory.scala
    override def cloneType = { new mram_req(data_width).asInstanceOf[this.type] }
}

class mram_resp(data_width: Int) extends Bundle {
    val data = Output(UInt(data_width.W))
    val valid = Output(Bool())
    
    //Solve cloneType Error!?
    //Ref: https://github.com/ucb-bar/riscv-sodor/blob/master/src/common/memory.scala
    override def cloneType = { new mram_resp(data_width).asInstanceOf[this.type] }
}

class mram_io(data_width: Int) extends Bundle {
    val req = new mram_req(data_width)
    val resp = Flipped(new mram_resp(data_width))
    
    //Solve cloneType Error!?
    //Ref: https://github.com/ucb-bar/riscv-sodor/blob/master/src/common/memory.scala
    override def cloneType = { new mram_io(data_width).asInstanceOf[this.type] }
}
*/

trait arb_stat {
    val NOP = UInt(0, 2) 
    val DM = UInt(1, 2) //dm_port
    val IP = UInt(2, 2) //inst_port
    val DP = UInt(3, 2) //data_port
}

object arb_stat extends arb_stat

/*
class rvmemspv_io extends Bundle { //RV MEMory Single Port Verilog
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
*/

class rvextmemif_io extends Bundle { //RV EXTernal MEMory InterFace

    val waen = Input(Bool())
    val wden = Input(Bool())
    val waddr = Input(UInt(32.W))
    val wdata = Input(UInt(32.W))
    val wmask = Input(UInt(4.W))
    val wardy = Output(Bool())
    val wdrdy = Output(Bool())
    val wbvld = Output(Bool())
    val raen = Input(Bool())
    val rden = Input(Bool())
    val raddr = Input(UInt(32.W))
    val rdata = Output(UInt(32.W))
    val rardy = Output(Bool())
    val rdrdy = Output(Bool())
    
    //Line 119 @ https://github.com/freechipsproject/chisel3/blob/master/chiselFrontend/src/main/scala/chisel3/core/BlackBox.scala
    val clock = Input(Clock())
    val reset = Input(Bool())
}

/*
//Move to external memory design

//Use Verilog source to simulate memory
//Reference: https://github.com/freechipsproject/chisel3/wiki/BlackBoxes#blackboxes-with-verilog-in-a-resource-file
//Instantiation Parameterization
//Ref: https://github.com/freechipsproject/chisel3/wiki/BlackBoxes#parameterization
class rvmemspv extends BlackBox(Map(
        //require "import chisel3.experimental._" , or generate Param error 
        "MEM_SIZE" -> 0x40000,
        "READ_DELAY" -> 2
    )) with HasBlackBoxResource {

    val io = IO(new rvmemspv_io())
    setResource("/rvmemspv.v")
}
*/

/*
//For FPGA code generating
class rvmemspv extends BlackBox {
    val io = IO(new rvmemspv_io())
}
*/

class rvmemarb extends Module {

    val mem_unit = 8 //8bit
    val mask_size = rvspec.xlen/mem_unit
    val mword_hi = log2Up(mask_size)-1 //Memory Word High Bit
    val mword_lo = 0

    val io = IO(new Bundle {
        val inst_port = Flipped(new mram_io(rvspec.xlen))
        val data_port = Flipped(new mram_io(rvspec.xlen))
        val dm_port = Flipped(new mram_io(rvspec.xlen))
        val ext_mem = Flipped(new rvextmemif_io())
    })

    io <> DontCare

    val reg_stat = Reg(UInt(arb_stat.NOP.getWidth.W))

    val reg_wabusy = Reg(Bool())
    val reg_wdbusy = Reg(Bool())
    val reg_rabusy = Reg(Bool())
    val reg_rdbusy = Reg(Bool())

    val waen = Wire(Bool())
    val wden = Wire(Bool())
    val waddr = Wire(UInt(32.W))
    val wdata = Wire(UInt(32.W))
    val wmask = Wire(UInt(4.W)) // 32/8
    val wardy = Wire(Bool())
    val wdrdy = Wire(Bool())
    val wbvld = Wire(Bool())
    val raen = Wire(Bool())
    val rden = Wire(Bool())
    val raddr = Wire(UInt(32.W))
    val rdata = Wire(UInt(32.W))
    val rardy = Wire(Bool())
    val rdrdy = Wire(Bool())

    val reg_dmdata = Reg(UInt(32.W))
    val reg_dmvld = Reg(Bool())
    //val reg_dmrdy = Reg(Bool())
    val reg_ipdata = Reg(UInt(32.W))
    val reg_ipvld = Reg(Bool())
    //val reg_iprdy = Reg(Bool())
    val reg_dpdata = Reg(UInt(32.W))
    val reg_dpvld = Reg(Bool())
    //val reg_dprdy = Reg(Bool())

    //wen := false.B
    waen := false.B
    wden := false.B
    waddr := 0.U
    wdata := 0.U
    wmask := 0.U
    //ren := false.B
    raen := false.B
    rden := false.B
    raddr := 0.U

    io.inst_port.req.ready := false.B
    io.data_port.req.ready := false.B
    io.dm_port.req.ready := false.B

    io.inst_port.resp.valid := reg_ipvld
    io.data_port.resp.valid := reg_dpvld
    io.dm_port.resp.valid := reg_dmvld

    reg_ipvld := false.B
    reg_dpvld := false.B
    reg_dmvld := false.B

    io.inst_port.resp.data := reg_ipdata
    io.data_port.resp.data := reg_dpdata
    io.dm_port.resp.data := reg_dmdata

    switch(reg_stat) {
        is(arb_stat.NOP) {
            when(io.dm_port.req.valid) {
                val port = io.dm_port
                val resp_vld = reg_dmvld
                val resp_data = reg_dmdata
                switch(port.req.mfunc) {
                    is(mram_op.MF_WR) {
                        
                        val data = port.req.data
                        val off = port.req.addr(mword_hi, mword_lo)
                        val mt = port.req.mtype
                        
                        waddr := port.req.addr
                        
                        port.req.ready := false.B
                        when(reg_wabusy) {
                            waen := false.B
                            wden := false.B
                            when(reg_wdbusy) {
                                when(wbvld) {
                                    reg_wabusy := false.B
                                    reg_wdbusy := false.B
                                    port.req.ready := true.B
                                }
                            }
                            .otherwise {
                                //waen := false.B
                                wden := true.B
                                when(wden&wdrdy) {
                                    reg_wdbusy := true.B
                                }
                            }
                        }
                        .otherwise {
                            waen := true.B
                            wden := false.B

                            when(waen&wardy) {
                                //waen := false.B
                                reg_wabusy := true.B
                            }
                        }
                        
                        switch(mt) {
                            is(mram_op.MT_B) {
                                val dv = Vec(
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(1)-1, 8*(0)))

                                val dms = MuxLookup(
                                    off, 
                                    UInt(0x0,mask_size),
                                    Array(
                                        UInt(0,2) -> UInt(0x1,mask_size),
                                        UInt(1,2) -> UInt(0x2,mask_size),
                                        UInt(2,2) -> UInt(0x4,mask_size),
                                        UInt(3,2) -> UInt(0x8,mask_size)
                                    )
                                )

                                wdata := dv.asUInt
                                wmask := dms
                            }
                            is(mram_op.MT_H) {

                                val dv = Vec(
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(2)-1, 8*(1)),
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(2)-1, 8*(1)))

                                val dms = MuxLookup(
                                    off(1), 
                                    UInt(0x0,mask_size),
                                    Array(
                                        UInt(0,1) -> UInt(0x3,mask_size),
                                        UInt(1,1) -> UInt(0xC,mask_size)
                                    )
                                )

                                wdata := dv.asUInt
                                wmask := dms
                            }
                            is(mram_op.MT_W) {
                                
                                val dv = Vec(
                                    data(8*((0)+1)-1, 8*(0)),
                                    data(8*((1)+1)-1, 8*(1)),
                                    data(8*((2)+1)-1, 8*(2)),
                                    data(8*((3)+1)-1, 8*(3)))
                                
                                val dms = UInt(0xF, mask_size)

                                wdata := dv.asUInt
                                wmask := dms
                            }
                        }

                        //For quick test, replace with 
                        //wmask := UInt(0xF, 4)
                        //wdata := port.req.data //32bit

                    }
                    is(mram_op.MF_RD) {
                        raddr := port.req.addr
                        raen := true.B
                        rden := false.B
                        when(raen&rardy) {
                            //raen := false.B
                            reg_rabusy := true.B
                        }
                    }
                }
                reg_stat := arb_stat.DM
            }
            .elsewhen(io.inst_port.req.valid) {
                val port = io.inst_port
                val resp_vld = reg_ipvld
                val resp_data = reg_ipdata
                switch(port.req.mfunc) {
                    //inst_port only use 32-bit read operation
                    is(mram_op.MF_RD) {
                        raddr := port.req.addr
                        raen := true.B
                        rden := false.B
                        when(raen&rardy) {
                            //raen := false.B
                            reg_rabusy := true.B
                        }
                    }
                }
                reg_stat := arb_stat.IP
            }
        }
        is(arb_stat.DM) {
            when(io.dm_port.req.valid) {
                io.dm_port.req.ready := true.B
                val port = io.dm_port
                val resp_vld = reg_dmvld
                val resp_data = reg_dmdata
                switch(port.req.mfunc) {
                    is(mram_op.MF_WR) {

                        val data = port.req.data
                        val off = port.req.addr(mword_hi, mword_lo)
                        val mt = port.req.mtype

                        waddr := port.req.addr

                        port.req.ready := false.B
                        when(reg_wabusy) {
                            waen := false.B
                            wden := false.B
                            when(reg_wdbusy) {
                                when(wbvld) {
                                    reg_wabusy := false.B
                                    reg_wdbusy := false.B
                                    port.req.ready := true.B
                                }
                            }
                            .otherwise {
                                //waen := false.B
                                wden := true.B
                                when(wden&wdrdy) {
                                    reg_wdbusy := true.B
                                }
                            }
                        }
                        .otherwise {
                            waen := true.B
                            wden := false.B

                            when(waen&wardy) {
                                //waen := false.B
                                reg_wabusy := true.B
                            }
                        }
                      
                        switch(mt) {
                            is(mram_op.MT_B) {
                                val dv = Vec(
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(1)-1, 8*(0)))

                                val dms = MuxLookup(
                                    off, 
                                    UInt(0x0,mask_size),
                                    Array(
                                        UInt(0,2) -> UInt(0x1,mask_size),
                                        UInt(1,2) -> UInt(0x2,mask_size),
                                        UInt(2,2) -> UInt(0x4,mask_size),
                                        UInt(3,2) -> UInt(0x8,mask_size)
                                    )
                                )

                                wdata := dv.asUInt
                                wmask := dms
                            }
                            is(mram_op.MT_H) {

                                val dv = Vec(
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(2)-1, 8*(1)),
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(2)-1, 8*(1)))

                                val dms = MuxLookup(
                                    off(1), 
                                    UInt(0x0,mask_size),
                                    Array(
                                        UInt(0,1) -> UInt(0x3,mask_size),
                                        UInt(1,1) -> UInt(0xC,mask_size)
                                    )
                                )

                                wdata := dv.asUInt
                                wmask := dms
                            }
                            is(mram_op.MT_W) {
                                
                                val dv = Vec(
                                    data(8*((0)+1)-1, 8*(0)),
                                    data(8*((1)+1)-1, 8*(1)),
                                    data(8*((2)+1)-1, 8*(2)),
                                    data(8*((3)+1)-1, 8*(3)))
                                
                                val dms = UInt(0xF, mask_size)

                                wdata := dv.asUInt
                                wmask := dms
                            }
                        }

                        //Quick test, replaced by memory type operation 
                        //wmask := UInt(0xF, 4)
                        //wdata := port.req.data //32bit
                    }
                    is(mram_op.MF_RD) {
                        
                        val off = port.req.addr(mword_hi, mword_lo)
                        val mt = port.req.mtype

                        raddr := port.req.addr
                        
                        when(reg_rabusy) {
                            raen := false.B
                            rden := false.B
                            when(reg_rdbusy) {
                                when(rdrdy) {
                                    reg_rabusy := false.B
                                    reg_rdbusy := false.B
                                    port.req.ready := true.B
                                }
                            }
                            .otherwise {
                                //raen := false.B
                                rden := true.B
                                reg_rdbusy := true.B
                                when(rdrdy) {
                                    reg_rabusy := false.B
                                    reg_rdbusy := false.B
                                    port.req.ready := true.B
                                }
                            } 
                        }
                        .otherwise {
                            raen := true.B
                            when(resp_vld) {
                                raen := false.B
                            }

                            rden := false.B
                            when(raen&rardy) {
                                //raen := false.B
                                reg_rabusy := true.B
                            }
                        }
                        when(rdrdy) {
                            //reg_rdbusy := false.B

                            switch(mt) {
                                is(mram_op.MT_B) {
                                    val data = MuxLookup(
                                        off, 
                                        UInt(0x0, rvspec.xlen),
                                        Array(
                                            UInt(0,2) -> Cat(Fill(24, UInt(0,1)), rdata(8*((0)+1)-1, 8*(0))),
                                            UInt(1,2) -> Cat(Fill(24, UInt(0,1)), rdata(8*((1)+1)-1, 8*(1))),
                                            UInt(2,2) -> Cat(Fill(24, UInt(0,1)), rdata(8*((2)+1)-1, 8*(2))),
                                            UInt(3,2) -> Cat(Fill(24, UInt(0,1)), rdata(8*((3)+1)-1, 8*(3)))
                                        )
                                    )
                                    resp_data := data.asUInt
                                    resp_vld := true.B
                                }
                                is(mram_op.MT_H) {
                                    val data = MuxLookup(
                                        off(1), 
                                        UInt(0x0, rvspec.xlen),
                                        Array(
                                            UInt(0,1) -> Cat(Fill(16, UInt(0,1)), rdata(8*((1)+1)-1, 8*(1)), rdata(8*((0)+1)-1, 8*(0))),
                                            UInt(1,1) -> Cat(Fill(16, UInt(0,1)), rdata(8*((3)+1)-1, 8*(3)), rdata(8*((2)+1)-1, 8*(2)))
                                        )
                                    )
                                    resp_data := data.asUInt
                                    resp_vld := true.B
                                }
                                is(mram_op.MT_W) {
                                    val data = rdata
                                    resp_data := data.asUInt
                                    resp_vld := true.B
                                }
                            }
                            
                            //Quick test, replaced by memory type operation 
                            //resp_vld := true.B
                            //resp_data := rdata
                        }
                        when(resp_vld) {
                            //ren := false.B
                            //port.req.ready := false.B
                            //reg_rdbusy := false.B

                            when(!io.dm_port.req.valid) {
                                when(io.inst_port.req.valid) {
                                    reg_stat := arb_stat.IP
                                }
                                .otherwise {
                                    reg_stat := arb_stat.NOP
                                }
                            }
                        }
                    }
                }
            }
            //when(!io.dm_port.req.valid) {
            .otherwise {
/*               
                when(wdrdy) {
                    reg_wabusy := false.B
                    reg_wdbusy := false.B
                }

                when(rdrdy) {
                    reg_rabusy := false.B
                    reg_rdbusy := false.B
                }
*/
                reg_wabusy := false.B
                reg_wdbusy := false.B

                when(io.inst_port.req.valid) {
                    reg_stat := arb_stat.IP
                }
                .otherwise {
                    reg_stat := arb_stat.NOP
                }
            }
        }
        is(arb_stat.IP) {
            when(io.inst_port.req.valid) {
                val port = io.inst_port
                val resp_vld = reg_ipvld
                val resp_data = reg_ipdata

                switch(port.req.mfunc) {
                    //inst_port only use 32-bit read operation
                    is(mram_op.MF_RD) {
                        raddr := port.req.addr

                        when(reg_rabusy) {
                            raen := false.B
                            rden := false.B
                            when(reg_rdbusy) {
                                when(rdrdy) {
                                    reg_rabusy := false.B
                                    reg_rdbusy := false.B
                                    port.req.ready := true.B
                                }
                            }
                            .otherwise {
                                //raen := false.B
                                rden := true.B
                                reg_rdbusy := true.B
                                when(rdrdy) {
                                    reg_rabusy := false.B
                                    reg_rdbusy := false.B
                                    port.req.ready := true.B
                                }
                            } 
                        }
                        .otherwise {
                            raen := true.B
                            when(resp_vld) {
                                raen := false.B
                            }
                            
                            rden := false.B
                            when(raen&rardy) {
                                //raen := false.B
                                reg_rabusy := true.B
                            }
                        }

                        when(rdrdy) {
                            //reg_rdbusy := false.B
                            resp_vld := true.B
                            resp_data := rdata //32bit
                        }

                        when(resp_vld) {
                            //ren := false.B
                            //port.req.ready := false.B
                            reg_rdbusy := false.B

                            when(io.data_port.req.valid) {
                                reg_stat := arb_stat.DP
                                reg_ipvld := true.B //Keep inst_port.resp.valid for RV32I delayed data_port operation
                            }
                            .elsewhen(io.dm_port.req.valid) {
                                reg_stat := arb_stat.DM
                            }
                            .elsewhen(!io.inst_port.req.valid) {
                                reg_stat := arb_stat.NOP
                            }
                        }
                    }
                }
            }
            .otherwise {
                reg_ipvld := false.B
                //reg_ipdata := 0.U
                reg_ipdata := rvspec.NOP
                reg_stat := arb_stat.NOP

/*
                when(rdrdy) {
                    reg_rabusy := false.B
                    reg_rdbusy := false.B
                }
*/
                reg_wabusy := false.B
                reg_wdbusy := false.B
            }
        }
        is(arb_stat.DP) {
            //Keep the same instruction
            reg_ipvld := true.B

            when(io.data_port.req.valid) {
                val port = io.data_port
                val resp_vld = reg_dpvld
                val resp_data = reg_dpdata
                switch(port.req.mfunc) {
                    is(mram_op.MF_WR) {
                        val data = port.req.data
                        val off = port.req.addr(mword_hi, mword_lo)
                        val mt = port.req.mtype

                        waddr := port.req.addr
                        
                        port.req.ready := false.B
                        when(reg_wabusy) {
                            waen := false.B
                            wden := false.B
                            when(reg_wdbusy) {
                                when(wbvld) {
                                    reg_wabusy := false.B
                                    reg_wdbusy := false.B
                                    port.req.ready := true.B
                                }
                            }
                            .otherwise {
                                //waen := false.B
                                wden := true.B
                                when(wden&wdrdy) {
                                    reg_wdbusy := true.B
                                }
                            }
                        }
                        .otherwise {
                            waen := true.B
                            wden := false.B

                            when(waen&wardy) {
                                //waen := false.B
                                reg_wabusy := true.B
                            }
                        }
                        
                        switch(mt) {
                            is(mram_op.MT_B) {
                                val dv = Vec(
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(1)-1, 8*(0)))

                                val dms = MuxLookup(
                                    off, 
                                    UInt(0x0,mask_size),
                                    Array(
                                        UInt(0,2) -> UInt(0x1,mask_size),
                                        UInt(1,2) -> UInt(0x2,mask_size),
                                        UInt(2,2) -> UInt(0x4,mask_size),
                                        UInt(3,2) -> UInt(0x8,mask_size)
                                    )
                                )

                                wdata := dv.asUInt
                                wmask := dms
                            }
                            is(mram_op.MT_H) {

                                val dv = Vec(
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(2)-1, 8*(1)),
                                    data(8*(1)-1, 8*(0)),
                                    data(8*(2)-1, 8*(1)))

                                val dms = MuxLookup(
                                    off(1), 
                                    UInt(0x0,mask_size),
                                    Array(
                                        UInt(0,1) -> UInt(0x3,mask_size),
                                        UInt(1,1) -> UInt(0xC,mask_size)
                                    )
                                )

                                wdata := dv.asUInt
                                wmask := dms
                            }
                            is(mram_op.MT_W) {
                                
                                val dv = Vec(
                                    data(8*((0)+1)-1, 8*(0)),
                                    data(8*((1)+1)-1, 8*(1)),
                                    data(8*((2)+1)-1, 8*(2)),
                                    data(8*((3)+1)-1, 8*(3)))
                                
                                val dms = UInt(0xF, mask_size)

                                wdata := dv.asUInt
                                wmask := dms
                            }
                        }

                        //Quick test, replaced by memory type operation 
                        //wmask := UInt(0xF, 4)
                        //wdata := port.req.data //32bit

                        //when(wdrdy) {
                        when(wbvld) {
                            reg_ipvld := false.B
                            reg_ipdata := rvspec.NOP
                            when(io.dm_port.req.valid) {
                                reg_stat := arb_stat.DM
                            }
                            .elsewhen(io.inst_port.req.valid) {
                                reg_stat := arb_stat.IP
                            }
                            .otherwise {
                                reg_stat := arb_stat.NOP
                            }
                        }
                    }
                    is(mram_op.MF_RD) {
                        val off = port.req.addr(mword_hi, mword_lo)
                        val mt = port.req.mtype

                        raddr := port.req.addr

                        when(reg_rabusy) {
                            raen := false.B
                            rden := false.B
                            when(reg_rdbusy) {
                                when(rdrdy) {
                                    reg_rabusy := false.B
                                    reg_rdbusy := false.B
                                    port.req.ready := true.B
                                }
                            }
                            .otherwise {
                                //raen := false.B
                                rden := true.B
                                reg_rdbusy := true.B
                                when(rdrdy) {
                                    reg_rabusy := false.B
                                    reg_rdbusy := false.B
                                    port.req.ready := true.B
                                }
                            } 
                        }
                        .otherwise {
                            raen := true.B
                            when(resp_vld) {
                                raen := false.B
                            }
                            
                            rden := false.B
                            when(raen&rardy) {
                                //raen := false.B
                                reg_rabusy := true.B
                            }
                        }
                        
                        when(rdrdy) {
                            //reg_rdbusy := false.B
                            
                            switch(mt) {
                                is(mram_op.MT_B) {
                                    val data = MuxLookup(
                                        off, 
                                        UInt(0x0, rvspec.xlen),
                                        Array(
                                            UInt(0,2) -> Cat(Fill(24, UInt(0,1)), rdata(8*((0)+1)-1, 8*(0))),
                                            UInt(1,2) -> Cat(Fill(24, UInt(0,1)), rdata(8*((1)+1)-1, 8*(1))),
                                            UInt(2,2) -> Cat(Fill(24, UInt(0,1)), rdata(8*((2)+1)-1, 8*(2))),
                                            UInt(3,2) -> Cat(Fill(24, UInt(0,1)), rdata(8*((3)+1)-1, 8*(3)))
                                        )
                                    )
                                    resp_data := data.asUInt
                                    resp_vld := true.B
                                }
                                is(mram_op.MT_H) {
                                    val data = MuxLookup(
                                        off(1), 
                                        UInt(0x0, rvspec.xlen),
                                        Array(
                                            UInt(0,1) -> Cat(Fill(16, UInt(0,1)), rdata(8*((1)+1)-1, 8*(1)), rdata(8*((0)+1)-1, 8*(0))),
                                            UInt(1,1) -> Cat(Fill(16, UInt(0,1)), rdata(8*((3)+1)-1, 8*(3)), rdata(8*((2)+1)-1, 8*(2)))
                                        )
                                    )
                                    resp_data := data.asUInt
                                    resp_vld := true.B
                                }
                                is(mram_op.MT_W) {
                                    val data = rdata
                                    resp_data := data.asUInt
                                    resp_vld := true.B
                                }
                            }
                            
                            //Quick test, replaced by memory type operation 
                            //resp_vld := true.B
                            //resp_data := rdata
                        }

                        when(resp_vld) {
                            //ren := false.B
                            //port.req.ready := false.B
                            reg_rdbusy := false.B

                            reg_ipvld := false.B
                            reg_ipdata := rvspec.NOP

                            when(io.dm_port.req.valid) {
                                reg_stat := arb_stat.DM
                            }
                            .elsewhen(io.inst_port.req.valid) {
                                reg_stat := arb_stat.IP
                            }
                            .otherwise {
                                reg_stat := arb_stat.NOP
                            }
                            
                        }
                    }
                }
            }
            .otherwise {
                reg_ipvld := false.B
                reg_ipdata := 0.U
                reg_stat := arb_stat.NOP
/*
                when(rdrdy) {
                    reg_rabusy := false.B
                    reg_rdbusy := false.B
                }
*/
                reg_wabusy := false.B
                reg_wdbusy := false.B
            }
        }
    }

    //Single Port Memory, from External 
    io.ext_mem.waen := waen
    io.ext_mem.wden := wden
    io.ext_mem.waddr := waddr
    io.ext_mem.wdata := wdata
    io.ext_mem.wmask := wmask
    wardy := io.ext_mem.wardy
    wdrdy := io.ext_mem.wdrdy
    wbvld := io.ext_mem.wbvld
    io.ext_mem.raen := raen
    io.ext_mem.rden := rden
    io.ext_mem.raddr := raddr
    rdata := io.ext_mem.rdata
    rardy := io.ext_mem.rardy
    rdrdy := io.ext_mem.rdrdy
    //For verilog simulation
    io.ext_mem.clock := clock
    io.ext_mem.reset := reset

/*
    //Single Port Memory, Embedded
    //val rvmemsp = Module(new rvmemsp) //Scala code
    val rvmemsp = Module(new rvmemspv) //Verilog code
    rvmemsp.io.wen := wen
    rvmemsp.io.waddr := waddr
    rvmemsp.io.wdata := wdata
    rvmemsp.io.wmask := wmask
    wrdy := rvmemsp.io.wrdy
    rvmemsp.io.ren := ren
    rvmemsp.io.raddr := raddr
    rdata := rvmemsp.io.rdata
    rvld := rvmemsp.io.rvld
    rrdy := rvmemsp.io.rrdy

    //For verilog simulation
    rvmemsp.io.clock := clock
    rvmemsp.io.reset := reset
*/

    when(reset.toBool()) {
        
        reg_stat := arb_stat.NOP
        //reg_wrbusy := false.B
        //reg_rdbusy := false.B

        reg_wabusy := false.B
        reg_wdbusy := false.B
        reg_rabusy := false.B
        reg_wdbusy := false.B

        //wen := false.B
        //ren := false.B
        waen := false.B
        wden := false.B
        raen := false.B
        rden := false.B

        io.inst_port.req.ready := false.B
        io.data_port.req.ready := false.B
        io.dm_port.req.ready := false.B

        io.inst_port.resp.valid := false.B
        io.data_port.resp.valid := false.B
        io.dm_port.resp.valid := false.B

        reg_dmdata := 0.U
        reg_dmvld := false.B
        reg_ipdata := 0.U
        reg_ipvld := false.B
        reg_dpdata := 0.U
        reg_dpvld := false.B

    }
}
