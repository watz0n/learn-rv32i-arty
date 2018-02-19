`timescale 1ns / 1ps

/* //
//      JTAG InterFace
//      Author: Watson Huang
//      Module Description:
//          JTAG Interface for Xilinx FPGA USER JTAG port(USER1-USER4)
//      Change Log:
//      02/13, JTAG DMI interface function work
//      02/18, Add reset function via JTAG USER3
*/ //

module jtag_if#( //JTAG to system InterFace
    parameter DMI_ADDR_WIDTH = 7,
    parameter DMI_DATA_WIDTH = 32,
    parameter DMI_OP_WIDTH = 2,
    parameter TX_WIDTH = (DMI_ADDR_WIDTH+DMI_DATA_WIDTH+DMI_OP_WIDTH),
    parameter RX_WIDTH = (DMI_DATA_WIDTH+DMI_OP_WIDTH),
    parameter INFO_DATA_WIDTH = 32
)(

    //Core Interface
    output creq_vld,
    output [TX_WIDTH-1:0] creq_data,
    input creq_rdy,
    input cresp_vld,
    input [RX_WIDTH-1:0] cresp_data,
    output cresp_rdy,
    input reset,
    input clock,

    //Info Interface
    //Output List
    output jsys_reset,
    //Input List
    input init_ddr3_done
);

jtag_dmi_if#( //JTAG to system InterFace
    .JTAG_CHAIN(4), //Use USER4
    .DMI_ADDR_WIDTH(DMI_ADDR_WIDTH),
    .DMI_DATA_WIDTH(DMI_DATA_WIDTH),
    .DMI_OP_WIDTH(DMI_OP_WIDTH)
) jtag_dmi_dev (
    //Core Interface
    .creq_vld(creq_vld),
    .creq_data(creq_data),
    .creq_rdy(creq_rdy),
    .cresp_vld(cresp_vld),
    .cresp_data(cresp_data),
    .cresp_rdy(cresp_rdy),

    .reset(reset),
    .clock(clock)
);

jtag_info_if#(
    .JTAG_CHAIN(3),
    .JTAG_DATA_WIDTH(32)
) jtag_info_dev (
    //Output List
    .jsys_reset(jsys_reset),
    //Input List
    .init_ddr3_done(init_ddr3_done)
);

endmodule
