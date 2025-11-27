module clk_gen #(
  parameter FREQ = 1*(10**9), // [Hz]. default: 1G[Hz]
  parameter DUTY = 50,        // [Percentage]. default: 50[%]
  parameter PHASE = 0		  // [Degrees]. 0, 90, 180, 270. default: 0
)(
  input      i_clk_en,
  output reg o_clk
);
  
  real t_clk_pd 	= (1.0 / FREQ) * 10**9; // *clk_pd : clock period [ns]
  real t_clk_h 	    = DUTY/100.0 * t_clk_pd; // *clk_h : 1'clock high time [ns]
  real t_clk_l	    = (100.0 - DUTY)/100.0 * t_clk_pd; // *clk_l : 1'clock low time [ns]
  real t_quarter	= t_clk_pd/4; // [ns]
  real t_start_dly	= t_quarter * PHASE/90; // [ns]
  
  reg r_clk_en_d; // clock enable delay
  
  always @(i_clk_en) begin
    if (i_clk_en) begin
      #(t_start_dly) r_clk_en_d = 1;
    end else begin
      #(t_start_dly) r_clk_en_d = 0;
    end      
  end
  
  always @(r_clk_en_d) begin
    while (r_clk_en_d) begin
      #(t_clk_l)	o_clk = 1;
      #(t_clk_h)	o_clk = 0;
    end
  end 
  
  initial begin
    r_clk_en_d <= 0;
    o_clk <= 0;
  end
  
  task clk_disp;
    $display("FREQ  =\t %-6d [MHz]", FREQ/(10**6));
    $display("DUTY  =\t %-6d [%%]",  DUTY);
    $display("PHASE =\t %-6d [deg]", PHASE);
    
    $display("PERIOD           = %0.3f [ns]", t_clk_pd);    
    $display("CLK_High Time    = %0.3f [ns]", t_clk_h);
    $display("CLK_Low Time     = %0.3f [ns]", t_clk_l);
    $display("QUARTER          = %0.3f [ns]", t_quarter);
    $display("START_DLY        = %0.3f [ns]", t_start_dly);
  endtask
  
endmodule
