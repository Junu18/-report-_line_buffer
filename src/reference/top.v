module line_buf_ctrl_top (
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

    single_port_ram u_ram11 (
        .clk(),
        .i_cs(),
        .i_we(),
        .i_addr(),
        .i_din(),
        .o_dout()
    );

    single_port_ram u_ram2 (
        .clk(),
        .i_cs(),
        .i_we(),
        .i_addr(),
        .i_din(),
        .o_dout()
    );

    assign o_vsync  = i_vsync  ;
    assign o_hsync  = i_hsync  ;
    assign o_de    = i_de  ;
    assign o_r_data = i_r_data ;
    assign o_g_data = i_g_data ;
    assign o_b_data = i_b_data ;


endmodule
