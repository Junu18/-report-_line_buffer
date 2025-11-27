
module single_port_ram #(
  parameter					ADDR_WIDTH = 6,   // 이거를 몇 으로 해야 내가 만들 수있는 rebolution을 구현 할 수있겠는가 
  // 내부에서도 파라미터를 바꿔도 되지만 외부에서도 파라미터를 바꿀 수 있고
  // ram을 만든다기 보다는 우리가 어떻게 line_buffer_controller를 만들어서 ram을 다루는지가 중요하다
  // ram 컨트롤을 어떻게 하는지가 중요하다.
  // ram 사이즈는 6으로 고정해서 사용한다.
  // 기존에 사용하던 환경에서 그것 이상의 사이즈를 지원한다면, (사이즈) // 비바도에서 구현 하는 것도 가능은 하다.
  parameter					DATA_WIDTH = 30,
  parameter					RAM_DEPTH = 1 << ADDR_WIDTH
)
  (
    input						clk,
    input						i_cs,
    input						i_we,
    input	[ADDR_WIDTH-1:0]	i_addr,
    input	[DATA_WIDTH-1:0]	i_din,
    output	[DATA_WIDTH-1:0]	o_dout
  );

  
    reg [DATA_WIDTH-1:0]    r_mem   [0:RAM_DEPTH-1];
    reg [DATA_WIDTH-1:0]    r_tmp_data;

    // output : when cs=1, we=0
  assign o_dout = (i_cs && !i_we) ? r_tmp_data : 'b0;

    // Memory write input
    // cs=1, we=1
    always @(posedge clk) begin
        if (i_cs && i_we) 
            r_mem[i_addr] <= i_din;
    end

    // Memory read input
    // cs=1, we=0
    always @(posedge clk) begin
        if (i_cs && !i_we)
            r_tmp_data <= r_mem[i_addr];
    end
  
endmodule