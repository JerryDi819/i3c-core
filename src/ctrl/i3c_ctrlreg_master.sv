// TODO: Align with spec on which condition/flag required for control reg
module i3c_ctrlreg_master (
    input  wire         i_clk,       // Clock signal
    input  wire         i_rst_n,     // Active-low reset signal
    input  wire [31:0]  i_cpu_wdata, // Data written from CPU
    input  wire         i_cpu_wr_en, // CPU write enable
    input  wire [7:0]   i_cpu_addr,  // Address for register access
    output reg  [31:0]  r_ctrl_reg   // Control register output
);

    // Bit definitions for the control register
    localparam START_BIT   = 0;  // Start condition trigger
    localparam STOP_BIT    = 1;  // Stop condition trigger
    localparam ACK_EN_BIT  = 2;  // ACK enable
    localparam I2C_EN_BIT  = 3;  // I2C enable
    localparam INT_EN_BIT  = 4;  // Interrupt enable
    localparam RESET_BIT   = 31; // Reset controller

    // Internal control register, reset to default values
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ctrl_reg <= 32'b0;  // Reset all control register bits
        end else if (i_cpu_wr_en && i_cpu_addr == 8'h00) begin
            r_ctrl_reg <= i_cpu_wdata;  // Write new values from CPU to control register
        end
    end

    // Extract control signals from the control register
    wire w_start_condition = r_ctrl_reg[START_BIT];   // Start condition
    wire w_stop_condition  = r_ctrl_reg[STOP_BIT];    // Stop condition
    wire w_ack_enable      = r_ctrl_reg[ACK_EN_BIT];  // Acknowledge enable
    wire w_i2c_enable      = r_ctrl_reg[I2C_EN_BIT];  // I2C controller enable
    wire w_int_enable      = r_ctrl_reg[INT_EN_BIT];  // Interrupt enable
    wire w_reset_control   = r_ctrl_reg[RESET_BIT];   // Reset the controller

endmodule
