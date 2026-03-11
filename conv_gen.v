module conv3x3 #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  wire clk,
    input  wire reset,

    input  wire [9*DATA_W-1:0] in_pixel,
    input  wire pixel_valid,

    input  wire signed [9*DATA_W-1:0] kernel,
    input  wire [7:0] norm_factor,
    input  wire negative,

    output reg  [DATA_W-1:0] out_pixel,
    output wire out_valid
);

localparam MAX_VAL = (1<<DATA_W)-1;

/*---------------------------------------
Unpack pixels and kernel
---------------------------------------*/
wire signed [DATA_W:0] p [0:8];     // zero extended pixels
wire signed [DATA_W-1:0] k [0:8];

genvar i;
generate
for(i=0;i<9;i=i+1) begin
    assign p[i] = {1'b0, in_pixel[i*DATA_W +: DATA_W]};
    assign k[i] = kernel[i*DATA_W +: DATA_W];
end
endgenerate


/*---------------------------------------
Stage 1 : Multipliers
---------------------------------------*/
reg signed [2*DATA_W:0] mult [0:8];

integer j;

always @(posedge clk) begin
    if(reset) begin
        for(j=0;j<9;j=j+1)
            mult[j] <= 0;
    end
    else begin
        for(j=0;j<9;j=j+1)
            mult[j] <= p[j] * k[j];
    end
end


/*---------------------------------------
Stage 2 : Adder tree
---------------------------------------*/
reg signed [ACC_W-1:0] sum1 [0:4];
reg signed [ACC_W-1:0] sum2 [0:2];
reg signed [ACC_W-1:0] sum3;

always @(posedge clk) begin
    if(reset) begin
        sum1[0]<=0; sum1[1]<=0; sum1[2]<=0; sum1[3]<=0; sum1[4]<=0;
    end else begin
        sum1[0] <= mult[0] + mult[1];
        sum1[1] <= mult[2] + mult[3];
        sum1[2] <= mult[4] + mult[5];
        sum1[3] <= mult[6] + mult[7];
        sum1[4] <= mult[8];
    end
end

always @(posedge clk) begin
    if(reset) begin
        sum2[0]<=0; sum2[1]<=0; sum2[2]<=0;
    end else begin
        sum2[0] <= sum1[0] + sum1[1];
        sum2[1] <= sum1[2] + sum1[3];
        sum2[2] <= sum1[4];
    end
end

always @(posedge clk) begin
    if(reset)
        sum3 <= 0;
    else
        sum3 <= sum2[0] + sum2[1] + sum2[2];
end


/*---------------------------------------
Stage 3 : Normalize + Clamp
---------------------------------------*/
reg signed [ACC_W-1:0] norm_val;
reg [DATA_W-1:0] pixel_clamped;

always @(posedge clk) begin
    if(reset) begin
        out_pixel <= 0;
    end
    else begin

        norm_val <= sum3 / norm_factor;

        if(norm_val < 0)
            pixel_clamped <= 0;
        else if(norm_val > MAX_VAL)
            pixel_clamped <= MAX_VAL;
        else
            pixel_clamped <= norm_val[DATA_W-1:0];

        if(negative)
            out_pixel <= MAX_VAL - pixel_clamped;
        else
            out_pixel <= pixel_clamped;

    end
end


/*---------------------------------------
Valid pipeline
---------------------------------------*/
reg vld1,vld2,vld3,vld4;

always @(posedge clk) begin
    if(reset) begin
        vld1<=0; vld2<=0; vld3<=0; vld4<=0;
    end
    else begin
        vld1 <= pixel_valid;
        vld2 <= vld1;
        vld3 <= vld2;
        vld4 <= vld3;
    end
end

assign out_valid = vld4;

endmodule