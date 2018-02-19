`timescale 1ns / 1ps

/* //
//      JTAG Debug Module InterFace (JTAG DMI) 
//      Author: Watson Huang
//      Module Description:
//          Combine JTAG DR-SHIFT handler and crossing domain module for cleaning instantiation
//      Change Log:
//      02/13, JTAG DMI interface function work
*/ //

module jtag_dmi_if#( //JTAG to system InterFace
    parameter JTAG_CHAIN = 4, //Use USER4
    parameter DMI_ADDR_WIDTH = 7,
    parameter DMI_DATA_WIDTH = 32,
    parameter DMI_OP_WIDTH = 2,
    parameter JTAG_DATA_WIDTH = (DMI_ADDR_WIDTH+DMI_DATA_WIDTH+DMI_OP_WIDTH),
    parameter TX_WIDTH = (DMI_ADDR_WIDTH+DMI_DATA_WIDTH+DMI_OP_WIDTH),
    parameter RX_WIDTH = (DMI_DATA_WIDTH+DMI_OP_WIDTH)
)(

    //Core Interface
    output creq_vld,
    output [TX_WIDTH-1:0] creq_data,
    input creq_rdy,
    input cresp_vld,
    input [RX_WIDTH-1:0] cresp_data,
    output cresp_rdy,

    input reset,
    input clock
);

wire jreq_vld;
wire [TX_WIDTH-1:0] jreq_data;
wire jreq_rdy;
wire jresp_vld;
wire [RX_WIDTH-1:0] jresp_data;
wire jresp_rdy;

//wire creq_vld;
//wire [TX_WIDTH-1:0] creq_data;
//wire creq_rdy;
//wire cresp_vld;
//wire [RX_WIDTH-1:0] cresp_data;
//wire cresp_rdy;

//JTAG D-SHIFT interface
wire jcapture;
wire jreset;
wire jshift;
wire jupdate;
wire jtdo;
wire jtdi;
wire jtms;
wire jsel; 

//Xilinx BSCANE2 interface
wire xcapture;
wire xreset;
wire xshift;
wire xupdate;
wire xsel;
wire xtdo;
wire xtdi;
wire xtck;
wire xtms;

BSCANE2 #(
    .JTAG_CHAIN(JTAG_CHAIN) // Value for USER command.
)
bse2_inst (
    .CAPTURE(xcapture), // 1-bit output: CAPTURE output from TAP controller.
    .DRCK(), // 1-bit output: Gated TCK output. When SEL is asserted, DRCK toggles when CAPTURE or SHIFT are asserted.
    .RESET(xreset), // 1-bit output: Reset output for TAP controller.
    .RUNTEST(), // 1-bit output: Output asserted when TAP controller is in Run Test/Idle state.
    .SEL(xsel), // 1-bit output: USER instruction active output.
    .SHIFT(xshift), // 1-bit output: SHIFT output from TAP controller.
    .TCK(xtck), // 1-bit output: Test Clock output. Fabric connection to TAP Clock pin.
    .TDI(xtdi), // 1-bit output: Test Data Input (TDI) output from TAP controller.
    .TMS(xtms), // 1-bit output: Test Mode Select output. Fabric connection to TAP.
    .UPDATE(xupdate), // 1-bit output: UPDATE output from TAP controller
    .TDO(xtdo) // 1-bit input: Test Data Output (TDO) input for USER function.
);

assign jcapture = xcapture;
assign jreset = xreset;
assign jshift = xshift;
assign jupdate = xupdate;
assign xtdo = jtdo;
assign jtdi = xtdi;
assign jtms = xtms;
assign jsel = xsel;

jtag_dmi_dsif jtag_dmi_dsif(
    //.jclk(jclk), //JTAG Sim Clock
    .jclk(xtck), //JTAG Clock
    
    //JTAG D-SHIFT interface
    .jcapture(jcapture),
    .jreset(jreset),
    .jshift(jshift),
    .jupdate(jupdate),
    .jtdo(jtdo),
    .jtdi(jtdi),
    .jtms(jtms),
    .jsel(jsel),
    
    //JTAG to DMI Interface
    .jreq_vld(jreq_vld),
    .jreq_data(jreq_data),
    .jreq_rdy(jreq_rdy),
    .jresp_vld(jresp_vld),
    .jresp_data(jresp_data),
    .jresp_rdy(jresp_rdy),
    
    .dev_rst(reset)
);

jtag_dmi_intc jtag_dmi_intc (
    //JTAG interface
    //.jclk(jclk), //JTAG Sim Clock
    .jclk(xtck), //JTAG Clock
    .jreq_vld(jreq_vld),
    .jreq_data(jreq_data),
    .jreq_rdy(jreq_rdy),
    .jresp_vld(jresp_vld),
    .jresp_data(jresp_data),
    .jresp_rdy(jresp_rdy),

    //Core Interface
    .cclk(clock), //Core Clock
    .creq_vld(creq_vld),
    .creq_data(creq_data),
    .creq_rdy(creq_rdy),
    .cresp_vld(cresp_vld),
    .cresp_data(cresp_data),
    .cresp_rdy(cresp_rdy),
    
    .dev_rst(reset)
);

endmodule