module gray2rgb #(
    parameter DATA_W = 8
)(
    input clk,
    input reset,

    input  [DATA_W-1:0] gray_pixel,
    input  in_valid,

    output reg [(DATA_W*3)-1:0] rgb_pixel,
    output reg out_valid
);

always @(posedge clk) begin
    if(reset) begin
        rgb_pixel <= 0;
        out_valid <= 0;
    end
    else begin
        if(in_valid)
            rgb_pixel <= {gray_pixel, gray_pixel, gray_pixel};
        else
            rgb_pixel <= 0;   // optional clearing

        out_valid <= in_valid;
    end
end

endmodule