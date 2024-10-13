/* TODO:
    1. How to handle PID arbitration
    2. Which is the dynamic addr start num?
    3. Compare with I2C
    4. Doc down this module
*/

module daa_master
  import controller_pkg::*;
  import i3c_pkg::*;
(
    input logic clk,               // System clock
    input logic reset_n,           // Active-low reset

    // Address Assignment Signals (Hand-shake)
    input logic daa_start,         // Start dynamic address assignment
    output logic daa_done,         // Dynamic address assignment completed

    // I3C Bus Signals
    output logic [6:0] dyn_addr_assigned,  // Dynamic address assigned to a slave
    output logic [47:0] pid_received,      // Provisional ID received from slave
    output logic daa_cmd_sent,             // Flag: ENTDAA command sent
    input logic daa_resp_received,         // Flag: ENTDAA response received
    input logic [6:0] bus_target_addr,     // Bus target address

    // Device Registers (from the slave)
    input  [31:0] device_static_addr_reg,  // Static address register
    input  [31:0] device_bcr_dcr_reg,      // BCR/DCR register
    input  [31:0] device_pid_lo_reg,       // Lower part of PID register
    output logic [63:0] response_to_daa    // Response to ENTDAA command
);

  // Address Assignment Variables
  logic [6:0] next_dyn_addr;       // Next dynamic address to assign
  logic [47:0] slave_pid;
  logic [7:0] bcr;
  logic [7:0] dcr;

  // State Machine for Address Assignment
  typedef enum logic [1:0] {
    IDLE,
    BROADCAST_ENTDAA,    // Send ENTDAA command to all slaves
    RECEIVE_PID,         // Wait for PID from a slave
    ASSIGN_DYNAMIC_ADDR  // Assign dynamic address to the responding slave
  } daa_state_t;

  daa_state_t current_state, next_state;

  // Provisional ID (PID) Construction
  assign slave_pid = {device_bcr_dcr_reg[15:1], 1'b0, device_pid_lo_reg};
  assign bcr = device_bcr_dcr_reg[31:24];
  assign dcr = device_bcr_dcr_reg[23:16];
  assign response_to_daa = {slave_pid, bcr, dcr};

  always_ff @(posedge clk or negedge reset_n) begin
    if (~reset_n) begin
      current_state <= IDLE;
      next_dyn_addr <= 7'h02;  // Start assigning dynamic addresses from 0x02 (as per I3C spec)
      daa_done <= 0;
      daa_cmd_sent <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        // --- Initial Mode ---
        IDLE: begin
          if (daa_start) begin
            next_state <= BROADCAST_ENTDAA;
          end
        end
        // --- Begin Broadcast ---
        BROADCAST_ENTDAA: begin
          // Send ENTDAA command to initiate address assignment
          daa_cmd_sent <= 1'b1;
          if (daa_resp_received) begin
            daa_cmd_sent <= 1'b0;
            next_state <= RECEIVE_PID;
          end
        end
        // --- PID Arbitration ---
        RECEIVE_PID: begin
          // After receiving the Provisional ID (PID), prepare to assign the dynamic address
          pid_received <= slave_pid;
          next_state <= ASSIGN_DYNAMIC_ADDR;
        end
        // 
        ASSIGN_DYNAMIC_ADDR: begin
          // Assign the next available dynamic address to the responding slave
          dyn_addr_assigned <= next_dyn_addr;
          next_dyn_addr <= next_dyn_addr + 7'h01;  // Increment to assign a unique dynamic address
          daa_done <= 1'b1;
          next_state <= IDLE;
        end
      endcase
    end
  end
endmodule
