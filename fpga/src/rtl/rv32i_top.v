`timescale 1ns / 1ps

/* //
//      RV32I core top module
//      Author: Watson Huang
//      Module Description:
//          Top module for connecting JTAG interface, RV32I core, and external large memory (DDR3)
//      Change Log:
//      02/12, Arty JTAG DMI to RV32I core function work via JTAG USER4
//      02/16, Add reset function via JTAG USER3
*/ //

module rv32i_top(
    //DDR3 =========================
    // Inouts
    inout [15:0]       ddr3_dq,
    inout [1:0]        ddr3_dqs_n,
    inout [1:0]        ddr3_dqs_p,
    // Outputs
    output [13:0]     ddr3_addr,
    output [2:0]        ddr3_ba,
    output            ddr3_ras_n,
    output            ddr3_cas_n,
    output            ddr3_we_n,
    output            ddr3_reset_n,
    output [0:0]       ddr3_ck_p,
    output [0:0]       ddr3_ck_n,
    output [0:0]       ddr3_cke,
    output [0:0]        ddr3_cs_n,
    output [1:0]     ddr3_dm,
    output [0:0]       ddr3_odt,
    //DDR3 =========================
    output [7:4] led,
    input board_clock
);

localparam DMI_ADDR_WIDTH = 7;
localparam DMI_DATA_WIDTH = 32;
localparam DMI_OP_WIDTH = 2;
localparam JTAG_DATA_WIDTH = (DMI_ADDR_WIDTH+DMI_DATA_WIDTH+DMI_OP_WIDTH);
localparam TX_WIDTH = (DMI_ADDR_WIDTH+DMI_DATA_WIDTH+DMI_OP_WIDTH);
localparam RX_WIDTH = (DMI_DATA_WIDTH+DMI_OP_WIDTH);

wire        reset; 
wire        clock;
wire        pll_locked;

wire  [1:0]  io_dmi_req_bits_op;
wire  [6:0]  io_dmi_req_bits_addr;
wire  [31:0] io_dmi_req_bits_data;
wire         io_dmi_req_valid;
wire        io_dmi_req_ready;
wire [1:0]  io_dmi_resp_bits_resp;
wire [31:0] io_dmi_resp_bits_data;
wire        io_dmi_resp_valid;
wire         io_dmi_resp_ready;
wire        io_ext_mem_waen;
wire        io_ext_mem_wden;
wire [31:0] io_ext_mem_waddr;
wire [31:0] io_ext_mem_wdata;
wire [3:0]  io_ext_mem_wmask;
wire         io_ext_mem_wardy;
wire         io_ext_mem_wdrdy;
wire         io_ext_mem_wbvld;
wire        io_ext_mem_raen;
wire        io_ext_mem_rden;
wire [31:0] io_ext_mem_raddr;
wire  [31:0] io_ext_mem_rdata;
wire         io_ext_mem_rardy;
wire         io_ext_mem_rdrdy;
wire        io_ext_mem_clock;
wire        io_ext_mem_reset;

/*
wire jreq_vld;
wire [TX_WIDTH-1:0] jreq_data;
wire jreq_rdy;
wire jresp_vld;
wire [RX_WIDTH-1:0] jresp_data;
wire jresp_rdy;
*/
wire creq_vld;
wire [TX_WIDTH-1:0] creq_data;
wire creq_rdy;
wire cresp_vld;
wire [RX_WIDTH-1:0] cresp_data;
wire cresp_rdy;

/*
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
*/

// Core External Memory Interface
wire waen;
wire wden;
wire [31:0] waddr;
wire [31:0] wdata;
wire [3:0] wmask;
wire wardy;
wire wdrdy;
wire wbvld;
wire raen;
wire rden;
wire [31:0] raddr;
wire [31:0] rdata;
wire rardy;
wire rdrdy;

wire init_ddr3_done;

wire bufg_board_clock;
wire debug_clock;

wire jsys_reset;
//Debug for JTAG DMI alive check
//reg samp_xsel;

// Keep reset until Clock Locked
assign reset = (~pll_locked);

BUFG BUFG_BD (
    .O(bufg_board_clock), // Clock buffer output
    .I(board_clock) // Clock buffer input (connect directly to top-level port)
);

core_pll core_clock (
    // Clock out ports
    .clk_out1(clock),
    .clk_out2(debug_clock),
    // Status and control signals
    //.reset(1'b0), // input reset
    .reset(jsys_reset),
    .locked(pll_locked),       // output locked
    // Clock in ports
    .clk_in1(bufg_board_clock)
);      // input clk_in1

/*
BSCANE2 #(
    .JTAG_CHAIN(4) // USER4 command.
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
*/

jtag_if jtag_if_dev (

    //Core Interface
    .creq_vld(creq_vld),
    .creq_data(creq_data),
    .creq_rdy(creq_rdy),
    .cresp_vld(cresp_vld),
    .cresp_data(cresp_data),
    .cresp_rdy(cresp_rdy),

    .reset(reset),
    .clock(clock),

    //Output List
    .jsys_reset(jsys_reset),
    //Input List
    .init_ddr3_done(init_ddr3_done)
);

assign io_dmi_req_bits_op = creq_data[0+:2];
assign io_dmi_req_bits_data = creq_data[2+:32];
assign io_dmi_req_bits_addr = creq_data[34+:7];
assign io_dmi_req_valid = creq_vld;
assign creq_rdy = io_dmi_req_ready&init_ddr3_done;

assign cresp_vld = io_dmi_resp_valid;
assign cresp_data = {io_dmi_resp_bits_data, io_dmi_resp_bits_resp};
assign io_dmi_resp_ready = cresp_rdy;

rv32i_fpga rv32i (
    .clock(clock),
    .reset(reset),
    .io_dmi_req_bits_op(io_dmi_req_bits_op),
    .io_dmi_req_bits_addr(io_dmi_req_bits_addr),
    .io_dmi_req_bits_data(io_dmi_req_bits_data),
    .io_dmi_req_valid(io_dmi_req_valid),
    .io_dmi_req_ready(io_dmi_req_ready),
    .io_dmi_resp_bits_resp(io_dmi_resp_bits_resp),
    .io_dmi_resp_bits_data(io_dmi_resp_bits_data),
    .io_dmi_resp_valid(io_dmi_resp_valid),
    .io_dmi_resp_ready(io_dmi_resp_ready),
    .io_ext_mem_waen(io_ext_mem_waen),
    .io_ext_mem_wden(io_ext_mem_wden),
    .io_ext_mem_waddr(io_ext_mem_waddr),
    .io_ext_mem_wdata(io_ext_mem_wdata),
    .io_ext_mem_wmask(io_ext_mem_wmask),
    .io_ext_mem_wardy(io_ext_mem_wardy),
    .io_ext_mem_wdrdy(io_ext_mem_wdrdy),
    .io_ext_mem_wbvld(io_ext_mem_wbvld),
    .io_ext_mem_raen(io_ext_mem_raen),
    .io_ext_mem_rden(io_ext_mem_rden),
    .io_ext_mem_raddr(io_ext_mem_raddr),
    .io_ext_mem_rdata(io_ext_mem_rdata),
    .io_ext_mem_rardy(io_ext_mem_rardy),
    .io_ext_mem_rdrdy(io_ext_mem_rdrdy),
    .io_ext_mem_clock(io_ext_mem_clock),
    .io_ext_mem_reset(io_ext_mem_reset)
);

assign waen = io_ext_mem_waen;
assign wden = io_ext_mem_wden;
assign waddr = io_ext_mem_waddr;
assign wdata = io_ext_mem_wdata;
assign wmask = io_ext_mem_wmask;
assign io_ext_mem_wardy = wardy;
assign io_ext_mem_wdrdy = wdrdy;
assign io_ext_mem_wbvld = wbvld;
assign raen = io_ext_mem_raen;
assign rden = io_ext_mem_rden;
assign raddr = io_ext_mem_raddr;
assign io_ext_mem_rdata = rdata;
assign io_ext_mem_rardy = rardy;
assign io_ext_mem_rdrdy = rdrdy;

rvmemspv rvmemspv (
    
    // Inouts
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    // Outputs
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_cke(ddr3_cke),
    .ddr3_cs_n(ddr3_cs_n),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt),
    
    .board_clock(bufg_board_clock),
    .init_ddr3_done(init_ddr3_done),
    
    .waen(waen),
    .wden(wden),
    .waddr(waddr),
    .wdata(wdata),
    .wmask(wmask),
    .wardy(wardy),
    .wdrdy(wdrdy),
    .wbvld(wbvld),
    .raen(raen),
    .rden(rden),
    .raddr(raddr),
    .rdata(rdata),
    .rardy(rardy),
    .rdrdy(rdrdy),
    
    .reset(reset),
    .clock(clock)
);

//Debug by show status on LED
assign led[4] = 1'b0;
assign led[5] = 1'b0;
assign led[6] = 1'b0;
assign led[7] = 1'b0;

endmodule
