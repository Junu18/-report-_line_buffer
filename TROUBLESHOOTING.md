# Line Buffer Controller 설계 트러블슈팅 가이드

## 개요
본 문서는 2-line buffer를 사용하는 영상 처리 시스템 설계 시 발생할 수 있는 문제점과 고려사항을 정리한 것입니다.

---

## 1. Sync 신호와 Data의 타이밍 정합 (Timing Alignment)

### 문제점
Line buffer를 사용할 경우, 데이터는 버퍼링으로 인해 지연이 발생합니다. 그러나 sync 신호(vsync, hsync, de)를 지연 없이 그대로 출력하면 **타이밍 미스매치**가 발생합니다.

### 발생 원인
```verilog
// 잘못된 구현 예시
assign o_vsync = i_vsync;  // 즉시 출력
assign o_hsync = i_hsync;  // 즉시 출력
assign o_de = i_de;        // 즉시 출력

// 하지만 데이터는...
// 2 라인 후에 출력됨 (RAM에서 읽어오는 시간)
```

- **데이터**: 2 라인 지연 (Line 0 write → Line 1 write → Line 0 read)
- **Sync**: 지연 없음
- **결과**: 출력 데이터와 sync 신호가 2 라인만큼 어긋남

### 해결 방안
Sync 신호도 데이터와 **동일한 지연**을 적용해야 합니다.

```verilog
localparam DELAY_CYCLES = 2 * HTOT;  // 2 line delay

// Shift register로 sync 신호 지연
reg [DELAY_CYCLES-1:0] vsync_delay;
reg [DELAY_CYCLES-1:0] hsync_delay;
reg [DELAY_CYCLES-1:0] de_delay;

always @(posedge clk) begin
    vsync_delay <= {vsync_delay[DELAY_CYCLES-2:0], i_vsync};
    hsync_delay <= {hsync_delay[DELAY_CYCLES-2:0], i_hsync};
    de_delay    <= {de_delay[DELAY_CYCLES-2:0], i_de};
end

assign o_vsync = vsync_delay[DELAY_CYCLES-1];
assign o_hsync = hsync_delay[DELAY_CYCLES-1];
assign o_de = de_delay[DELAY_CYCLES-1];
```

### 영향
- **타이밍 정합**: 출력 데이터와 sync가 정확히 일치
- **리소스**: Shift register 사용으로 FF 증가 (3 * DELAY_CYCLES 개)
- **VGA 환경**: 2 * 800 = 1600 클럭 지연 → 4800 FF 필요

---

## 2. 지연 사이클 계산 (Delay Cycle Calculation)

### 문제점
2-line buffer의 지연 시간을 정확히 계산해야 합니다.

### 계산 방법
```
지연 사이클 = 라인 수 × 라인당 총 픽셀 수
           = 2 × HTOT
           = 2 × (HSW + HBP + HACT + HFP)
```

### 예시
| 환경 | HTOT | 지연 사이클 |
|------|------|-------------|
| Testbench | 15 (1+2+10+2) | 30 clocks |
| VGA 640×480 | 800 (96+48+640+16) | 1600 clocks |

### 주의사항
- HTOT는 **active 영역만이 아닌 전체 라인** (blanking 포함)
- Parameter로 HTOT를 받거나 자동 측정 필요
- 해상도마다 다른 값 사용

---

## 3. State Machine 설계 (Line Buffer 제어)

### 상태 정의
2-line buffer는 다음 4가지 상태로 제어됩니다:

| State | 동작 | RAM0 | RAM1 |
|-------|------|------|------|
| LINE0_WR | Line 0 쓰기 | Write | - |
| LINE1_WR | Line 1 쓰기 | - | Write |
| LINE0_WR_RD | Line 0 쓰기, Line 1 읽기 | Write | Read |
| LINE1_WR_RD | Line 1 쓰기, Line 0 읽기 | Read | Write |

### 상태 전이 조건
```verilog
// hsync falling edge = 라인 종료
wire hsync_fall = i_hsync_d & ~i_hsync;

// State transition on hsync_fall
LINE0_WR → LINE1_WR → LINE0_WR_RD → LINE1_WR_RD → LINE0_WR_RD → ...
```

