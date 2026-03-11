module image_control_param #(
    parameter DATA_W    = 8,     // pixel width (INT8)
    parameter IMG_WIDTH = 512    // image / feature-map width
)(
    input  wire                     clk,
    input  wire                     reset,

    input  wire [DATA_W-1:0]        in_pixel,
    input  wire                     in_valid,

    output wire [9*DATA_W-1:0]      out_pixel,  // 3x3 window
    output wire                     out_valid,
    output reg                      o_intr
);

    // ------------------------------------------
    // Local parameters
    // ------------------------------------------
    localparam PTR_W = $clog2(IMG_WIDTH);// imprtant fix***
    localparam ROW_PIXELS = IMG_WIDTH;
    localparam START_THRESHOLD = 3 * IMG_WIDTH;

    // ------------------------------------------
    // Line buffer outputs (3 horizontal pixels)
    // ------------------------------------------
    wire [3*DATA_W-1:0] line_buf_data [0:3];

    reg  [3:0] buff_valid;
    reg  [3:0] buff_read;

    reg  [PTR_W-1:0] write_pixel_count;
    reg  [1:0]       buff_curr_write;
    reg  [1:0]       buff_curr_read;

    // ------------------------------------------
    // Line buffers
    // ------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : LINE_BUFS
            line_buffer_param #(
                .DATA_W(DATA_W),
                .IMG_WIDTH(IMG_WIDTH)
            ) lb (
                .clk(clk),
                .reset(reset),
                .in_data(in_pixel),
                .valid(buff_valid[i]),
                .read(buff_read[i]),
                .out_data(line_buf_data[i]),
                .end_of_row (rd_state && rd_pixel_count == IMG_WIDTH-1)
            );
        end
    endgenerate

    // ------------------------------------------
    // Write pixel counter
    // ------------------------------------------
    always @(posedge clk) begin
        if (reset)
            write_pixel_count <= 0;
        else if (in_valid) begin
            if (write_pixel_count == IMG_WIDTH-1)
                write_pixel_count <= 0;
            else
                write_pixel_count <= write_pixel_count + 1'b1;
        end
    end


    // ------------------------------------------
    // Rotate write buffer every row
    // ------------------------------------------
    always @(posedge clk) begin
        if (reset)
            buff_curr_write <= 0;
        else if (in_valid && write_pixel_count == IMG_WIDTH-1)
            buff_curr_write <= buff_curr_write + 1'b1;
    end

    // ------------------------------------------
    // Write enables
    // ------------------------------------------
    always @(*) begin
        buff_valid = 4'b0000;
        buff_valid[buff_curr_write] = in_valid;
    end

    // ------------------------------------------
    // Total buffered pixel count
    // ------------------------------------------
    reg [PTR_W+2:0] tot_pixel;
    wire reading = (rd_state == 1'b1);

    always @(posedge clk) begin
        if (reset)
            tot_pixel <= 0;
        else begin
            if (in_valid && !reading)
                tot_pixel <= tot_pixel + 1'b1;
            else if (!in_valid && reading)
                tot_pixel <= tot_pixel - 1'b1;
        end
    end

    // ------------------------------------------
    // Read FSM
    // ------------------------------------------
    reg rd_state;   // 0 = IDLE, 1 = READ
    reg [PTR_W-1:0] rd_pixel_count;

    always @(posedge clk) begin
        if (reset) begin
            rd_state        <= 1'b0;
            rd_pixel_count <= 0;
            o_intr          <= 1'b0;
        end else begin
            case (rd_state)
                1'b0: begin
                    o_intr <= 1'b0;
                    if (tot_pixel >= START_THRESHOLD) begin
                        rd_state        <= 1'b1;
                        rd_pixel_count <= 0;
                    end
                end

                1'b1: begin
                    rd_pixel_count <= rd_pixel_count + 1'b1;
                    if (rd_pixel_count == IMG_WIDTH-1) begin
                        rd_state        <= 1'b0;
                        rd_pixel_count <= 0;
                        o_intr          <= 1'b1;
                    end
                end
            endcase
        end
    end

    // ------------------------------------------
    // Rotate read buffer per row
    // ------------------------------------------
    always @(posedge clk) begin
        if (reset)
            buff_curr_read <= 0;
        else if (rd_state && rd_pixel_count == IMG_WIDTH-1)
            buff_curr_read <= buff_curr_read + 1'b1;
    end

    // ------------------------------------------
    // Read enables (3 buffers active)
    // ------------------------------------------
    always @(*) begin
        buff_read = 4'b0000;
        if (rd_state) begin
            case (buff_curr_read)
                2'b00: buff_read = 4'b0111;
                2'b01: buff_read = 4'b1110;
                2'b10: buff_read = 4'b1101;
                2'b11: buff_read = 4'b1011;
            endcase
        end
    end

    // ------------------------------------------
    // Vertical 3x3 window assembly
    // ------------------------------------------
    reg [9*DATA_W-1:0] out_pixel_reg;

    always @(*) begin
        case (buff_curr_read)
            2'b00: out_pixel_reg = { line_buf_data[0], line_buf_data[1], line_buf_data[2] };
            2'b01: out_pixel_reg = { line_buf_data[1], line_buf_data[2], line_buf_data[3] };
            2'b10: out_pixel_reg = { line_buf_data[2], line_buf_data[3], line_buf_data[0] };
            2'b11: out_pixel_reg = { line_buf_data[3], line_buf_data[0], line_buf_data[1] };
            default: out_pixel_reg = {9*DATA_W{1'b0}};
        endcase
    end

    assign out_pixel = out_pixel_reg;
    assign out_valid = rd_state;

endmodule
