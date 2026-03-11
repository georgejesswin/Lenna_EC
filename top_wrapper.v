`timescale 1ns / 1ps

module image_ip
(
    input wire i_top_clk,
    input wire i_top_rst,

    input wire  i_top_cam_start,
    output wire o_top_cam_done,
    input wire [6:0] kernel_sel,

    // Camera
    input wire       i_top_pclk,
    input wire [7:0] i_top_pix_byte,
    input wire       i_top_pix_vsync,
    input wire       i_top_pix_href,
    output wire      o_top_reset,
    output wire      o_top_pwdn,
    output wire      o_top_xclk,
    output wire      o_top_siod,
    output wire      o_top_sioc,

    // VGA
    output wire [3:0] o_top_vga_red,
    output wire [3:0] o_top_vga_green,
    output wire [3:0] o_top_vga_blue,
    output wire       o_top_vga_vsync,
    output wire       o_top_vga_hsync
);

//////////////////////////////////////////////////////////////
// CLOCK GENERATION
//////////////////////////////////////////////////////////////

wire w_clk25m;

clk_wiz_0 clock_gen
(
    .clk_in1(i_top_clk),
    .clk_out1(w_clk25m),
    .clk_out2(o_top_xclk)
);

//////////////////////////////////////////////////////////////
// RESET SYNCHRONIZATION
//////////////////////////////////////////////////////////////

wire w_rst_btn_db;

debouncer
#(.DELAY(240000))
top_btn_db
(
    .i_clk(i_top_clk),
    .i_btn_in(~i_top_rst),
    .o_btn_db(w_rst_btn_db)
);

reg r1_rstn_top_clk,r2_rstn_top_clk;
reg r1_rstn_pclk,r2_rstn_pclk;
reg r1_rstn_clk25m,r2_rstn_clk25m;

always @(posedge i_top_clk or negedge w_rst_btn_db)
begin
    if(!w_rst_btn_db)
        {r2_rstn_top_clk,r1_rstn_top_clk} <= 0;
    else
        {r2_rstn_top_clk,r1_rstn_top_clk} <= {r1_rstn_top_clk,1'b1};
end

always @(posedge i_top_pclk or negedge w_rst_btn_db)
begin
    if(!w_rst_btn_db)
        {r2_rstn_pclk,r1_rstn_pclk} <= 0;
    else
        {r2_rstn_pclk,r1_rstn_pclk} <= {r1_rstn_pclk,1'b1};
end

always @(posedge w_clk25m or negedge w_rst_btn_db)
begin
    if(!w_rst_btn_db)
        {r2_rstn_clk25m,r1_rstn_clk25m} <= 0;
    else
        {r2_rstn_clk25m,r1_rstn_clk25m} <= {r1_rstn_clk25m,1'b1};
end

//////////////////////////////////////////////////////////////
// CAMERA MODULE
//////////////////////////////////////////////////////////////

wire [11:0] cam_pix_data;
wire [18:0] cam_pix_addr;
wire cam_pix_wr;

cam_top
#(.CAM_CONFIG_CLK(100_000_000))
OV7670_cam
(
    .i_clk(i_top_clk),
    .i_rstn_clk(r2_rstn_top_clk),
    .i_rstn_pclk(r2_rstn_pclk),

    .i_cam_start(i_top_cam_start),
    .o_cam_done(o_top_cam_done),

    .i_pclk(i_top_pclk),
    .i_pix_byte(i_top_pix_byte),
    .i_vsync(i_top_pix_vsync),
    .i_href(i_top_pix_href),

    .o_reset(o_top_reset),
    .o_pwdn(o_top_pwdn),
    .o_siod(o_top_siod),
    .o_sioc(o_top_sioc),

    .o_pix_wr(cam_pix_wr),
    .o_pix_data(cam_pix_data),
    .o_pix_addr(cam_pix_addr)
);

//////////////////////////////////////////////////////////////
// RGB444 -> RGB888
//////////////////////////////////////////////////////////////

wire [23:0] proc_in_pixel;

assign proc_in_pixel =
{
    {cam_pix_data[11:8],cam_pix_data[11:8]},
    {cam_pix_data[7:4],cam_pix_data[7:4]},
    {cam_pix_data[3:0],cam_pix_data[3:0]}
};

//////////////////////////////////////////////////////////////
// IMAGE PROCESSING
//////////////////////////////////////////////////////////////

wire [23:0] proc_out_pixel;
wire proc_out_valid;
wire proc_ready;

top_wrapper
#(
    .DATA_W(8),
    .IMG_WIDTH(640)
)
image_processing
(
    .clk(i_top_pclk),

    .reset(r2_rstn_pclk),

    .in_pixel(proc_in_pixel),

    .in_valid(cam_pix_wr & proc_ready),

    .kernel_sel(kernel_sel),

    .s_out_ready(proc_ready),

    .out_pixel(proc_out_pixel),
    .out_valid(proc_out_valid),

    .m_in_ready(1'b1),
    .o_intr()
);

//////////////////////////////////////////////////////////////
// RGB888 -> RGB444
//////////////////////////////////////////////////////////////

wire [11:0] proc_out_rgb444;

assign proc_out_rgb444 =
{
    proc_out_pixel[23:20],
    proc_out_pixel[15:12],
    proc_out_pixel[7:4]
};

//////////////////////////////////////////////////////////////
// WRITE ADDRESS GENERATION
//////////////////////////////////////////////////////////////

reg [18:0] wr_addr;

always @(posedge i_top_pclk or negedge r2_rstn_pclk)
begin
    if(!r2_rstn_pclk)
        wr_addr <= 0;

    else if(i_top_pix_vsync)
        wr_addr <= 0;

    else if(proc_out_valid)
        wr_addr <= wr_addr + 1'b1;
end

//////////////////////////////////////////////////////////////
// FRAME BUFFER BRAM
//////////////////////////////////////////////////////////////

wire [11:0] o_bram_pix_data;
wire [18:0] o_bram_pix_addr;

mem_bram
#(
    .WIDTH(12),
    .DEPTH(640*480)
)
pixel_memory
(
    .i_wclk(i_top_pclk),
    .i_wr(proc_out_valid),
    .i_wr_addr(wr_addr),
    .i_bram_data(proc_out_rgb444),
    .i_bram_en(1'b1),

    .i_rclk(w_clk25m),
    .i_rd(1'b1),
    .i_rd_addr(o_bram_pix_addr),
    .o_bram_data(o_bram_pix_data)
);

//////////////////////////////////////////////////////////////
// VGA CONTROLLER
//////////////////////////////////////////////////////////////
wire X;
wire Y;
vga_top
display_interface
(
    .i_clk25m(w_clk25m),
    .i_rstn_clk25m(r2_rstn_clk25m),

    .o_VGA_x(X),
    .o_VGA_y(Y),
    .o_VGA_vsync(o_top_vga_vsync),
    .o_VGA_hsync(o_top_vga_hsync),
    .o_VGA_video(),

    .o_VGA_red(o_top_vga_red),
    .o_VGA_green(o_top_vga_green),
    .o_VGA_blue(o_top_vga_blue),

    .i_pix_data(o_bram_pix_data),
    .o_pix_addr(o_bram_pix_addr)
);

endmodule