### 고려사항
- **초기 2 라인**: 쓰기만 수행 (읽기 불가)
- **3번째 라인부터**: 쓰기 + 읽기 동시 수행
- **vsync 발생 시**: 상태 초기화 (LINE0_WR로 복귀)

---

## 4. RAM 주소 관리 (Address Management)

### 문제점
Write 주소와 Read 주소를 어떻게 생성할 것인가?

### 해결 방안
```verilog
// Pixel counter (DE가 1일 때만 증가)
always @(posedge clk) begin
    if (i_vsync || hsync_fall) begin
        pixel_cnt <= 0;
    end else if (i_de) begin
        pixel_cnt <= pixel_cnt + 1;
    end
end

// 동일 주소 사용
assign wr_addr = pixel_cnt;
assign rd_addr = pixel_cnt;
```

### 이유
- **Write**: 현재 픽셀 위치에 데이터 저장
- **Read**: 2 라인 전 **같은 픽셀 위치**의 데이터 읽기
- **동일 주소**: 동일한 수평 위치 → 같은 주소 사용

### 주소 폭 계산
```verilog
localparam ADDR_WIDTH = $clog2(HACT);
```
- HACT = 10 → 4 bits
- HACT = 640 → 10 bits

---

## 5. RAM Read/Write 동시 접근 (Simultaneous Access)

### 문제점
LINE0_WR_RD, LINE1_WR_RD 상태에서 한 RAM은 Write, 다른 RAM은 Read를 동시 수행합니다.

### Single Port RAM의 제약
```verilog
// Single port RAM은 한 번에 하나의 동작만 가능
// cs=1, we=1 → Write
// cs=1, we=0 → Read
```

### 해결 방안: 2개의 RAM 사용
- **RAM0**: 짝수 라인 (Line 0, 2, 4, ...)
- **RAM1**: 홀수 라인 (Line 1, 3, 5, ...)

| 시점 | RAM0 | RAM1 |
|------|------|------|
| Line 0 | Write | - |
| Line 1 | - | Write |
| Line 2 | Write | Read (Line 1) |
| Line 3 | Read (Line 2) | Write |

→ 각 RAM은 한 번에 하나의 동작만 수행!

---

## 6. Data Packing/Unpacking

### 문제점
RGB 데이터는 각각 10-bit인데, RAM은 30-bit 단일 데이터로 저장합니다.

### 해결 방안
```verilog
// Write: 3개 채널을 하나로 묶음
wire [29:0] write_data = {i_r_data, i_g_data, i_b_data};
                      // [29:20]   [19:10]   [9:0]

// Read: 하나의 데이터를 3개 채널로 분리
assign o_r_data = read_data[29:20];
assign o_g_data = read_data[19:10];
assign o_b_data = read_data[9:0];
```

### 주의사항
- Bit 순서 일치 필요
- RAM DATA_WIDTH = 30 bits

---

## 7. Edge Detection (hsync falling)

### 문제점
라인 종료를 어떻게 감지할 것인가?

### 해결 방안
```verilog
reg i_hsync_d;

always @(posedge clk) begin
    i_hsync_d <= i_hsync;
end

wire hsync_fall = i_hsync_d & ~i_hsync;
```

### 타이밍
```
clk:     __|‾|_|‾|_|‾|_|‾|_
i_hsync: ‾‾‾‾‾‾‾‾‾‾‾|_______
i_hsync_d: ‾‾‾‾‾‾‾‾‾‾‾‾‾|_____
hsync_fall: ________|‾|_______
                     ^ 이 시점에 상태 전이
```

---

## 8. Reset 처리

### 고려사항
```verilog
// vsync 발생 시 프레임 시작 → 상태 초기화
if (i_vsync) begin
    state_n = ST_LINE0_WR;
end
```

### 이유
- 새 프레임 시작
- Line 0부터 다시 쓰기 시작
- 버퍼 재사용

---

## 9. 리소스 사용량 (Resource Utilization)

