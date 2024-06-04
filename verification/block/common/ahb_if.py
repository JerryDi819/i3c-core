# SPDX-License-Identifier: Apache-2.0

from functools import reduce
from math import log2
from typing import List, Tuple

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandle, SimHandleBase
from cocotb.triggers import ClockCycles, RisingEdge, Timer, with_timeout
from cocotb_AHB.AHB_common.InterconnectInterface import InterconnectWrapper
from cocotb_AHB.drivers.DutSubordinate import DUTSubordinate
from cocotb_AHB.drivers.SimSimpleManager import SimSimpleManager
from cocotb_AHB.interconnect.SimInterconnect import SimInterconnect


async def setup_dut(dut: SimHandle, clk_period: Tuple[int, str]) -> None:
    """
    Setup clock & reset the unit
    """
    await cocotb.start(Clock(dut.hclk, *clk_period).start())
    dut.hreset_n.value = 0
    await ClockCycles(dut.hclk, 10)
    await RisingEdge(dut.hclk)
    await Timer(1, units="ns")
    dut.hreset_n.value = 1
    await ClockCycles(dut.hclk, 1)


def int_to_ahb_data(value: int, byte_width=4) -> List[int]:
    assert (
        log2(value) <= byte_width * 8
    ), f"Requested int: {value:#x} exceeds {byte_width:#x} bytes."
    return [(value >> (b * 8)) & 0xFF for b in range(byte_width)]


def ahb_data_to_int(data: List[int], byte_width=4) -> int:
    return reduce(lambda acc, bi: acc + (bi[0] << (bi[1] * 8)), zip(data, range(byte_width)), 0)


class AHBFIFOTestInterface:
    """
    This interface initializes appropriate cocotb AHB models and provides abstractions for
    common functionalities, such as read / write to CSR.
    """

    def __init__(self, dut: SimHandleBase, data_width=64):
        self.dut = dut
        self.data_width = data_width
        self.data_byte_width = data_width // 8

        # FIFO AHB Frontend
        self.AHBSubordinate = DUTSubordinate(dut, bus_width=data_width)

        # Simulated AHB in control of dispatching commands
        self.AHBManager = SimSimpleManager(bus_width=data_width)

        # Cocotb-ahb-specific construct for simulation purposes
        self.interconnect = SimInterconnect()

        # Cocotb-ahb-specific construct for simulation purposes
        self.wrapper = InterconnectWrapper()

    async def register_test_interfaces(self):
        # Clocks & resets
        self.AHBManager.register_clock(self.dut.hclk).register_reset(self.dut.hreset_n, True)
        self.interconnect.register_clock(self.dut.hclk).register_reset(self.dut.hreset_n, True)
        self.wrapper.register_clock(self.dut.hclk).register_reset(self.dut.hreset_n, True)
        # Interconnect setup
        self.interconnect.register_subordinate(self.AHBSubordinate)
        self.interconnect.register_manager(self.AHBManager)
        # Handled address space
        self.interconnect.register_manager_subordinate_addr(
            self.AHBManager, self.AHBSubordinate, 0x0, 0x4000
        )
        self.wrapper.register_interconnect(self.interconnect)

        await cocotb.start(self.AHBManager.start())
        await cocotb.start(self.wrapper.start())
        await cocotb.start(setup_dut(self.dut, (10, "ns")))

    async def read_csr(
        self, addr: int, size: int = 4, timeout: int = 2, units: str = "ms"
    ) -> List[int]:
        """Send a read request & await the response for 'timeout' in 'units'."""
        self.AHBManager.read(addr, size)
        await with_timeout(self.AHBManager.transfer_done(), timeout, units)
        read = self.AHBManager.get_rsp(addr, self.data_byte_width)
        return read

    async def write_csr(
        self, addr: int, data: List[int], size: int = 4, timeout: int = 2, units: str = "ms"
    ) -> None:
        """Send a write request & await transfer to finish for 'timeout' in 'units'."""
        # Write strobe is not supported by DUT's AHB-Lite; enable all bytes
        strb = [1 for _ in range(size)]
        self.AHBManager.write(addr, len(strb), data, strb)
        await with_timeout(self.AHBManager.transfer_done(), timeout, units)


def compare_values(expected: List[int], actual: List[int], addr: int):
    assert all([expected[i] == actual[i] for i in range(len(expected))]), (
        f"Word at {addr:#x} differs. "
        f"Expected: {ahb_data_to_int(expected):#x} "
        f"Got: {ahb_data_to_int(actual):#x} "
    )
