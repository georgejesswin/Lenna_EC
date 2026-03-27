module rgb2gray #(
    parameter DATA_W = 8
)(
    input clk,
    input reset,                 // active high
    input [(DATA_W*3)-1:0] in_pixel,
    input in_valid,

    output reg [DATA_W-1:0] gray_pixel,
    output reg out_valid
);

wire [DATA_W-1:0] r;
wire [DATA_W-1:0] g;
wire [DATA_W-1:0] b;

assign r = in_pixel[(3*DATA_W)-1:(2*DATA_W)];
assign g = in_pixel[(2*DATA_W)-1:(DATA_W)];
assign b = in_pixel[(DATA_W)-1:0];

wire [DATA_W+1:0] sum;

assign sum = r + (g << 1) + b;

always @(posedge clk) begin
    if(reset) begin
        gray_pixel <= 0;
        out_valid  <= 0;
    end
    else begin
        gray_pixel <= sum >> 2;
        out_valid  <= in_valid;
    end
end

endmodule