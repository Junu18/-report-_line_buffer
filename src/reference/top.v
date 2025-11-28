module line_buf_ctrl_top #(
    parameter HTOT = 15,  // Horizontal total pixels per line (HSW+HBP+HACT+HFP)
    parameter HACT = 10   // Horizontal active pixels
)(
    input             clk,
    input             rstn,
    input             i_vsync,
    input             i_hsync,
    input             i_de,
    input       [9:0] i_r_data,
    input       [9:0] i_g_data,
    input       [9:0] i_b_data,
    output wire       o_vsync,
    output wire       o_hsync,
    output wire       o_de,
    output wire [9:0] o_r_data,
    output wire [9:0] o_g_data,
    output wire [9:0] o_b_data
);

    //===========================================================================
    // Local Parameters & Signal Declarations
    //===========================================================================
    localparam DELAY_CYCLES = 2 * HTOT;  // 2 line delay
    localparam ADDR_WIDTH = $clog2(HACT);  // Address width for RAM

    // State encoding
    localparam [1:0] ST_LINE0_WR    = 2'b00;  // Writing to Line 0
    localparam [1:0] ST_LINE1_WR    = 2'b01;  // Writing to Line 1
    localparam [1:0] ST_LINE0_WR_RD = 2'b10;  // Write to Line 0, Read from Line 1
    localparam [1:0] ST_LINE1_WR_RD = 2'b11;  // Write to Line 1, Read from Line 0

    reg [1:0] state, state_n;

    // Sync delay shift registers (2 line delay)
    reg [DELAY_CYCLES-1:0] vsync_delay;
    reg [DELAY_CYCLES-1:0] hsync_delay;
    reg [DELAY_CYCLES-1:0] de_delay;

    // Line buffer control signals
    reg [ADDR_WIDTH-1:0] wr_addr, rd_addr;
    reg [ADDR_WIDTH-1:0] pixel_cnt;

    // RAM control signals
    wire        ram0_cs, ram1_cs;
    wire        ram0_we, ram1_we;
    wire [ADDR_WIDTH-1:0] ram0_addr, ram1_addr;
    wire [29:0] ram0_din, ram1_din;
    wire [29:0] ram0_dout, ram1_dout;

    // Edge detection for line change
    reg i_hsync_d;
    wire hsync_fall;

    // Data packing/unpacking
    wire [29:0] write_data;
    reg  [29:0] read_data;

    //===========================================================================
    // Edge Detection - detect end of line (hsync falling edge)
    //===========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            i_hsync_d <= 1'b0;
        end else begin
            i_hsync_d <= i_hsync;
        end
    end

    assign hsync_fall = i_hsync_d & ~i_hsync;

    //===========================================================================
    // Sync Signal Delay (2 line delay = 2 * HTOT clocks)
    //===========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            vsync_delay <= {DELAY_CYCLES{1'b0}};
            hsync_delay <= {DELAY_CYCLES{1'b0}};
            de_delay    <= {DELAY_CYCLES{1'b0}};
        end else begin
            vsync_delay <= {vsync_delay[DELAY_CYCLES-2:0], i_vsync};
            hsync_delay <= {hsync_delay[DELAY_CYCLES-2:0], i_hsync};
            de_delay    <= {de_delay[DELAY_CYCLES-2:0], i_de};
        end
    end

    assign o_vsync = vsync_delay[DELAY_CYCLES-1];
    assign o_hsync = hsync_delay[DELAY_CYCLES-1];
    assign o_de    = de_delay[DELAY_CYCLES-1];

    //===========================================================================
    // State Machine - Line Buffer Control
    //===========================================================================
    // State register
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= ST_LINE0_WR;
        end else begin
            state <= state_n;
        end
    end

    // Next state logic
    always @(*) begin
        state_n = state;

        case (state)
            ST_LINE0_WR: begin
                if (hsync_fall) begin
                    state_n = ST_LINE1_WR;
                end
            end

            ST_LINE1_WR: begin
                if (hsync_fall) begin
                    state_n = ST_LINE0_WR_RD;
                end
            end

            ST_LINE0_WR_RD: begin
                if (hsync_fall) begin
                    state_n = ST_LINE1_WR_RD;
                end
            end

            ST_LINE1_WR_RD: begin
                if (hsync_fall) begin
                    state_n = ST_LINE0_WR_RD;
                end
            end

            default: state_n = ST_LINE0_WR;
        endcase

        // Reset on vsync
        if (i_vsync) begin
            state_n = ST_LINE0_WR;
        end
    end

    //===========================================================================
    // Pixel Counter (Address Generation)
    //===========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            pixel_cnt <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (i_vsync || hsync_fall) begin
                pixel_cnt <= {ADDR_WIDTH{1'b0}};
            end else if (i_de) begin
                pixel_cnt <= pixel_cnt + 1'b1;
            end
        end
    end

    // Write/Read address assignment
    always @(*) begin
        wr_addr = pixel_cnt;
        rd_addr = pixel_cnt;
    end

    //===========================================================================
    // RAM Control Signal Generation
    //===========================================================================
    assign write_data = {i_r_data, i_g_data, i_b_data};

    // RAM 0 control
    assign ram0_cs = 1'b1;  // Always enabled
    assign ram0_we = (state == ST_LINE0_WR || state == ST_LINE0_WR_RD) ? i_de : 1'b0;
    assign ram0_addr = ram0_we ? wr_addr : rd_addr;
    assign ram0_din = write_data;

    // RAM 1 control
    assign ram1_cs = 1'b1;  // Always enabled
    assign ram1_we = (state == ST_LINE1_WR || state == ST_LINE1_WR_RD) ? i_de : 1'b0;
    assign ram1_addr = ram1_we ? wr_addr : rd_addr;
    assign ram1_din = write_data;

    //===========================================================================
    // Read Data Selection
    //===========================================================================
    always @(*) begin
        case (state)
            ST_LINE0_WR_RD: read_data = ram1_dout;  // Read from RAM 1
            ST_LINE1_WR_RD: read_data = ram0_dout;  // Read from RAM 0
            default:        read_data = 30'b0;
        endcase
    end

    assign o_r_data = read_data[29:20];
    assign o_g_data = read_data[19:10];
    assign o_b_data = read_data[9:0];

    //===========================================================================
    // RAM Instances
    //===========================================================================
    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(30),
        .RAM_DEPTH(1 << ADDR_WIDTH)
    ) u_ram0 (
        .clk(clk),
        .i_cs(ram0_cs),
        .i_we(ram0_we),
        .i_addr(ram0_addr),
        .i_din(ram0_din),
        .o_dout(ram0_dout)
    );

    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(30),
        .RAM_DEPTH(1 << ADDR_WIDTH)
    ) u_ram1 (
        .clk(clk),
        .i_cs(ram1_cs),
        .i_we(ram1_we),
        .i_addr(ram1_addr),
        .i_din(ram1_din),
        .o_dout(ram1_dout)
    );

endmodule
