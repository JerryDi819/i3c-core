// SPDX-License-Identifier: Apache-2.0
`include "i3c_defines.svh"

module i3c_wrapper
  import i3c_pkg::*;
#(
`ifdef I3C_USE_AHB
    parameter int unsigned AHB_DATA_WIDTH = `AHB_DATA_WIDTH,
    parameter int unsigned AHB_ADDR_WIDTH = `AHB_ADDR_WIDTH
`endif  // TODO: AXI4 I/O
) (
    input clk_i,  // clock
    input rst_ni, // active low reset

`ifdef I3C_USE_AHB
    // AHB-Lite interface
    // Byte address of the transfer
    input  logic [  AHB_ADDR_WIDTH-1:0] haddr_i,
    // Indicates the number of bursts in a transfer
    input  logic [                 2:0] hburst_i,     // Unhandled
    // Protection control; provides information on the access type
    input  logic [                 3:0] hprot_i,      // Unhandled
    // Indicates the size of the transfer
    input  logic [                 2:0] hsize_i,
    // Indicates the transfer type
    input  logic [                 1:0] htrans_i,
    // Data for the write operation
    input  logic [  AHB_DATA_WIDTH-1:0] hwdata_i,
    // Write strobes; Deasserted when write data lanes do not contain valid data
    input  logic [AHB_DATA_WIDTH/8-1:0] hwstrb_i,     // Unhandled
    // Indicates write operation when asserted
    input  logic                        hwrite_i,
    // Read data
    output logic [  AHB_DATA_WIDTH-1:0] hrdata_o,
    // Asserted indicates a finished transfer; Can be driven low to extend a transfer
    output logic                        hreadyout_o,
    // Transfer response, high when error occurred
    output logic                        hresp_o,
    // Indicates the subordinate is selected for the transfer
    input  logic                        hsel_i,
    // Indicates all subordinates have finished transfers
    input  logic                        hready_i,
    // TODO: AXI4 I/O
    // `else
`endif

    // I3C bus IO
    input        i3c_scl_i,    // serial clock input from i3c bus
    output logic i3c_scl_o,    // serial clock output to i3c bus
    output logic i3c_scl_en_o, // serial clock output to i3c bus

    input        i3c_sda_i,    // serial data input from i3c bus
    output logic i3c_sda_o,    // serial data output to i3c bus
    output logic i3c_sda_en_o, // serial data output to i3c bus

    input  logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o

    // TODO: Check if anything missing; Interrupts?
);

  `define REPORT_INCOMPATIBLE_PARAM(param_name, received, expected) \
    `ifdef DEBUG \
      $warning("%s: %0d doesn't match the I3C config: %0d (instance %m).", \
        param_name, received, expected); \
      $info("Overriding %s to %0d.", param_name, expected); \
    `else \
      $fatal(0, "%s: %0d doesn't match the I3C config: %0d (instance %m).", \
      param_name, received, expected); \
    `endif

  // Check widths match the I3C configuration
  initial begin : clptra_vs_i3c_config_param_check
`ifdef I3C_USE_AHB
    if (AHB_ADDR_WIDTH != `AHB_ADDR_WIDTH) begin : clptra_ahb_addr_w_check
      `REPORT_INCOMPATIBLE_PARAM("AHB address width", AHB_ADDR_WIDTH, `AHB_ADDR_WIDTH)
    end
    if (AHB_DATA_WIDTH != `AHB_DATA_WIDTH) begin : clptra_ahb_data_w_check
      `REPORT_INCOMPATIBLE_PARAM("AHB data width", AHB_DATA_WIDTH, `AHB_DATA_WIDTH)
    end
`endif  // I3C_USE_AHB TODO: AXI4 I/O
  end

  logic i3c_scl_io;
  logic i3c_sda_io;

  // DAT memory export interface
  dat_mem_src_t dat_mem_src;
  dat_mem_sink_t dat_mem_sink;

  // DCT memory export interface
  dct_mem_src_t dct_mem_src;
  dct_mem_sink_t dct_mem_sink;

  i3c #(
`ifdef I3C_USE_AHB
      .AHB_DATA_WIDTH(AHB_DATA_WIDTH),
      .AHB_ADDR_WIDTH(AHB_ADDR_WIDTH)
`endif
  ) i3c (
      .clk_i,
      .rst_ni,

      .haddr_i,
      .hburst_i,
      .hprot_i,
      .hsize_i,
      .htrans_i,
      .hwdata_i,
      .hwstrb_i,
      .hwrite_i,
      .hrdata_o,
      .hreadyout_o,
      .hresp_o,
      .hsel_i,
      .hready_i,

      .i3c_scl_i,
      .i3c_scl_o,
      .i3c_scl_en_o,

      .i3c_sda_i,
      .i3c_sda_o,
      .i3c_sda_en_o,

      .dat_mem_src_i (dat_mem_src),
      .dat_mem_sink_o(dat_mem_sink),

      .dct_mem_src_i (dct_mem_src),
      .dct_mem_sink_o(dct_mem_sink),

      .i3c_fsm_en_i,
      .i3c_fsm_idle_o
  );

  prim_ram_1p_adv #(
      .Depth(`DAT_DEPTH),
      .Width(64),
      .DataBitsPerMask(32)
  ) dat_memory (
      .clk_i,
      .rst_ni,
      .req_i(dat_mem_sink.req),
      .write_i(dat_mem_sink.write),
      .addr_i(dat_mem_sink.addr),
      .wdata_i(dat_mem_sink.wdata),
      .wmask_i(dat_mem_sink.wmask),
      .rdata_o(dat_mem_src.rdata),
      .rvalid_o(),  // Unused
      .rerror_o(),  // Unused
      .cfg_i('0)  // Unused
  );

  prim_ram_1p_adv #(
      .Depth(`DCT_DEPTH),
      .Width(128),
      .DataBitsPerMask(32)
  ) dct_memory (
      .clk_i,
      .rst_ni,
      .req_i(dct_mem_sink.req),
      .write_i(dct_mem_sink.write),
      .addr_i(dct_mem_sink.addr),
      .wdata_i(dct_mem_sink.wdata),
      .wmask_i(dct_mem_sink.wmask),
      .rdata_o(dct_mem_src.rdata),
      .rvalid_o(),  // Unused
      .rerror_o(),  // Unused
      .cfg_i('0)  // Unused
  );

  i3c_io phy_io (
      .scl_io(i3c_scl_io),
      .scl_i(i3c_scl_o),
      .scl_en_i(i3c_scl_en_o),

      .sda_io(i3c_sda_io),
      .sda_i(i3c_sda_o),
      .sda_en_i(i3c_sda_en_o)
  );

endmodule
