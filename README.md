# UART Transmitter (Verilog)

This project implements a **UART Transmitter** in Verilog with configurable baud rate using a `baud_gen` module.  
A testbench (`tb_uart`) is included to simulate data transmission at different baud rates.

---

## 📌 Project Overview

UART (**Universal Asynchronous Receiver/Transmitter**) is a serial communication protocol.  
This design focuses on the **transmitter** side:

1. **`baud_gen`** → Generates baud ticks based on system clock & selected baud rate.  
2. **`test_tx`** → Implements UART TX state machine (IDLE → START → DATA → STOP).  
3. **`tb_uart`** → Testbench for simulation with multiple baud rates and data patterns.  

---

## ⚙️ Features

- Configurable baud rates:
  - `9600`, `19200`, `38400`, `57600`, `115200`
- Oversampling factor: **16**  
- Supports 8-bit data transmission  
- Self-contained testbench with multiple test cases  

---

## 📂 File Structure
├── baud_gen.v # Baud rate generator
├── test_tx.v # UART transmitter (TX) module
├── tb_uart.v # Testbench
└── README.md # Documentation

---

## 🔧 Module Descriptions

### 1. `baud_gen`
- Input: `clk` (50 MHz system clock), `baud_sel` (3-bit baud rate selector)  
- Output: `baud_tick` (pulse at selected baud rate × oversampling)  
- Uses a divisor lookup table to generate accurate baud timing.

**Baud Select Mapping**

| `baud_sel` | Baud Rate |
|------------|-----------|
| `000`      | 9600      |
| `001`      | 19200     |
| `010`      | 38400     |
| `011`      | 57600     |
| `100`      | 115200    |

---

### 2. `test_tx`
Implements the **UART transmitter state machine**:
[IDLE] → [START] → [DATA BITS] → [STOP] → [IDLE]

- **IDLE**: Line stays HIGH, waiting for `start` signal  
- **START**: Sends logic `0` as the start bit  
- **DATA BITS**: Sends 8 data bits, LSB first  
- **STOP**: Sends logic `1` as stop bit  

Outputs:
- `tx` → Serial data line  
- `ready` → High when transmitter is idle and ready for new data  

---

### 3. `tb_uart`
Testbench to simulate UART transmitter.  
- Generates a **50 MHz clock**  
- Applies reset, sends multiple bytes (`0x55`, `0xAA`, `0xEF`)  
- Changes `baud_sel` during simulation to test multiple baud rates  
- Uses `$display` messages for clarity  

---

## 📊 UART Transmission Diagram

Line State:

IDLE START D0 D1 D2 D3 D4 D5 D6 D7 STOP IDLE
| | | | | | | | | | | |
1 ---- 0 ---- b0 - b1 - b2 - b3 - b4 - b5 - b6 - b7 -- 1 ---- 1

- `IDLE` = Line held high (`1`)  
- `START` = Single `0` bit  
- `DATA` = 8 bits (LSB first)  
- `STOP` = Single `1` bit  

---

## 🚀 Simulation

Run the testbench with any Verilog simulator (e.g., ModelSim, Icarus, Verilator):

