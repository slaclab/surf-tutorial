##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# dut_tb
import itertools
import logging
import cocotb
from cocotb.clock      import Clock
from cocotb.handle     import Immediate
from cocotb.triggers   import RisingEdge

from cocotbext.axi import AxiStreamFrame, AxiStreamBus, AxiStreamSource, AxiStreamSink

# test_MyAxiStreamMuxDemuxWrapper
from cocotb_tools.runner import get_runner
import pytest
import glob
import os

# Define a new log level
CUSTOM_LEVEL = 60
logging.addLevelName(CUSTOM_LEVEL, "CUSTOM")

def custom(self, message, *args, **kwargs):
    if self.isEnabledFor(CUSTOM_LEVEL):
        self._log(CUSTOM_LEVEL, message, args, **kwargs)

# Add the custom level to the logging.Logger class
logging.Logger.custom = custom

tests_dir = os.path.dirname(__file__)
tests_module = 'MyAxiStreamMuxDemuxWrapper'

# Testbench logger, named after the toplevel so that it shares a prefix
# with the per-bus loggers created by cocotbext-axi
log = logging.getLogger(f"cocotb.{tests_module.lower()}")
log.setLevel(logging.INFO)

# Helper function for converting 32-bit values to string
def rdDataToStr(data):
    return hex(int.from_bytes(data, byteorder="little"))

class TB:
    def __init__(self, dut):

        # Pointer to DUT object
        self.dut = dut

        self.log = log

        # Start AXIS_ACLK clock (200 MHz) in a separate thread
        Clock(dut.AXIS_ACLK, 5.0, unit='ns').start()

        # Setup the AXI stream source
        self.source = AxiStreamSource(
            bus   = AxiStreamBus.from_prefix(dut, "S_AXIS"),
            clock = dut.AXIS_ACLK,
            reset = dut.AXIS_ARESETN,
            reset_active_level = False,
        )

        # Setup the AXI stream sink
        self.sink = AxiStreamSink(
            bus   = AxiStreamBus.from_prefix(dut, "M_AXIS"),
            clock = dut.AXIS_ACLK,
            reset = dut.AXIS_ARESETN,
            reset_active_level = False,
        )

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())

    async def cycle_reset(self):
        self.dut.AXIS_ARESETN.set(Immediate(0))
        await RisingEdge(self.dut.AXIS_ACLK)
        await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 0
        await RisingEdge(self.dut.AXIS_ACLK)
        await RisingEdge(self.dut.AXIS_ACLK)
        self.dut.AXIS_ARESETN.value = 1
        await RisingEdge(self.dut.AXIS_ACLK)
        await RisingEdge(self.dut.AXIS_ACLK)

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])

def size_list():
    return list(range(1, 32+1))

def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))

@cocotb.test()
@cocotb.parametrize(
    payload_lengths       = [size_list],
    payload_data          = [incrementing_payload],
    idle_inserter         = [None, cycle_pause],
    backpressure_inserter = [None, cycle_pause],
)
async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    log.custom( f'run_test(): idle_inserter={idle_inserter}, backpressure_inserter={backpressure_inserter}' )

    tb = TB(dut)

    id_count = 2**len(tb.source.bus.tid)

    cur_id = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_frames = []

    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id
        await tb.source.send(test_frame)

        test_frames.append(test_frame)

        cur_id = (cur_id + 1) % id_count

    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()

        assert rx_frame.tdata == test_frame.tdata
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == test_frame.tdest
        assert not rx_frame.tuser

    assert tb.sink.empty()
    tb.log.custom( f'.... passed test' )


##############################################################################

@pytest.mark.parametrize(
    "parameters", [
        None
    ])
def test_MyAxiStreamMuxDemuxWrapper(parameters):

    # https://docs.cocotb.org/en/stable/library_reference.html#python-test-runner
    # https://docs.cocotb.org/en/stable/runner.html
    runner = get_runner('ghdl')

    # The directory used to compile the tests. (default: sim_build)
    build_dir = f'{tests_dir}/../build/{tests_module}'

    # use of synopsys package "std_logic_arith" needs the -fsynopsys option
    # -frelaxed-rules option to allow IP integrator attributes
    # When two operators are overloaded, give preference to the explicit declaration (-fexplicit)
    build_args = ['-fsynopsys','-frelaxed-rules', '-fexplicit']

    # Analyse the VHDL source code into its own named library.
    # The toplevel's library is built last so that "ghdl -m" can resolve
    # the toplevel's dependencies against the already-analysed libraries.
    for hdl_library in ['surf', 'ruckus', 'work']:
        runner.build(
            # The library name to compile into
            hdl_library = hdl_library,

            # VHDL source files to include
            sources = glob.glob(f'{tests_dir}/../build/SRC_VHDL/{hdl_library}/*'),

            build_args = build_args,
            build_dir  = build_dir,

            # Only elaborate once the toplevel's library is reached
            hdl_toplevel = tests_module if hdl_library == 'work' else None,
        )

    runner.test(
        # name of the file that contains @cocotb.test() -- this file
        # https://docs.cocotb.org/en/stable/building.html?#envvar-COCOTB_TEST_MODULES
        test_module = f'test_{tests_module}',

        # top level HDL (lowercase to match the instance name reported by GHDL's VPI)
        hdl_toplevel         = tests_module.lower(),
        hdl_toplevel_library = 'work',

        # https://docs.cocotb.org/en/stable/building.html?#var-COCOTB_TOPLEVEL_LANG
        hdl_toplevel_lang = 'vhdl',

        # A dictionary of top-level parameters/generics.
        parameters = parameters,

        build_dir = build_dir,

        # GHDL's mcode backend elaborates at run time, so the compile flags are
        # needed here as well as in build()
        test_args = build_args,

        ########################################################################
        # Dump waveform to file ($ gtkwave build/MyAxiStreamMuxDemuxWrapper/MyAxiStreamMuxDemuxWrapper.ghw)
        ########################################################################
        waves = True,
    )
