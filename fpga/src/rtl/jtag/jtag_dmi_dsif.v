`timescale 1ns / 1ps

/* //
//      JTAG Debug Module InterFace (JTAG DMI) for JTAG DR-SHIFT state
//      Author: Watson Huang
//      Module Description:
//          Handle JTAG DR-SHIFT behavior and pass command to RISCV DMI module
//      Change Log:
//      02/13, JTAG DMI interface function work
*/ //

module jtag_dmi_dsif#( //JTAG D-SHIFT Interface
    parameter DMI_ADDR_WIDTH = 7,
    parameter DMI_DATA_WIDTH = 32,
    parameter DMI_OP_WIDTH = 2,
    parameter JTAG_DATA_WIDTH = (DMI_ADDR_WIDTH+DMI_DATA_WIDTH+DMI_OP_WIDTH),
    parameter TX_WIDTH = (DMI_ADDR_WIDTH+DMI_DATA_WIDTH+DMI_OP_WIDTH),
    parameter RX_WIDTH = (DMI_DATA_WIDTH+DMI_OP_WIDTH)
)(
    input jclk, //Jtag Clock
    
    //JTAG D-SHIFT interface
    input jcapture,
    input jreset,
    input jshift,
    input jupdate,
    output jtdo, 
    input jtdi,
    input jtms,
    input jsel,
    
    //JTAG to DMI Interface
    output reg jreq_vld,
    output [TX_WIDTH-1:0] jreq_data,
    input jreq_rdy,
    input jresp_vld,
    input [RX_WIDTH-1:0] jresp_data,
    output reg jresp_rdy,
    
    input dev_rst
);

reg [JTAG_DATA_WIDTH-1:0] jreq_buf;
reg [JTAG_DATA_WIDTH-1:0] jresp_buf;

reg req_avl; //Request Available
reg req_done;
reg resp_avl; //Response Availalbe
reg [RX_WIDTH-1:0] resp_data;
reg [DMI_ADDR_WIDTH-1:0] resp_addr;

reg jreq_update;

assign jtdo = jresp_buf[0];
assign jreq_data = jreq_buf;

always@(posedge jclk or posedge dev_rst) begin //Use sub-optimal reset trigger, caluse JTAG clock didn't always available
    if(dev_rst|jreset) begin
        jreq_vld <= 1'b0;
        jresp_rdy <= 1'b0;
    
        jreq_buf <= {JTAG_DATA_WIDTH{1'b0}};
        jresp_buf <= {JTAG_DATA_WIDTH{1'b0}};
        req_avl <= 1'b0;
        req_done <= 1'b0;
        resp_avl <= 1'b0;
        resp_data <= {RX_WIDTH{1'b0}};
        resp_addr <= {DMI_ADDR_WIDTH{1'b0}};
        
        jreq_update <= 1'b0;
    end
    else begin
        if(jsel) begin
            //CAPTURE STATE
            if(jcapture) begin
                if(resp_avl&(!req_done)) begin
                    jresp_buf[RX_WIDTH+:DMI_ADDR_WIDTH] <= resp_addr;
                    jresp_buf[0+:RX_WIDTH] <= resp_data;
                    req_done <= 1'b1;
                end
            end
            
            //D-SHIFT STATE
            if(jshift&(~jreq_update)) begin
                jreq_buf <= {jtdi, jreq_buf[JTAG_DATA_WIDTH-1:1]};
                jresp_buf <= {jresp_buf[0], jresp_buf[JTAG_DATA_WIDTH-1:1]};
                if(jtms) begin
                    jreq_update <= 1'b1;
                end
            end
            
            //UPDATE-DR STATE with EXIT1-DR
            //jreq_vld <= 1'b0;
            
            if(jupdate) begin
                jreq_update <= 1'b0;
                jreq_vld <= 1'b0;
            end
            else if(jreq_update) begin //EXIT1-DR
                jreq_update <= 1'b0;
                if(req_avl) begin
                    if(req_done) begin
                        req_avl <= 1'b0;
                        resp_avl <= 1'b0;
                        req_done <= 1'b0;
                        jresp_buf <= {JTAG_DATA_WIDTH{1'b0}};
                    end
                end
                else begin
                    if(jreq_rdy) begin
                        if(jreq_buf[DMI_OP_WIDTH-1:0] == 2'b01) begin //DMI_REQOP_RD = 2'h1;'
                            jreq_vld <= 1'b1;
                            req_avl <= 1'b1;
                            resp_addr <= jreq_buf[(DMI_DATA_WIDTH+DMI_OP_WIDTH)+:DMI_ADDR_WIDTH];
                            jresp_buf[DMI_OP_WIDTH+:(DMI_ADDR_WIDTH+DMI_DATA_WIDTH)] <= {jreq_buf[(DMI_DATA_WIDTH+DMI_OP_WIDTH)+:DMI_ADDR_WIDTH], {DMI_DATA_WIDTH{1'b0}}};
                            jresp_buf[DMI_OP_WIDTH-1:0] <= 2'h3;
                        end
                        else if(jreq_buf[DMI_OP_WIDTH-1:0] == 2'b10) begin //DMI_REQOP_WR = 2'h2;
                            jreq_vld <= 1'b1;
                            req_avl <= 1'b1;
                            resp_addr <= jreq_buf[(DMI_DATA_WIDTH+DMI_OP_WIDTH)+:DMI_ADDR_WIDTH];
                            jresp_buf[DMI_OP_WIDTH+:(DMI_ADDR_WIDTH+DMI_DATA_WIDTH)] <= {jreq_buf[(DMI_DATA_WIDTH+DMI_OP_WIDTH)+:DMI_ADDR_WIDTH], {DMI_DATA_WIDTH{1'b0}}};
                            jresp_buf[DMI_OP_WIDTH-1:0] <= 2'h3;
                        end
                        else if(jreq_buf[DMI_OP_WIDTH-1:0] == 2'b00) begin //DMI_REQOP_NOP = 2'h0;'
                            if(jresp_buf[DMI_OP_WIDTH-1:0] == 2'h2) begin
                                jresp_buf <= {JTAG_DATA_WIDTH{1'b0}};
                            end
                            if(req_avl) begin
                                jresp_buf[(DMI_DATA_WIDTH+DMI_OP_WIDTH)+:(DMI_ADDR_WIDTH)] = resp_addr;
                                jresp_buf[DMI_OP_WIDTH-1:0] <= 2'h3;
                            end
                        end
                    end
                    else begin
                        if(jreq_buf[DMI_OP_WIDTH-1:0] == 2'b00) begin //DMI_REQOP_NOP = 2'h0;'
                            if(jresp_buf[DMI_OP_WIDTH-1:0] == 2'h2) begin
                                jresp_buf <= {JTAG_DATA_WIDTH{1'b0}};
                            end
                            if(req_avl) begin
                                jresp_buf[(DMI_DATA_WIDTH+DMI_OP_WIDTH)+:(DMI_ADDR_WIDTH)] = resp_addr;
                                jresp_buf[DMI_OP_WIDTH-1:0] <= 2'h3;
                            end
                        end
                        else begin
                            jresp_buf[DMI_OP_WIDTH+:(DMI_ADDR_WIDTH+DMI_DATA_WIDTH)] <= jreq_buf[DMI_OP_WIDTH+:(DMI_ADDR_WIDTH+DMI_DATA_WIDTH)];
                            jresp_buf[DMI_OP_WIDTH-1:0] <= 2'h2;
                        end
                    end
                end
            end
            
        end
        //Receive data from JTAG-DMI-INTC
        jresp_rdy <= 1'b1; // Always enable, allow to overwrite exist data for simplicify
        if(jresp_vld&(req_avl)) begin
            resp_avl <= 1'b1;
            resp_data <= jresp_data;
        end
        
    end
end

endmodule
