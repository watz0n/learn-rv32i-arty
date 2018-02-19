//=======================================================================
// RISCV, A Simple As Possible Core
// Watson Huang
// Jan 25, 2018
// 
// RV DMI Unit-Test
// Control core by DMI simulator in Scala/Chisel code
//=======================================================================
package rvdmisim

import chisel3._
import chisel3.util._
import chisel3.iotesters._
import org.scalatest._              
import org.scalatest.exceptions._
import chisel3.experimental._ //For BlockBox Parameter

import rvtile._
import rvcommon._

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

class rvsimtop extends Module {
    val io = IO(new Bundle{
        val dmi = Flipped(new dmi_io())
    })
    val rvtile = Module(new rvtile)
    val ext_mem = Module(new rvmemspv)
    rvtile.io.dmi <> io.dmi
    ext_mem.io <> rvtile.io.ext_mem
}

class RVDMIPeekPokeTester(dut: rvsimtop, instlist: List[(UInt, UInt)], target: (UInt, UInt, Int)) extends PeekPokeTester(dut)  {

    //Initialize, delay 1T
    poke(dut.io.dmi.req.bits.op, dmi_reqop.X)
    poke(dut.io.dmi.req.bits.addr, 0x00)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    for (inst <- instlist) {
        val (iaddr:UInt, idata:UInt) = inst

        poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
        poke(dut.io.dmi.req.bits.addr, dm_addr.sbaddress0)
        poke(dut.io.dmi.req.bits.data, iaddr)
        poke(dut.io.dmi.req.valid, 1)
        step(1)
        while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
        poke(dut.io.dmi.req.valid, 0)
        step(1)

        poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
        poke(dut.io.dmi.req.bits.addr, dm_addr.sbdata0)
        poke(dut.io.dmi.req.bits.data, idata)
        poke(dut.io.dmi.req.valid, 1)
        step(1)
        while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
        poke(dut.io.dmi.req.valid, 0)
        step(1)
    }


    poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
    poke(dut.io.dmi.req.bits.addr, 0x44)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    poke(dut.io.dmi.req.bits.addr, 0x00)
    poke(dut.io.dmi.req.bits.data, 0x00)

    val (taddr:UInt, tdata:UInt, tcount:Int) = target
    var i = 0 //Loop variable
  
    for( i <- 1 to tcount) {
        poke(dut.io.dmi.req.valid, 0)
        step(1)
    }

    //Read MEM[sbaddress0] to sbdata0
    poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
    poke(dut.io.dmi.req.bits.addr, dm_addr.sbaddress0)
    poke(dut.io.dmi.req.bits.data, taddr)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    //Read data to dmi interface
    poke(dut.io.dmi.req.bits.op, dmi_reqop.read)
    poke(dut.io.dmi.req.bits.addr, dm_addr.sbdata0)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
    
    //expect(dut.io.dmi.resp.valid, 1)
    expect(dut.io.dmi.resp.bits.data, tdata)

    poke(dut.io.dmi.req.valid, 0)
    step(1)
    
    poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
    poke(dut.io.dmi.req.bits.addr, 0x48)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    poke(dut.io.dmi.req.bits.op, dmi_reqop.X)
    poke(dut.io.dmi.req.bits.addr, 0x00)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 0)
    step(1)

}

class RVDMIWritePeekPokeTester(dut: rvsimtop, instlist: List[(UInt, UInt)], target: (UInt, UInt, Int)) extends PeekPokeTester(dut)  {

    //Initialize, delay 1T
    poke(dut.io.dmi.req.bits.op, dmi_reqop.X)
    poke(dut.io.dmi.req.bits.addr, 0x00)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    for (inst <- instlist) {
        val (iaddr:UInt, idata:UInt) = inst

        poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
        poke(dut.io.dmi.req.bits.addr, dm_addr.sbaddress0)
        poke(dut.io.dmi.req.bits.data, iaddr)
        poke(dut.io.dmi.req.valid, 1)
        step(1)
        while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
        poke(dut.io.dmi.req.valid, 0)
        step(1)

        poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
        poke(dut.io.dmi.req.bits.addr, dm_addr.sbdata0)
        poke(dut.io.dmi.req.bits.data, idata)
        poke(dut.io.dmi.req.valid, 1)
        step(1)
        while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
        poke(dut.io.dmi.req.valid, 0)
        step(1)
    }

    poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
    poke(dut.io.dmi.req.bits.addr, 0x44)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    poke(dut.io.dmi.req.bits.addr, 0x00)
    poke(dut.io.dmi.req.bits.data, 0x00)

    val (taddr:UInt, tdata:UInt, tcount:Int) = target
    var i = 0 //Loop variable

    //for( i <- 1 to tcount) {
    //    poke(dut.io.dmi.req.valid, 0)
    //    step(1)
    //}

    i = 0
    while( i < 50 ) {
        poke(dut.io.dmi.req.bits.op, dmi_reqop.X)
        poke(dut.io.dmi.req.bits.addr, 0x00)
        poke(dut.io.dmi.req.bits.data, 0x00)
        poke(dut.io.dmi.req.valid, 0)
        step(1)
        i = i+1
    }

    //Read MEM[sbaddress0] to sbdata0
    poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
    poke(dut.io.dmi.req.bits.addr, dm_addr.sbaddress0)
    poke(dut.io.dmi.req.bits.data, taddr)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    //Read data to dmi interface
    poke(dut.io.dmi.req.bits.op, dmi_reqop.read)
    poke(dut.io.dmi.req.bits.addr, dm_addr.sbdata0)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }

    expect(dut.io.dmi.resp.bits.data, tdata)
    println("RESP.BITS.DATA:0x%X".format(peek(dut.io.dmi.resp.bits.data)))

    poke(dut.io.dmi.req.valid, 0)
    step(1)

    poke(dut.io.dmi.req.bits.op, dmi_reqop.X)
    poke(dut.io.dmi.req.bits.addr, 0x00)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    i = 0
    while( i < tcount) {
        val iaddr = "h80002000".U
        poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
        poke(dut.io.dmi.req.bits.addr, dm_addr.sbaddress0)
        poke(dut.io.dmi.req.bits.data, iaddr)
        poke(dut.io.dmi.req.valid, 1)
        step(1)
        while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
        poke(dut.io.dmi.req.valid, 0)
        step(1)
        i = i+1

        val idata = "h87654321".U
        poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
        poke(dut.io.dmi.req.bits.addr, dm_addr.sbdata0)
        poke(dut.io.dmi.req.bits.data, idata )
        poke(dut.io.dmi.req.valid, 1)
        step(1)
        while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
        poke(dut.io.dmi.req.valid, 0)
        step(1)
        i = i+1
    }

    i = 0
    while( i < 1) {
        val iaddr = "h80001000".U
        poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
        poke(dut.io.dmi.req.bits.addr, dm_addr.sbaddress0)
        poke(dut.io.dmi.req.bits.data, iaddr)
        poke(dut.io.dmi.req.valid, 1)
        step(1)
        while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
        poke(dut.io.dmi.req.valid, 0)
        step(1)
        i = i+1

        val idata = "h12345678".U
        poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
        poke(dut.io.dmi.req.bits.addr, dm_addr.sbdata0)
        poke(dut.io.dmi.req.bits.data, idata )
        poke(dut.io.dmi.req.valid, 1)
        step(1)
        while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
        poke(dut.io.dmi.req.valid, 0)
        step(1)
        i = i+1
    }

    i = 0
    while( i < 50 ) {
        poke(dut.io.dmi.req.bits.op, dmi_reqop.X)
        poke(dut.io.dmi.req.bits.addr, 0x00)
        poke(dut.io.dmi.req.bits.data, 0x00)
        poke(dut.io.dmi.req.valid, 0)
        step(1)
        i = i+1
    }

    //Read MEM[sbaddress0] to sbdata0
    poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
    poke(dut.io.dmi.req.bits.addr, dm_addr.sbaddress0)
    poke(dut.io.dmi.req.bits.data, taddr)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    //Read data to dmi interface
    poke(dut.io.dmi.req.bits.op, dmi_reqop.read)
    poke(dut.io.dmi.req.bits.addr, dm_addr.sbdata0)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
    
    expect(dut.io.dmi.resp.bits.data, "h12345678".U)
    println("RESP.BITS.DATA:0x%X".format(peek(dut.io.dmi.resp.bits.data)))
    
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    poke(dut.io.dmi.req.bits.op, dmi_reqop.write)
    poke(dut.io.dmi.req.bits.addr, 0x48)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 1)
    step(1)
    while(peek(dut.io.dmi.resp.valid) == BigInt(0)) { step(1) }
    poke(dut.io.dmi.req.valid, 0)
    step(1)

    poke(dut.io.dmi.req.bits.op, dmi_reqop.X)
    poke(dut.io.dmi.req.bits.addr, 0x00)
    poke(dut.io.dmi.req.bits.data, 0x00)
    poke(dut.io.dmi.req.valid, 0)
    step(1)
    
}

