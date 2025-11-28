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
    // Local Parameters
    //===========================================================================
    localparam ADDR_WIDTH = $clog2(HACT);  // Address width for RAM

    //===========================================================================
    // Internal Signals - RAM Control
    //===========================================================================
    wire        ram0_cs, ram1_cs;
    wire        ram0_we, ram1_we;
    wire [ADDR_WIDTH-1:0] ram0_addr, ram1_addr;
    wire [29:0] ram0_din, ram1_din;
    wire [29:0] ram0_dout, ram1_dout;

    //===========================================================================
    // Line Buffer Controller Instance
    //===========================================================================
    line_buf_ctrl #(
        .HTOT(HTOT),
        .HACT(HACT)
    ) u_line_buf_ctrl (
        .clk        (clk),
        .rstn       (rstn),
        .i_vsync    (i_vsync),
        .i_hsync    (i_hsync),
        .i_de       (i_de),
        .i_r_data   (i_r_data),
        .i_g_data   (i_g_data),
        .i_b_data   (i_b_data),

        // RAM 0 control
        .o_ram0_cs  (ram0_cs),
        .o_ram0_we  (ram0_we),
        .o_ram0_addr(ram0_addr),
        .o_ram0_din (ram0_din),
        .i_ram0_dout(ram0_dout),

        // RAM 1 control
        .o_ram1_cs  (ram1_cs),
        .o_ram1_we  (ram1_we),
        .o_ram1_addr(ram1_addr),
        .o_ram1_din (ram1_din),
        .i_ram1_dout(ram1_dout),

        // Outputs
        .o_vsync    (o_vsync),
        .o_hsync    (o_hsync),
        .o_de       (o_de),
        .o_r_data   (o_r_data),
        .o_g_data   (o_g_data),
        .o_b_data   (o_b_data)
    );

    //===========================================================================
    // SRAM1 (RAM 0) Instance
    //===========================================================================
    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(30),
        .RAM_DEPTH(1 << ADDR_WIDTH)
    ) u_sram1 (
        .clk    (clk),
        .i_cs   (ram0_cs),
        .i_we   (ram0_we),
        .i_addr (ram0_addr),
        .i_din  (ram0_din),
        .o_dout (ram0_dout)
    );

    //===========================================================================
    // SRAM2 (RAM 1) Instance
    //===========================================================================
    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(30),
        .RAM_DEPTH(1 << ADDR_WIDTH)
    ) u_sram2 (
        .clk    (clk),
        .i_cs   (ram1_cs),
        .i_we   (ram1_we),
        .i_addr (ram1_addr),
        .i_din  (ram1_din),
        .o_dout (ram1_dout)
    );

endmodule
