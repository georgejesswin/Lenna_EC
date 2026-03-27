module sobel_edge_stream_rgb #(
    parameter DATA_W = 8,
    parameter THRESHOLD = 9'd80
)(
    input clk,
    input reset,

    input  [DATA_W-1:0] sobel_x,
    input  [DATA_W-1:0] sobel_y,
    input  in_valid,

    output reg [(DATA_W*3)-1:0] out_pixel,
    output reg out_valid
);

wire [DATA_W:0] magnitude;
wire [DATA_W-1:0] edge_val;

// magnitude calculation (9-bit to prevent overflow)
assign magnitude = sobel_x + sobel_y;

// threshold comparison
assign edge_val = (magnitude > THRESHOLD) ? {DATA_W{1'b1}} : {DATA_W{1'b0}};

always @(posedge clk) begin
    if(reset) begin
        out_pixel <= 0;
        out_valid <= 0;
    end
    else begin
        if(in_valid)
            out_pixel <= {edge_val, edge_val, edge_val};
        else
            out_pixel <= 0;

        out_valid <= in_valid;
    end
end

endmodule