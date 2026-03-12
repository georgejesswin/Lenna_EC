module kernel_selector (
    input  wire [6:0] kernel_sel,  
    output reg  signed [71:0] kernel_out,
    output reg  [7:0] norm_factor,    // normalization divisor
    output reg signed [71:0] kernel_alt
);

    // =========================================================
    // 8-bit Signed Kernel Coefficients (3x3 flattened)
    // =========================================================

    localparam signed [71:0] K_IDENTITY = {
        8'sd0, 8'sd0, 8'sd0,
        8'sd0, 8'sd1, 8'sd0,
        8'sd0, 8'sd0, 8'sd0
    };

    localparam signed [71:0] K_SOBEL_X = {
        -8'sd1, 8'sd0,  8'sd1,
        -8'sd2, 8'sd0,  8'sd2,
        -8'sd1, 8'sd0,  8'sd1
    };

    localparam signed [71:0] K_SOBEL_Y = {
        -8'sd1, -8'sd2, -8'sd1,
         8'sd0,  8'sd0,  8'sd0,
         8'sd1,  8'sd2,  8'sd1
    };

    localparam signed [71:0] K_SHARPEN = {
         8'sd0, -8'sd1,  8'sd0,
        -8'sd1,  8'sd5, -8'sd1,
         8'sd0, -8'sd1,  8'sd0
    };

    localparam signed [71:0] K_BOX = {
        8'sd1, 8'sd1, 8'sd1,
        8'sd1, 8'sd1, 8'sd1,
        8'sd1, 8'sd1, 8'sd1
    };

    localparam signed [71:0] K_GAUSS = {
        8'sd1, 8'sd2, 8'sd1,
        8'sd2, 8'sd4, 8'sd2,
        8'sd1, 8'sd2, 8'sd1
    };

    // =========================================================
    // Selection Logic
    // =========================================================
    always @(*) begin
        // Default
        kernel_out  = K_IDENTITY;
        kernel_alt = K_IDENTITY;
        norm_factor = 8'd1;

        case (1'b1)
            kernel_sel[6]: begin
                kernel_out  = K_SOBEL_X;
                norm_factor = 8'd1;  // sum = 1
                kernel_alt = K_SOBEL_Y;
            end
            kernel_sel[5]: begin
                kernel_out  = K_SHARPEN;
                norm_factor = 8'd1;  // sum = 1
            end

            kernel_sel[4]: begin
                kernel_out  = K_SOBEL_Y;
                norm_factor = 8'd1;  // gradient (no normalization)
            end

            kernel_sel[3]: begin
                kernel_out  = K_SOBEL_X;
                norm_factor = 8'd1;
            end

            kernel_sel[2]: begin
                kernel_out  = K_GAUSS;
                norm_factor = 8'd16; // sum of gaussian
            end

            kernel_sel[1]: begin
                kernel_out  = K_BOX;
                norm_factor = 8'd9;  // average
            end

            kernel_sel[0]: begin
                kernel_out  = K_IDENTITY;
                norm_factor = 8'd1;
            end
        endcase
    end
    

endmodule
