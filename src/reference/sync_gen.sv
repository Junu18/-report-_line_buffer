//------------------------------------------------
// Sync Generator TB Task
//------------------------------------------------

typedef enum int {
    ST_IDLE = 0,
    ST_SW   = 1,
    ST_BP   = 2,
    ST_ACT  = 3,
    ST_FP   = 4,
    ST_END  = 5
} state_t;

reg [2:0] r_vstate    = ST_IDLE; 
reg [2:0] r_hstate    = ST_IDLE; 

reg       r_vsync     = 0;
reg       r_hsync     = 0;
reg       r_de        = 0;
reg [9:0] r_red       = 0;
reg [9:0] r_green     = 0;
reg [9:0] r_blue      = 0;

int r_frame_cnt     = 0;
int r_vstate_cnt    = 0;
int r_hstate_cnt    = 0;

int r_hsw_cnt       = 0;
int r_hbp_cnt       = 0;
int r_hfp_cnt       = 0;
int r_hact_cnt      = 0;

int r_vsw_cnt       = 0;
int r_vbp_cnt       = 0;
int r_vfp_cnt       = 0;
int r_vact_cnt      = 0;

state_t cur_vstate;
state_t cur_hstate;

//------------------------------------------------
// Initialization (Polarity Setup)
//------------------------------------------------
initial begin
    if (VSYNC_POL == 0) r_vsync = 0;
    else                r_vsync = 1;

    if (HSYNC_POL == 0) r_hsync = 0;
    else                r_hsync = 1;
end

//------------------------------------------------
// [Core Task] Signal Drive and Counter Management
//------------------------------------------------
task task_drive_signal(
    input bit   i_vsync,
    input bit   i_hsync,
    input bit   i_de,
    input logic [9:0] i_r,
    input logic [9:0] i_g,
    input logic [9:0] i_b
);
    @(posedge w_pclk);

    r_vsync     <= (VSYNC_POL == 0) ? i_vsync : ~i_vsync;
    r_hsync     <= (HSYNC_POL == 0) ? i_hsync : ~i_hsync;
    r_de        <= i_de;
    r_red       <= i_r;
    r_green     <= i_g;
    r_blue      <= i_b;

    r_vstate    <= cur_vstate;
    r_hstate    <= cur_hstate;

    if (cur_hstate == ST_SW)       r_hsw_cnt++;
    else if (cur_hstate == ST_BP)  r_hbp_cnt++;
    else if (cur_hstate == ST_ACT) r_hact_cnt++;
    else if (cur_hstate == ST_FP)  r_hfp_cnt++;

    if (cur_vstate == ST_SW)       r_vsw_cnt++;
    else if (cur_vstate == ST_BP)  r_vbp_cnt++;
    else if (cur_vstate == ST_ACT) r_vact_cnt++;
    else if (cur_vstate == ST_FP)  r_vfp_cnt++;
    
    r_hstate_cnt++; 
    r_vstate_cnt++; 
endtask

//------------------------------------------------
// [Reset Task] Reset Horizontal Counters
//------------------------------------------------
task task_h_reset();
    r_hsw_cnt    = 0;
    r_hbp_cnt    = 0;
    r_hfp_cnt    = 0;
    r_hact_cnt   = 0;
    r_hstate_cnt = 0;
endtask

//------------------------------------------------
// [Reset Task] Reset Vertical Counters
//------------------------------------------------
task task_v_reset();
    r_vsw_cnt    = 0;
    r_vbp_cnt    = 0;
    r_vfp_cnt    = 0;
    r_vact_cnt   = 0;
    r_vstate_cnt = 0;
endtask

//------------------------------------------------
// [Line Task] Generate 1 Horizontal Line
//------------------------------------------------
task task_run_line(
    input state_t v_mode
);
    int i;
    bit v_active;
    bit drv_vsync, drv_hsync, drv_de;
    logic [9:0] drv_r, drv_g, drv_b;

    cur_vstate = v_mode;
    drv_vsync  = (v_mode == ST_SW) ? 1'b1 : 1'b0; 
    v_active   = (v_mode == ST_ACT);

    task_h_reset(); 

    cur_hstate = ST_SW;
    drv_hsync  = 1'b1;
    for(i=0; i<HSW; i++) begin
        task_drive_signal(drv_vsync, drv_hsync, 0, 0, 0, 0);
    end

    cur_hstate = ST_BP;
    drv_hsync  = 1'b0;
    for(i=0; i<HBP; i++) begin
        task_drive_signal(drv_vsync, drv_hsync, 0, 0, 0, 0);
    end

    cur_hstate = ST_ACT;
    for(i=0; i<HACT; i++) begin
        if (v_active) begin
            drv_de = 1'b1;
            drv_r  = $urandom_range(0, 1023);
            drv_g  = $urandom_range(0, 1023);
            drv_b  = $urandom_range(0, 1023);
        end else begin
            drv_de = 0;
            drv_r = 0; drv_g = 0; drv_b = 0;
        end
        task_drive_signal(drv_vsync, drv_hsync, drv_de, drv_r, drv_g, drv_b);
    end

    cur_hstate = ST_FP;
    drv_de = 0; drv_r = 0; drv_g = 0; drv_b = 0;
    for(i=0; i<HFP; i++) begin
        task_drive_signal(drv_vsync, drv_hsync, 0, 0, 0, 0);
    end
endtask

//------------------------------------------------
// [Frame Task] Generate Full Frames
//------------------------------------------------
task task_nframe_send(input int i_frames);
    int f, line;

    r_frame_cnt = 0;
    cur_vstate = ST_IDLE;
    cur_hstate = ST_IDLE;
    task_drive_signal(0,0,0,0,0,0);

    for(f=0; f < i_frames; f++) begin
        r_frame_cnt++;
        task_v_reset();

        for(line=0; line<VSW; line++)  task_run_line(ST_SW);
        for(line=0; line<VBP; line++)  task_run_line(ST_BP);
        for(line=0; line<VACT; line++) task_run_line(ST_ACT);
        for(line=0; line<VFP; line++)  task_run_line(ST_FP);
    end

    cur_vstate = ST_END;
    cur_hstate = ST_END;
    r_vstate_cnt = 0;
    r_hstate_cnt = 0;
    
    task_drive_signal(0, 0, 0, 0, 0, 0);
endtask