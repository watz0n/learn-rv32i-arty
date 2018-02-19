`timescale 1ns / 1ps

/* //
//      JTAG System Information Interface
//      Author: Watson Huang
//      Module Description:
//          PC control action and collect information interface
//      Change Log:
//      02/18, Reset(write to bit0) and detect DDR3 calibration done (read from bit1) function work
*/ //

module jtag_info_if#( //JTAG to system InterFace
    parameter JTAG_CHAIN = 3, //Use USER3
    parameter JTAG_DATA_WIDTH = 32
)(
    //Output List
    output jsys_reset,

    //Input List
    input init_ddr3_done
);

//JTAG D-SHIFT interface
wire jcapture;
wire jreset;
wire jshift;
wire jupdate;
wire jtdo;
wire jtdi;
wire jtms;
wire jsel; 
wire jclk;

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

reg [JTAG_DATA_WIDTH-1:0] jinfo_buf;
reg [JTAG_DATA_WIDTH-1:0] jreq_buf;
reg [JTAG_DATA_WIDTH-1:0] jresp_buf;


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

assign jclk = xtck;

assign jtdo = jresp_buf[0];

initial begin: assign_initial_value
    jreq_buf = {JTAG_DATA_WIDTH{1'b0}};
    jresp_buf = {JTAG_DATA_WIDTH{1'b0}};
    jinfo_buf = {JTAG_DATA_WIDTH{1'b0}};
end

always@(posedge jclk) begin
    if(jreset) begin
        jreq_buf <= {JTAG_DATA_WIDTH{1'b0}};
        jresp_buf <= {JTAG_DATA_WIDTH{1'b0}};
        jinfo_buf <= {JTAG_DATA_WIDTH{1'b0}};
    end
    else begin
        if(jsel) begin

            if(jcapture) begin
                jresp_buf <= {JTAG_DATA_WIDTH{1'b0}};

                //Assign input from system list
                jresp_buf[0] <= jsys_reset;
                jresp_buf[1] <= init_ddr3_done;

            end

            if(jshift) begin
                jreq_buf <= {jtdi, jreq_buf[JTAG_DATA_WIDTH-1:1]};
                jresp_buf <= {jresp_buf[0], jresp_buf[JTAG_DATA_WIDTH-1:1]};
            end

            if(jupdate) begin
                jinfo_buf <= jreq_buf;
            end
        
        end
    end
end

//Assign output to system list
assign jsys_reset = jinfo_buf[0];

endmodule