class RVDMIPeekPokeSpec extends ChiselFlatSpec with Matchers {
  
    it should "Test1: RV Tile should be elaborate normally" in {
        elaborate { 
            new rvsimtop
        }
        info("elaborate rvsimtop done")
    }

    it should "Test2: RV DMI Tester return the correct result" in {
        val manager = new TesterOptionsManager {
            testerOptions = testerOptions.copy(backendName = "verilator")
        }

        val rvdmi_inst = List(
            ("h80000000".U, "h800010B7".U), // LUI x1, 0x80001
            ("h80000004".U, "h0000A103".U), // LW x2, x1, 0
            ("h80000008".U, "h00110193".U), // ADDI x3, x2, 1
            ("h8000000C".U, "h0030A023".U), // SW x3, x1, 0
            ("h80000010".U, "h00000033".U), // ADD x0, x0, x0, replace NOP for distinguish pending instruction
            ("h80000014".U, "hFE000EE3".U), // Branch to previous address, here is 0x80000014-4

            ("h80001000".U, "h87654320".U)
        )

        //val rvdmi_target = ("h80001000".U, "h87654321".U, rvdmi_inst.length)

        val rvdmi_target = ("h80001000".U, "h87654321".U, 100)

        info("Expect MEM[0x%08X]:0x%08X".format(rvdmi_target._1.litValue(), rvdmi_target._2.litValue()))

        try {
            chisel3.iotesters.Driver.execute(() => new rvsimtop, manager) {
                dut => new RVDMIPeekPokeTester(dut, rvdmi_inst, rvdmi_target)
            } should be (true)
        } catch {
            case tfe: TestFailedException => {
                info("Failed dmi unit-test")
                throw tfe
            }
        }
        info("Passed dmi unit-test")
    }
/*
    it should "Test3: RV DMI Continue Write return the correct result" in {
        val manager = new TesterOptionsManager {
            testerOptions = testerOptions.copy(backendName = "verilator")
        }

        val rvdmi_inst = List(
            ("h80000000".U, "h800010B7".U), // LUI x1, 0x80001
            ("h80000004".U, "h0000A103".U), // LW x2, x1, 0
            ("h80000008".U, "h00110193".U), // ADDI x3, x2, 1
            ("h8000000C".U, "h0030A023".U), // SW x3, x1, 0
            ("h80000010".U, "h0000A103".U), // LW x2, x1, 0 //Test DMI write when Core read memory
            ("h80000014".U, "h0000A203".U), // LW x4, x1, 0 //Test DMI write when Core read memory
            ("h80000018".U, "hFE000DE3".U), // Branch to previous address, here is 0x80000018-8

            ("h80001000".U, "h87654320".U)
        )

        //val rvdmi_target = ("h80001000".U, "h87654321".U, rvdmi_inst.length)

        val rvdmi_target = ("h80001000".U, "h87654321".U, 100)

        info("Expect MEM[0x%08X]:0x%08X".format(rvdmi_target._1.litValue(), rvdmi_target._2.litValue()))

        try {
            chisel3.iotesters.Driver.execute(() => new rvsimtop, manager) {
                dut => new RVDMIWritePeekPokeTester(dut, rvdmi_inst, rvdmi_target)
            } should be (true)
        } catch {
            case tfe: TestFailedException => {
                info("Failed dmi unit-test")
                throw tfe
            }
        }
        info("Passed dmi unit-test")
    }
*/
}