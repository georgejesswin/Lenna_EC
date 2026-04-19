module image_process_wrapper#(
    parameter DATA_W = 8,
    parameter IMG_WIDTH = 512,
    parameter ACC_W = 32,
    parameter BRIGHT_VAL = 32 // Fixed amount for brightness adjustment
)(
    input clk,
    input reset,// Active Lo
    input [(DATA_W*3)-1:0] in_pixel,
    input in_valid,
    input [6:0] kernel_sel,
    input wire neg,
    input wire gray_scale,
    input wire red_off,
    input wire blue_off,
    input wire green_off,
    input wire bright,             // Brightness increase
    input wire dim,                // Brightness decrease
    input wire thermal_en,         
    input wire sepia_en,           
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
    // FIX: Removed thermal_en to prevent valid glitching
    .in_valid(in_valid && (edge_mode || gray_image)), 
    .gray_pixel(gray_pixel),
    .out_valid(gray_valid)
);

// FIX: Removed thermal_en from front-end routing
wire use_gray = edge_mode || gray_image;

// 2. Update IMC_B
image_control_param #(
    .DATA_W(DATA_W),
    .IMG_WIDTH(IMG_WIDTH)
)IMC_B (
    .clk(clk),
    .reset(~reset),
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

// FIX: Reverted valid routing to rely solely on the stable hardware paths
wire out_valid_rgb = edge_mode ? sobel_valid : 
                     gray_image ? gray_rgb_valid : 
                     (out_valid_conv[0] && out_valid_conv[1] && out_valid_conv[2]);

// ==========================================
// CHANNEL MASKING
// ==========================================
wire [DATA_W-1:0] red_mask   = red_off   ? {DATA_W{1'b0}} : out_pixel_conv[2];
wire [DATA_W-1:0] green_mask = green_off ? {DATA_W{1'b0}} : out_pixel_conv[1];
wire [DATA_W-1:0] blue_mask  = blue_off  ? {DATA_W{1'b0}} : out_pixel_conv[0];

// ==========================================
// SEPIA TONE (Shift-and-Add)
// ==========================================
wire [DATA_W+1:0] sep_r_add = red_mask + (green_mask >> 1) + (blue_mask >> 2);
wire [DATA_W+1:0] sep_g_add = (red_mask >> 1) + (green_mask >> 1) + (blue_mask >> 3);
wire [DATA_W+1:0] sep_b_add = (red_mask >> 2) + (green_mask >> 2) + (blue_mask >> 2);

wire [DATA_W-1:0] sep_r = (sep_r_add > {DATA_W{1'b1}}) ? {DATA_W{1'b1}} : sep_r_add[DATA_W-1:0];
wire [DATA_W-1:0] sep_g = (sep_g_add > {DATA_W{1'b1}}) ? {DATA_W{1'b1}} : sep_g_add[DATA_W-1:0];
wire [DATA_W-1:0] sep_b = (sep_b_add > {DATA_W{1'b1}}) ? {DATA_W{1'b1}} : sep_b_add[DATA_W-1:0];

wire [DATA_W-1:0] r_pre_bright = sepia_en ? sep_r : red_mask;
wire [DATA_W-1:0] g_pre_bright = sepia_en ? sep_g : green_mask;
wire [DATA_W-1:0] b_pre_bright = sepia_en ? sep_b : blue_mask;

// ==========================================
// BRIGHTNESS CONTROL
// ==========================================
wire [DATA_W:0] r_add = r_pre_bright + BRIGHT_VAL;
wire [DATA_W:0] g_add = g_pre_bright + BRIGHT_VAL;
wire [DATA_W:0] b_add = b_pre_bright + BRIGHT_VAL;

wire [DATA_W-1:0] r_bright = (r_add > {DATA_W{1'b1}}) ? {DATA_W{1'b1}} : r_add[DATA_W-1:0];
wire [DATA_W-1:0] g_bright = (g_add > {DATA_W{1'b1}}) ? {DATA_W{1'b1}} : g_add[DATA_W-1:0];
wire [DATA_W-1:0] b_bright = (b_add > {DATA_W{1'b1}}) ? {DATA_W{1'b1}} : b_add[DATA_W-1:0];

wire [DATA_W-1:0] r_dim = (r_pre_bright > BRIGHT_VAL) ? (r_pre_bright - BRIGHT_VAL) : {DATA_W{1'b0}};
wire [DATA_W-1:0] g_dim = (g_pre_bright > BRIGHT_VAL) ? (g_pre_bright - BRIGHT_VAL) : {DATA_W{1'b0}};
wire [DATA_W-1:0] b_dim = (b_pre_bright > BRIGHT_VAL) ? (b_pre_bright - BRIGHT_VAL) : {DATA_W{1'b0}};

wire [DATA_W-1:0] r_final = bright ? r_bright : (dim ? r_dim : r_pre_bright);
wire [DATA_W-1:0] g_final = bright ? g_bright : (dim ? g_dim : g_pre_bright);
wire [DATA_W-1:0] b_final = bright ? b_bright : (dim ? b_dim : b_pre_bright);

// ==========================================
// THERMAL / HEATMAP VISION
// ==========================================
// Uses a fast hardware approximation of Luminosity: I = (R/4) + (G/2) + (B/4)
wire [DATA_W-1:0] therm_intensity = gray_image ? out_pixel_gray[DATA_W-1:0] : 
                                    ((r_final >> 2) + (g_final >> 1) + (b_final >> 2));

wire [DATA_W-1:0] therm_r, therm_g, therm_b;

assign therm_r = (therm_intensity > 8'd170) ? 8'hFF :
                 (therm_intensity > 8'd85)  ? 8'h80 : 8'h00; 

assign therm_g = (therm_intensity > 8'd170) ? 8'h40 :        
                 (therm_intensity > 8'd85)  ? 8'hFF : 8'h80; 

assign therm_b = (therm_intensity > 8'd170) ? 8'h00 :
                 (therm_intensity > 8'd85)  ? 8'h00 : 8'hFF; 

wire [(DATA_W*3)-1:0] therm_rgb = {therm_r, therm_g, therm_b};

// ==========================================
// OUTPUT ROUTING
// ==========================================
wire [(DATA_W*3)-1:0] rgb =  {r_final, g_final, b_final};                                

wire [(DATA_W*3)-1:0] out_pixel_rgb = 
    edge_mode  ? out_pixel_sobel : 
    thermal_en ? therm_rgb : 
    gray_image ? out_pixel_gray : rgb;

fifo_generator_0 your_instance_name (
  .wr_rst_busy(),        
  .rd_rst_busy(),
  .s_aclk(clk),                  
  .s_aresetn(reset),            
  .s_axis_tvalid(out_valid_rgb),    
  .s_axis_tdata(out_pixel_rgb),      
   .s_axis_tready(), 
  .m_axis_tvalid(out_valid),    
  .m_axis_tready(m_in_ready),    
  .m_axis_tdata(out_pixel),      
  .axis_prog_full(axis_prog_full)  
);
endmodule
