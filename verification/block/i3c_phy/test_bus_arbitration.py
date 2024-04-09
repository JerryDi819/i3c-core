# Copyright (c) 2024 Antmicro
# SPDX-License-Identifier: Apache-2.0

import logging
import random

import cocotb
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge
from common import I3C_CLOCK_DIV, check_delayed, init_phy

random.seed()


async def run_test(dut):
    """Run test for bus arbitration."""
    cocotb.log.setLevel(logging.INFO)
    TEST_DATA = [random.randint(0, 1) for _ in range(20)]

    clk = dut.clk

    clock_counter = 0
    while True:
        # Simulate I3C bus slower than internal clock
        await FallingEdge(clk)
        clock_counter += 1
        if clock_counter % I3C_CLOCK_DIV:
            continue

        # If TEST_DATA is empty, leave the loop
        if not TEST_DATA:
            break
        test_sda_bit = TEST_DATA.pop()

        # Assign new values to SCL and SDA
        not_scl = int(not int(dut.ctrl_scl_i.value))
        dut.ctrl_scl_i._log.debug(f"Setting SCL to {not_scl}")
        dut.ctrl_scl_i.value = not_scl
        dut.ctrl_sda_i._log.debug(f"Setting SDA to {test_sda_bit}")
        dut.ctrl_sda_i.value = test_sda_bit

        # We expect requested value if we control the bus
        if int(dut.arbitration_en_i.value):
            expected_scl = not_scl
            expected_sda = test_sda_bit
        else:  # We expect bus input value if we do not control the bus
            expected_scl = int(dut.scl_i.value) if not_scl else 0
            expected_sda = int(dut.sda_i.value) if test_sda_bit else 0

        # Spawn a coroutine that will check SCL state after synchronization cycles
        cocotb.start_soon(check_delayed(clk, dut.ctrl_scl_o, expected_scl))

        # Spawn a coroutine that will check SDA state after synchronization cycles
        cocotb.start_soon(check_delayed(clk, dut.ctrl_sda_o, expected_sda))

        # Spawn a coroutine that will check bus errors after synchronization cycles
        if int(dut.arbitration_en_i.value):
            cocotb.start_soon(check_delayed(clk, dut.phy_err_o, 0))

        await RisingEdge(clk)

    await ClockCycles(clk, 5)


# TODO: Add a test that will check if the errors are raised properly


@cocotb.test()
async def run_as_controller(dut):
    # Enable bus arbitration since we should always be in control
    dut.arbitration_en_i.value = 1

    await init_phy(dut)
    await run_test(dut)


@cocotb.test()
async def run_as_target(dut):
    await init_phy(dut)
    await run_test(dut)
