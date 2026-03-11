module top_wrapper#(
    parameter DATA_W = 8,
    parameter IMG_WIDTH = 512,
    parameter ACC_W = 32
)(
    input clk,
    input reset,// Active Lo
    input [(DATA_W*3)-1:0] in_pixel,
    input in_valid,
    input [6:0] kernel_sel,
    output s_out_ready,
    output [(DATA_W*3)-1:0] out_pixel,
    output out_valid,
    input m_in_ready,
    output o_intr
);

wire [(DATA_W*9)-1:0] out_72 [0:2];
wire [DATA_W-1:0] out_pixel_conv [0:2];
wire out_valid_contr [0:2];
wire out_valid_conv [0:2];
wire axis_prog_full;
wire  signed [9*DATA_W-1:0] kernel_out;
wire o_intr_loc [0:2];
assign s_out_ready=~axis_prog_full;
image_control_param #(
    .DATA_W(DATA_W),
    .IMG_WIDTH(IMG_WIDTH)
)IMC_B (
    .clk(clk),
    .reset(~reset),
    .in_pixel(in_pixel[DATA_W-1:0]),
    .in_valid(in_valid),
    .out_pixel(out_72[0]), 
    .out_valid(out_valid_contr[0]),
    .o_intr(o_intr_loc[0])
);
image_control_param #(
    .DATA_W(DATA_W),
    .IMG_WIDTH(IMG_WIDTH)
)IMC_G (
    .clk(clk),
    .reset(~reset),
    .in_pixel(in_pixel[2*DATA_W-1:DATA_W]),
    .in_valid(in_valid),
    .out_pixel(out_72[1]), 
    .out_valid(out_valid_contr[1]),
    .o_intr(o_intr_loc[1])
);
image_control_param #(
    .DATA_W(DATA_W),
    .IMG_WIDTH(IMG_WIDTH)
)IMC_R (
    .clk(clk),
    .reset(~reset),
    .in_pixel(in_pixel[3*DATA_W-1:2*DATA_W]),
    .in_valid(in_valid),
    .out_pixel(out_72[2]), 
    .out_valid(out_valid_contr[2]),
    .o_intr(o_intr_loc[2])
);
wire [7:0] norm_factor;
kernel_selector KER(
    .kernel_sel(kernel_sel),
    .kernel_out(kernel_out),
    .norm_factor(norm_factor)
    
);
conv3x3#(
    .DATA_W(DATA_W),
    .ACC_W(ACC_W)
) CONV_B(
     .clk(clk),
    .in_pixel(out_72[0]),
    .kernel(kernel_out),
    .norm_factor(norm_factor),
    .negative(kernel_sel[6]),
    .pixel_valid(out_valid_contr[0]),
    .out_pixel(out_pixel_conv[0]),
    .out_valid(out_valid_conv[0])
);
conv3x3#(
    .DATA_W(DATA_W),
    .ACC_W(ACC_W)
) CONV_G(
     .clk(clk),
    .in_pixel(out_72[1]),
    .kernel(kernel_out),
    .norm_factor(norm_factor),
    .negative(kernel_sel[6]),
    .pixel_valid(out_valid_contr[1]),
    .out_pixel(out_pixel_conv[1]),
    .out_valid(out_valid_conv[1])
);
conv3x3#(
    .DATA_W(DATA_W),
    .ACC_W(ACC_W)
) CONV_R(
     .clk(clk),
    .in_pixel(out_72[2]),
    .kernel(kernel_out),
    .norm_factor(norm_factor),
    .negative(kernel_sel[6]),
    .pixel_valid(out_valid_contr[2]),
    .out_pixel(out_pixel_conv[2]),
    .out_valid(out_valid_conv[2])
);
assign o_intr=o_intr_loc[0] || o_intr_loc[1] || o_intr_loc[2];
wire out_valid_rgb= out_valid_conv[0] && out_valid_conv[1] && out_valid_conv[2];
wire [(DATA_W*3)-1:0] out_pixel_rgb= {out_pixel_conv[2],out_pixel_conv[1],out_pixel_conv[0]};
fifo_generator_0 your_instance_name (
  .wr_rst_busy(),        // output wire wr_rst_busy
  .rd_rst_busy(),
  .s_aclk(clk),                  // input wire s_aclk
  .s_aresetn(reset),            // input wire s_aresetn
  .s_axis_tvalid(out_valid_rgb),    // input wire s_axis_tvalid
  .s_axis_tdata(out_pixel_rgb),      // input wire [31 : 0] s_axis_tdata
   .s_axis_tready(), // unused bcs axis_prog_full takes care of ready
  .m_axis_tvalid(out_valid),    // output wire m_axis_tvalid
  .m_axis_tready(m_in_ready),    // input wire m_axis_tready
  .m_axis_tdata(out_pixel),      // output wire [31 : 0] m_axis_tdata
  .axis_prog_full(axis_prog_full)  // output wire axis_prog_full
);
endmodule
