module line_buffer_param #(
    parameter DATA_W     = 8,    // bits per pixel (INT8)
    parameter IMG_WIDTH  = 512   // image width in pixels
)(
    input  wire                     clk,
    input  wire                     reset,
    input  wire                     end_of_row,

    input  wire [DATA_W-1:0]        in_data,
    input  wire                     valid,
    input  wire                     read,

    output wire [3*DATA_W-1:0]      out_data
);

    // Pointer width (safe for non-power-of-2 widths)
    localparam PTR_W = $clog2(IMG_WIDTH);

    // Line memory
    reg [DATA_W-1:0] line [0:IMG_WIDTH-1];

    reg [PTR_W-1:0] write_ptr;
    reg [PTR_W-1:0] read_ptr;

    // Extended pointer math (prevents overflow)
    wire [PTR_W:0] rp1 = read_ptr + 1'b1;
    wire [PTR_W:0] rp2 = read_ptr + 2'd2;

    // Output 3-pixel horizontal window
    assign out_data =
        (read_ptr <= IMG_WIDTH-3) ?
        { line[read_ptr],
          line[rp1[PTR_W-1:0]],
          line[rp2[PTR_W-1:0]] } :
        {3*DATA_W{1'b0}};   // zero padding at boundary

    always @(posedge clk) begin
        if (reset) begin
            write_ptr <= {PTR_W{1'b0}};
            read_ptr  <= {PTR_W{1'b0}};
        end else begin

            // Write logic with explicit wrap
            if (valid) begin
                line[write_ptr] <= in_data;
                if (write_ptr == IMG_WIDTH-1)
                    write_ptr <= {PTR_W{1'b0}};
                else
                    write_ptr <= write_ptr + 1'b1;
            end

            // Read logic with explicit wrap
            if (end_of_row)
                read_ptr <= {PTR_W{1'b0}};
            else if (read) begin
                if (read_ptr == IMG_WIDTH-1)
                    read_ptr <= {PTR_W{1'b0}};
                else
                    read_ptr <= read_ptr + 1'b1;
            end

        end
    end

endmodule
