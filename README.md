# UART Design & Verification using SystemVerilog

## Overview

This project implements and verifies a parameterized UART (Universal Asynchronous Receiver Transmitter) using Verilog RTL and SystemVerilog-based functional verification.

The design supports UART transmission and reception with configurable clock frequency and baud rate. A loopback configuration is used in the testbench to verify end-to-end data integrity.

## Architecture

```text
              +-------------------+
              |     UART TX       |
              |                   |
TX Data ----->| Parallel to       |-----> TX
              | Serial            |
              +-------------------+
                       |
                       | Loopback
                       v
              +-------------------+
              |     UART RX       |
              |                   |
              | Serial to         |-----> RX Data
              | Parallel          |
              +-------------------+
Verification Environment

The SystemVerilog testbench provides:

TX-to-RX loopback verification
Self-checking scoreboard
Randomized data generation
Directed corner-case testing
Frame-error checking
Transaction-level pass/fail reporting
VCD waveform generation
Test Strategy

The verification suite contains 500 test transactions.

Directed Tests
The following corner cases are explicitly tested:
| Test    | Purpose                     |
| ------- | --------------------------- |
| `8'h00` | All-zero pattern            |
| `8'hFF` | All-one pattern             |
| `8'h55` | Alternating-bit pattern     |
| `8'hAA` | Reverse alternating pattern |
| `8'h01` | LSB activity                |
| `8'h80` | MSB activity                |
| `8'h7F` | Lower-bit boundary pattern  |
| `8'hA5` | Mixed-bit pattern           |

Randomized Tests
492 additional transactions are generated using randomized 8-bit data.

==============================================
              VERIFICATION REPORT
==============================================
Total Tests  : 500
Passed       : 500
Failed       : 0
RESULT       : ALL 500 TESTS PASSED
==============================================
