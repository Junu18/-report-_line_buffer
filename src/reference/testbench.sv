`include "clk_gen.sv"

module testbench;

  reg  r_rst_n  ;
  reg  r_clk_en ;
  wire w_pclk   ;
  
  // clock generation
  clk_gen  #(
    .FREQ		(10**9    ),
    .DUTY		(60       ),
    .PHASE		(0        )
  ) u_clk_gen (
    .i_clk_en	(r_clk_en ),
    .o_clk		(w_pclk   )
  );

  wire    		   w_vsync, w_hsync, w_de ;
  wire    [9:0]    w_red, w_green, w_blue ;

  // user setting
  parameter VSYNC_POL = 0  ; // Vsync Polarity. 0: Active High, 1: Active Low
  parameter HSYNC_POL = 0  ; // Hsync Polarity. 0: Active High, 1: Active Low
  parameter VSW  	  = 1  ; // Vertical Sync Width [line]
  parameter VBP  	  = 1  ; // Vertical Back Porch [line]
  parameter VACT 	  = 4  ; // Vertical Active [line]
  parameter VFP  	  = 1  ; // Vertical Front Porch [line]
  parameter HSW  	  = 1  ; // Horizontal Sync Width [clock]
  parameter HBP  	  = 2  ; // Horizontal Back Porch [clock]
  parameter HACT 	  = 10 ; // Horizontal Active [clock]
  parameter HFP  	  = 2  ; // Horizontal Front Porch [clock]
// auto setting
  parameter VTOT 	  = VSW + VBP + VACT + VFP ; // Vertical Total [line]
  parameter HTOT 	  = HSW + HBP + HACT + HFP ; // Horizontal Total [Clock]
  
  `include "sync_gen.sv"

  
   line_buf_ctrl_top #(
    .HTOT       (HTOT    ),
    .HACT       (HACT    )
   ) u_line_buf_ctrl_top(
    .clk        (w_pclk  ),
    .rstn       (r_rst_n ),
    .i_vsync    (r_vsync ),
    .i_hsync    (r_hsync ),
    .i_de       (r_de    ),
    .i_r_data   (r_red   ),
    .i_g_data   (r_green ),
    .i_b_data   (r_blue  ),
    .o_vsync    (w_vsync ),
    .o_hsync    (w_hsync ),
    .o_de       (w_de    ),
    .o_r_data   (w_red   ),
    .o_g_data   (w_green ),
    .o_b_data   (w_blue  )
   );
  
  initial begin
    r_rst_n  <= 0 ;
    r_clk_en <= 1 ;
    testbench.u_clk_gen.clk_disp();
    
    #(20ns)
    r_rst_n  <= 1 ;
    
    repeat(10) @(posedge w_pclk);
    
    //task_nline_send(1)   ;
    task_nframe_send(10) ;
    
    repeat (100) @(posedge w_pclk); 
    $finish;
  end
  
  // wave dump
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, testbench);
  end
  
  
endmodule