### Shift Register (Sync Delay)
| 항목 | 계산 | Testbench | VGA 640×480 |
|------|------|-----------|-------------|
| DELAY_CYCLES | 2 × HTOT | 30 | 1600 |
| FF 개수 (3신호) | 3 × DELAY_CYCLES | 90 FF | 4800 FF |

### RAM
| 항목 | 계산 | Testbench | VGA 640×480 |
|------|------|-----------|-------------|
| ADDR_WIDTH | $clog2(HACT) | 4 bits | 10 bits |
| DATA_WIDTH | 고정 | 30 bits | 30 bits |
| RAM_DEPTH | 2^ADDR_WIDTH | 16 | 1024 |
| RAM 개수 | 2개 | 2 | 2 |

---

## 10. SystemVerilog 추가 기능 사용 권장사항

### 현재 코드에서 사용된 기능
| 기능 | 용도 | 복잡도 |
|------|------|--------|
| `logic` | wire/reg 통합 타입 | 낮음 |
| `always_ff` | FF 명시 | 낮음 |
| `always_comb` / `always @(*)` | 조합 논리 | 낮음 |
| `localparam` | 지역 파라미터 | 낮음 |
| `$clog2()` | 자동 bit 계산 | 낮음 |

### 추가 고려 가능한 기능
| 기능 | 설명 | 사용 상황 | 복잡도 |
|------|------|-----------|--------|
| `enum` | 상태 정의 | State machine을 더 명확히 | 낮음 |
| `typedef` | 사용자 정의 타입 | 복잡한 구조체 정의 시 | 중간 |
| `struct` | 데이터 구조화 | RGB를 하나의 구조체로 | 중간 |
| `interface` | 모듈 간 통신 | 신호가 매우 많을 때 | 높음 |

### 예시: enum 사용
```verilog
// 기존 방식
localparam [1:0] ST_LINE0_WR = 2'b00;

// enum 사용
typedef enum logic [1:0] {
    ST_LINE0_WR    = 2'b00,
    ST_LINE1_WR    = 2'b01,
    ST_LINE0_WR_RD = 2'b10,
    ST_LINE1_WR_RD = 2'b11
} state_t;

state_t state, state_n;
```

---

## 요약 체크리스트

설계 시 반드시 확인해야 할 항목:

- [ ] **Sync 신호 지연**: 데이터와 동일한 지연 적용 (2 × HTOT)
- [ ] **HTOT 계산**: 전체 라인 길이 (blanking 포함)
- [ ] **상태 전이**: hsync falling edge 기준
- [ ] **주소 관리**: Write/Read 주소 동일 (같은 픽셀 위치)
- [ ] **RAM 분리**: 2개 RAM으로 동시 접근 해결
- [ ] **Data packing**: RGB 3채널을 30-bit 단일 데이터로
- [ ] **vsync 리셋**: 프레임 시작 시 상태 초기화
- [ ] **Parameter 전달**: HTOT, HACT를 testbench에서 전달
- [ ] **리소스 고려**: Shift register 크기 (VGA: 4800 FF)

---

## 참고: VGA Timing (640×480 @ 60Hz)

| 항목 | 값 |
|------|-----|
| Pixel Clock | 25.175 MHz |
| Horizontal Sync (HSW) | 96 pixels |
| Horizontal Back Porch (HBP) | 48 pixels |
| Horizontal Active (HACT) | 640 pixels |
| Horizontal Front Porch (HFP) | 16 pixels |
| **Horizontal Total (HTOT)** | **800 pixels** |
| Vertical Sync (VSW) | 2 lines |
| Vertical Back Porch (VBP) | 33 lines |
| Vertical Active (VACT) | 480 lines |
| Vertical Front Porch (VFP) | 10 lines |
| Vertical Total (VTOT) | 525 lines |

---

## 결론

Line buffer 설계 시 **가장 중요한 포인트**:
1. **Sync 신호 지연 = Data 지연** (타이밍 정합)
2. **2개의 RAM 사용** (동시 Read/Write)
3. **hsync falling edge** 기준 상태 전이

이 3가지를 정확히 구현하면 올바른 line buffer controller를 설계할 수 있습니다.
