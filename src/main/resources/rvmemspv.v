module rvmemspv #( 
    parameter MEM_SIZE = 'h100000,
    parameter MEM_ADDR_WIDTH = 32,
    parameter MEM_DATA_WIDTH = 32,
    parameter MASK_WIDTH = MEM_DATA_WIDTH/8,
    parameter WRITE_DELAY = 1,
    parameter READ_DELAY = 1 
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
    input reset,
    input clock
);

//Log2 function form Xilinx
//Ref: https://www.xilinx.com/support/answers/44586.html
function integer clog2;
    input integer value;
    begin
        value = value-1;
        for (clog2=0; value>0; clog2=clog2+1)
        value = value>>1;
    end
endfunction

localparam MEM_SLOTS = MEM_SIZE/(MEM_DATA_WIDTH/8);
localparam ADDR_LO = clog2(MASK_WIDTH);
localparam ADDR_HI = clog2(MEM_SIZE/MASK_WIDTH) + ADDR_LO - 1; 
localparam WR_VALID_DELAY = (READ_DELAY>0)?READ_DELAY:1;
localparam RD_VALID_DELAY = (READ_DELAY>0)?READ_DELAY:1;

reg [MEM_DATA_WIDTH-1:0] mem [0:MEM_SLOTS-1];

reg [WR_VALID_DELAY-1:0]    reg_wardy;
reg [WR_VALID_DELAY-1:0]    reg_wdrdy;
reg                         reg_wbvld;

reg [MEM_DATA_WIDTH-1:0]    reg_rdata;
reg [RD_VALID_DELAY-1:0]    reg_rdrdy;
reg                         reg_rardy;

assign rdata = reg_rdata;
//assign rdrdy = reg_rdrdy[RD_VALID_DELAY-1];

assign wardy = reg_wardy[WR_VALID_DELAY-1];
assign wdrdy = reg_wdrdy;
assign wbvld = reg_wbvld;
assign rardy = reg_rardy;
assign rdrdy = reg_rdrdy[RD_VALID_DELAY-1];

generate
    if(WR_VALID_DELAY == 1) begin
        always@(posedge clock) begin
            reg_wbvld <= 1'b0;
            if(reg_wbvld) begin
                reg_wbvld <= 1'b0;
            end
            if(reg_wdrdy[0]) begin
                reg_wardy[0] <= 1'b0;
                //if(wden&reg_wdrdy[0]) begin
                if(wden) begin
                    reg_wardy[0] <= 1'b0;
                    reg_wdrdy[0] <= 1'b0;
                    reg_wbvld <= 1'b1;
                end
            end
            else begin
                reg_wardy[0] <= 1'b1;
                //if(waen&reg_wardy[0]) begin
                if(waen) begin
                    reg_wardy[0] <= 1'b0;
                    reg_wdrdy[0] <= 1'b1;
                end
            end
        end
    end
endgenerate

genvar i;
generate
    if(WR_VALID_DELAY == 1) begin
        for(i=0; i<MASK_WIDTH; i=i+1) begin: mem_mask
            always@(posedge clock) begin
                if(reg_wdrdy[0]) begin
                    if(wden) begin
                        if(wmask[i]) begin
                            mem[waddr[ADDR_HI:ADDR_LO]][8*(i+1)-1:8*i] <= wdata[8*(i+1)-1:8*i];
                        end
                    end
                end
            end
        end
    end
endgenerate

//Inspired by delay signal to delay memory read data output
//Reference: https://stackoverflow.com/questions/18943621/generate-a-clock-delay-by-fixed-cycles-number-verilog

generate
    if(RD_VALID_DELAY == 1) begin
        always@(posedge clock) begin
            reg_rardy <= 1'b1;
            if(reg_rdrdy[0]) begin
                reg_rardy <= 1'b1;
                reg_rdrdy[0] <= 1'b0;
            end
            else begin
                reg_rdrdy[0] <= 1'b0;
                if(raen&rardy) begin
                    reg_rdata <= mem[raddr[ADDR_HI:ADDR_LO]];
                    reg_rdrdy[0] <= 1'b1;
                    reg_rardy <= 1'b0;
                end
            end
        end
    end 
endgenerate

always@(posedge clock) begin
    if(reset) begin
        reg_rdata <= 32'h0;
        reg_wardy <= {WR_VALID_DELAY{1'b0}};
        reg_wdrdy <= {WR_VALID_DELAY{1'b0}};
        reg_rardy <= 1'b0;
        reg_rdrdy <= {RD_VALID_DELAY{1'b0}};
    end
end

endmodule