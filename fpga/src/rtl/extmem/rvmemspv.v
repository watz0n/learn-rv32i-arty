`timescale 1ns / 1ps
/* //
//      Single Port Memory interface for RV32I core
//      Author: Watson Huang
//      Module Description:
//          Single Port Memory for RV32I, backend is DDR3 AXI IP for Digilent Arty board
//      Change Log:
//      02/13, 2018: Add DDR3 AXI IP for large memory, and Interconnect IP for crossing clock domain
//      02/18, 2018: Fix reset mechanism for JTAG USER3 reset information from top design
*/ //
module rvmemspv #( 
    //parameter MEM_SIZE = 'h100000,
    parameter MEM_ADDR_WIDTH = 32,
    parameter MEM_DATA_WIDTH = 32,
    parameter MASK_WIDTH = MEM_DATA_WIDTH/8
    //parameter WRITE_DELAY = 1,
    //parameter READ_DELAY = 1 
)(
    input waen,
    input wden,
    input [MEM_ADDR_WIDTH-1:0] waddr,
    input [MEM_DATA_WIDTH-1:0] wdata,
    input [MASK_WIDTH-1:0] wmask,
    output wardy,
    output wdrdy,
    output wbvld,
    input raen,
    input rden,
    input [MEM_ADDR_WIDTH-1:0] raddr,
    output [MEM_DATA_WIDTH-1:0] rdata,
    output rardy,
    output rdrdy,
    
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
    input board_clock,
    output reg init_ddr3_done,
    
    input reset,
    input clock
);

wire ui_clk;
wire aresetn;
wire sys_clk;
wire ref_clk;
wire ddr3_pll_locked;
// Slave Interface Write Address Ports
wire [3:0]           s_axi_awid;
wire [27:0]          s_axi_awaddr;
wire [7:0]           s_axi_awlen;
wire [2:0]           s_axi_awsize;
wire [1:0]           s_axi_awburst;
wire [0:0]           s_axi_awlock;
wire [3:0]           s_axi_awcache;
wire [2:0]           s_axi_awprot;
wire [3:0]           s_axi_awqos;
wire         s_axi_awvalid;
wire            s_axi_awready;
// Slave Interface Write Data Ports
wire [31:0]         s_axi_wdata;
wire [3:0]         s_axi_wstrb;
wire         s_axi_wlast;
wire         s_axi_wvalid;
wire            s_axi_wready;
// Slave Interface Write Response Ports
wire         s_axi_bready;
wire [3:0]          s_axi_bid;
wire [1:0]          s_axi_bresp;
wire            s_axi_bvalid;
// Slave Interface Read Address Ports
wire [3:0]           s_axi_arid;
wire [27:0]         s_axi_araddr;
wire [7:0]           s_axi_arlen;
wire [2:0]           s_axi_arsize;
wire [1:0]           s_axi_arburst;
wire [0:0]           s_axi_arlock;
wire [3:0]           s_axi_arcache;
wire [2:0]           s_axi_arprot;
wire [3:0]           s_axi_arqos;
wire         s_axi_arvalid;
wire            s_axi_arready;
// Slave Interface Read Data Ports
wire         s_axi_rready;
wire [3:0]          s_axi_rid;
wire [31:0]            s_axi_rdata;
wire [1:0]          s_axi_rresp;
wire            s_axi_rlast;
wire            s_axi_rvalid;

wire init_calib_complete;

reg [1:0] samp_init_ddr3_done;
reg init_ddr3_ready;

always@(posedge clock or posedge reset) begin
	if(reset) begin
		init_ddr3_done <= 1'b0;
		samp_init_ddr3_done <= 2'b11;
		init_ddr3_ready <= 1'b0;
	end
	else begin
	    samp_init_ddr3_done[0] <= init_calib_complete;
	    samp_init_ddr3_done[1] <= samp_init_ddr3_done[0];
	    
	    if((!samp_init_ddr3_done[1])&samp_init_ddr3_done[0]) begin
	       init_ddr3_ready <= 1'b1;
	    end
	    else if(!samp_init_ddr3_done[1]) begin
	       init_ddr3_ready <= 1'b0;
	    end
	    
		if(init_ddr3_ready&(wardy&rardy)) begin
			init_ddr3_done <= 1'b1;
		end
		else if(!samp_init_ddr3_done[1]) begin
		    init_ddr3_done <= 1'b0;
		end
		
	end
end

axi_intc axi_intc (
    .INTERCONNECT_ACLK(clock),
    //.INTERCONNECT_ARESETN(~reset), //Don't work
    .INTERCONNECT_ARESETN(init_calib_complete), //Keep reset until ddr3 calibration complete
    //.INTERCONNECT_ARESETN(samp_init_calib_complete),
    .S00_AXI_ARESET_OUT_N(),
    .S00_AXI_ACLK(clock),
    .S00_AXI_AWID(1'b0),
    .S00_AXI_AWADDR(waddr[27:0]),
    .S00_AXI_AWLEN(8'h00),
    .S00_AXI_AWSIZE(3'h2),
    .S00_AXI_AWBURST(2'h0),
    .S00_AXI_AWLOCK(1'b0),
    .S00_AXI_AWCACHE(4'h0),
    .S00_AXI_AWPROT(3'h0),
    .S00_AXI_AWQOS(4'h0),
    .S00_AXI_AWVALID(waen),
    .S00_AXI_AWREADY(wardy),
    .S00_AXI_WDATA(wdata),
    .S00_AXI_WSTRB(wmask),
    .S00_AXI_WLAST(wden),
    .S00_AXI_WVALID(wden),
    .S00_AXI_WREADY(wdrdy),
    .S00_AXI_BID(),
    .S00_AXI_BRESP(),
    .S00_AXI_BVALID(wbvld),
    .S00_AXI_BREADY(1'b1),
    .S00_AXI_ARID(1'b0),
    .S00_AXI_ARADDR(raddr[27:0]),
    .S00_AXI_ARLEN(8'h00),
    .S00_AXI_ARSIZE(3'h2),
    .S00_AXI_ARBURST(2'h0),
    .S00_AXI_ARLOCK(1'b0),
    .S00_AXI_ARCACHE(4'h0),
    .S00_AXI_ARPROT(3'h0),
    .S00_AXI_ARQOS(4'h0),
    .S00_AXI_ARVALID(raen),
    .S00_AXI_ARREADY(rardy),
    .S00_AXI_RID(),
    .S00_AXI_RDATA(rdata),
    .S00_AXI_RRESP(),
    .S00_AXI_RLAST(),
    .S00_AXI_RVALID(rdrdy),
    .S00_AXI_RREADY(1'b1),
    .M00_AXI_ARESET_OUT_N(aresetn),
    .M00_AXI_ACLK(ui_clk),
    .M00_AXI_AWID(s_axi_awid),
    .M00_AXI_AWADDR(s_axi_awaddr),
    .M00_AXI_AWLEN(s_axi_awlen),
    .M00_AXI_AWSIZE(s_axi_awsize),
    .M00_AXI_AWBURST(s_axi_awburst),
    .M00_AXI_AWLOCK( s_axi_awlock),
    .M00_AXI_AWCACHE(s_axi_awcache),
    .M00_AXI_AWPROT(s_axi_awprot),
    .M00_AXI_AWQOS(s_axi_awqos),
    .M00_AXI_AWVALID(s_axi_awvalid),
    .M00_AXI_AWREADY(s_axi_awready),
    .M00_AXI_WDATA(s_axi_wdata),
    .M00_AXI_WSTRB(s_axi_wstrb),
    .M00_AXI_WLAST(s_axi_wlast),
    .M00_AXI_WVALID(s_axi_wvalid),
    .M00_AXI_WREADY(s_axi_wready),
    .M00_AXI_BID(s_axi_bid),
    .M00_AXI_BRESP(s_axi_bresp),
    .M00_AXI_BVALID(s_axi_bvalid),
    .M00_AXI_BREADY(s_axi_bready),
    .M00_AXI_ARID(s_axi_arid),
    .M00_AXI_ARADDR(s_axi_araddr),
    .M00_AXI_ARLEN(s_axi_arlen),
    .M00_AXI_ARSIZE(s_axi_arsize),
    .M00_AXI_ARBURST(s_axi_arburst),
    .M00_AXI_ARLOCK(s_axi_arlock),
    .M00_AXI_ARCACHE(s_axi_arcache),
    .M00_AXI_ARPROT(s_axi_arprot),
    .M00_AXI_ARQOS(s_axi_arqos),
    .M00_AXI_ARVALID(s_axi_arvalid),
    .M00_AXI_ARREADY(s_axi_arready),
    .M00_AXI_RID(s_axi_rid),
    .M00_AXI_RDATA(s_axi_rdata),
    .M00_AXI_RRESP(s_axi_rresp),
    .M00_AXI_RLAST(s_axi_rlast),
    .M00_AXI_RVALID(s_axi_rvalid),
    .M00_AXI_RREADY(s_axi_rready)
);

axi_mig_ddr3 axi_mig_ddr3 (
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
    
    // Inputs
    // Single-ended system clock
    .sys_clk_i(sys_clk),
    // Single-ended iodelayctrl clk (reference clock)
    .clk_ref_i(ref_clk),
    // user interface signals
    .ui_clk(ui_clk),
    .ui_clk_sync_rst(),
    .mmcm_locked(),
    //.aresetn(),
    .app_sr_req(1'b0),
    .app_ref_req(1'b0),
    .app_zq_req(1'b0),
    .app_sr_active(),
    .app_ref_ack(),
    .app_zq_ack(),
    .aresetn(aresetn),
    // Slave Interface Write Address Ports
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awqos(s_axi_awqos),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    // Slave Interface Write Data Ports
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    // Slave Interface Write Response Ports
    .s_axi_bready(s_axi_bready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    // Slave Interface Read Address Ports
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arqos(s_axi_arqos),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    // Slave Interface Read Data Ports
    .s_axi_rready(s_axi_rready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_rvalid(s_axi_rvalid),
    
    //Other functions
    .init_calib_complete(init_calib_complete),
    .device_temp_i(12'h000),
    .device_temp(),
    .sys_rst(ddr3_pll_locked)
);

ddr3_pll ddr3_pll (
	// Clock out ports
	.clk_out1(sys_clk),
	.clk_out2(ref_clk),
	// Status and control signals
	//.reset(1'b0),
	.reset(reset),
	.locked(ddr3_pll_locked),
	// Clock in ports
	.clk_in1(board_clock)
);

endmodule