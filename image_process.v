module image_process_wrapper#(
    parameter DATA_W = 8,
    parameter IMG_WIDTH = 512,
    parameter ACC_W = 32
)(
    input clk,
    input reset,// Active Lo
    input [(DATA_W*3)-1:0] in_pixel,
    input in_valid,
    input [6:0] kernel_sel,
    input wire neg,
    input wire gray_scale,
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
wire  signed [9*DATA_W-1:0] kernel_alt;
wire o_intr_loc [0:2];
wire edge_mode=kernel_sel[6];
wire gray_image=gray_scale;
assign s_out_ready=~axis_prog_full;
wire [DATA_W-1:0] gray_pixel;
wire gray_valid;
rgb2gray #(
        .DATA_W(DATA_W)

) RGB_GRY(
     .clk(clk),
    .reset(~reset),
    .in_pixel(in_pixel),
    .in_valid(in_valid&&(edge_mode||gray_image)), 
    .gray_pixel(gray_pixel),
    .out_valid(gray_valid)
    
);
// 1. Create a unified control signal
wire use_gray = edge_mode || gray_image;

// 2. Update IMC_B
image_control_param #(
    .DATA_W(DATA_W),
    .IMG_WIDTH(IMG_WIDTH)
)IMC_B (
    .clk(clk),
    .reset(~reset),
    // Pass gray pixel and valid to ALL channels if use_gray is high
    .in_pixel(use_gray ? gray_pixel : in_pixel[DATA_W-1:0]),
    .in_valid(use_gray ? gray_valid : in_valid),
    .out_pixel(out_72[0]), 
    .out_valid(out_valid_contr[0]),
    .o_intr(o_intr_loc[0])
);

// 3. Update IMC_G
image_control_param #(
    .DATA_W(DATA_W),
    .IMG_WIDTH(IMG_WIDTH)
)IMC_G (
    .clk(clk),
    .reset(~reset),
    .in_pixel(use_gray ? gray_pixel : in_pixel[2*DATA_W-1:DATA_W]),
    .in_valid(use_gray ? gray_valid : in_valid),
    .out_pixel(out_72[1]), 
    .out_valid(out_valid_contr[1]),
    .o_intr(o_intr_loc[1])
);

// 4. Update IMC_R
image_control_param #(
    .DATA_W(DATA_W),
    .IMG_WIDTH(IMG_WIDTH)
)IMC_R (
    .clk(clk),
    .reset(~reset),
    .in_pixel(use_gray ? gray_pixel : in_pixel[3*DATA_W-1:2*DATA_W]),
    .in_valid(use_gray ? gray_valid : in_valid),
    .out_pixel(out_72[2]), 
    .out_valid(out_valid_contr[2]),
    .o_intr(o_intr_loc[2])
);
wire [7:0] norm_factor;
kernel_selector KER(
    .kernel_sel(kernel_sel),
    .kernel_out(kernel_out),
    .norm_factor(norm_factor),
    .kernel_alt(kernel_alt)
    
);
conv3x3#(
    .DATA_W(DATA_W),
    .ACC_W(ACC_W)
) CONV_B(
     .clk(clk),
    .in_pixel(out_72[0]),
    .kernel(kernel_out),
    .norm_factor(norm_factor),
    .negative(neg),
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
    .kernel(edge_mode?kernel_alt:kernel_out),
    .norm_factor(norm_factor),
    .negative(neg),
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
    .negative(neg),
    .pixel_valid(out_valid_contr[2]),
    .out_pixel(out_pixel_conv[2]),
    .out_valid(out_valid_conv[2])
);
assign o_intr=o_intr_loc[0] || o_intr_loc[1] || o_intr_loc[2];
wire [(DATA_W*3)-1:0] out_pixel_sobel,out_pixel_gray;
wire sobel_valid,gray_rgb_valid;
gray2rgb#(
    .DATA_W(DATA_W)

) GR_RGB(
       .clk(clk),
    .reset(~reset),
    .gray_pixel(out_pixel_conv[2]),
    .in_valid(out_valid_conv[2]),
    .rgb_pixel(out_pixel_gray),
    .out_valid(gray_rgb_valid)



);
sobel_edge_stream_rgb#(
    .DATA_W(DATA_W),
    .THRESHOLD(9'd80)
) SOB (    
    .clk(clk),
    .reset(~reset),
    .sobel_x(out_pixel_conv[0]),
    .sobel_y(out_pixel_conv[1]),
    .in_valid(out_valid_conv[0] && out_valid_conv[1]),
    .out_pixel(out_pixel_sobel),
    .out_valid(sobel_valid)
);
wire out_valid_rgb=edge_mode?sobel_valid:gray_image?gray_rgb_valid:out_valid_conv[0] && out_valid_conv[1] && out_valid_conv[2];
wire [(DATA_W*3)-1:0] out_pixel_rgb= edge_mode?out_pixel_sobel:gray_image?out_pixel_gray: {out_pixel_conv[2],out_pixel_conv[1],out_pixel_conv[0]};
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
