`timescale 1ns / 1ps

/* //
//      JTAG Debug Module InterFace (JTAG DMI) INTerConnect module
//      Author: Watson Huang
//      Module Description:
//          Crossing JTAG and RV32I core clock domain
//      Change Log:
//      02/13, JTAG DMI interface function work
*/ //

module jtag_dmi_intc#(
    parameter TX_WIDTH = (7+32+2),
    parameter RX_WIDTH = (32+2)
)(
    //Jtag Interface
    input jclk, //Jtag Clock
    input jreq_vld,
    input [TX_WIDTH-1:0] jreq_data,
    output reg jreq_rdy,
    output reg jresp_vld,
    output reg [RX_WIDTH-1:0] jresp_data,
    input jresp_rdy,
    
    //Core Interface
    input cclk, //Core Clock
    output reg creq_vld,
    output reg [TX_WIDTH-1:0] creq_data,
    input creq_rdy,
    input cresp_vld,
    input [RX_WIDTH-1:0] cresp_data,
    output reg cresp_rdy,
    
    input dev_rst
);

reg jreq_avl; //availalbe
reg [TX_WIDTH-1:0] jreq_buf;
reg [1:0] jresp_samp; //sampling

reg crst;
reg [1:0] creq_samp; //sampling
reg cresp_avl; //availalbe
reg [RX_WIDTH-1:0] cresp_buf;

always@(posedge jclk or posedge dev_rst) begin //Use sub-optimal reset trigger, caluse JTAG clock didn't always available
    if(dev_rst) begin
        jreq_rdy <= 1'b0;
        jresp_vld <= 1'b0;
        jresp_data <= {RX_WIDTH{1'b0}};
        
        jreq_avl <= 1'b0;
        jreq_buf <= {TX_WIDTH{1'b0}};
        jresp_samp <= 2'h0;
    end
    else begin
        jresp_samp <= {jresp_samp[0], cresp_avl};
        if(jreq_avl) begin
            jreq_rdy <= 1'b0;
            if((!jresp_samp[1])&(jresp_samp[0])) begin
                jresp_vld <= 1'b1;
                jresp_data <= cresp_buf;
            end
            if(jresp_vld&jresp_rdy) begin
                jresp_vld <= 1'b0;
                jreq_avl <= 1'b0;
                jreq_rdy <= 1'b1;
                if(jresp_samp[1]) begin
                    jreq_rdy <= 1'b0;
                end
            end 
        end
        else begin
            jreq_rdy <= 1'b1;
            jresp_vld <= 1'b0;
            if(jresp_samp[1]) begin
                jreq_rdy <= 1'b0;
            end
            if(jreq_vld&jreq_rdy) begin
                jreq_rdy <= 1'b0;
                jreq_avl <= 1'b1;
                jreq_buf <= jreq_data;
            end
        end
    end
end

always@(posedge cclk) begin
    crst <= dev_rst;
end

always@(posedge cclk) begin
    if(crst) begin
        creq_vld <= 1'b0;
        creq_data <= {TX_WIDTH{1'b0}};
        cresp_rdy <= 1'b0;
        
        creq_samp <= 2'h0;
        cresp_avl <= 1'b0;
        cresp_buf <= {RX_WIDTH{1'b0}};
    end
    else begin
        
        creq_samp <= {creq_samp[0], jreq_avl};
        if((!creq_samp[1])&creq_samp[0]) begin // 0->1
            creq_vld <= 1'b1;
            creq_data <= jreq_buf;
        end
        if(creq_vld&creq_rdy) begin
            creq_vld <= 1'b0;
        end
        
        //Resp
        if(cresp_avl) begin
             cresp_rdy <= 1'b0;
            if(creq_samp[1]&(!creq_samp[0])) begin //1->0
                cresp_avl <= 1'b0;
                cresp_rdy <= 1'b1;
            end
        end
        else begin
            cresp_rdy <= 1'b1;
            if(cresp_vld&cresp_rdy) begin
                cresp_rdy <= 1'b0;
                creq_data <= {TX_WIDTH{1'b0}};
                cresp_avl <= 1'b1;
                cresp_buf <= cresp_data;
            end
        end
    end
end

endmodule
