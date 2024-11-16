import random
import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from FixedPoint import FXfamily, FXnum


def generate_random_camera_region(x_max, y_max):
    x_min = random.randint(0, x_max // 2)
    y_min = random.randint(0, y_max // 2)
    x_max = random.randint(x_min + 1, x_max)
    y_max = random.randint(y_min + 1, y_max)
    return x_min, x_max, y_min, y_max


def reverse_bits(n, size):
    reversed_n = 0
    for i in range(size):
        reversed_n = (reversed_n << 1) | (n & 1)
        n >>= 1
    return reversed_n


async def reset_dut(dut):
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 1
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)


async def test_dut_divide(dut, a, b, log=True, fp_family=FXfamily(8, 4)):
    cocotb.start_soon(Clock(dut.clk_in, 1, units="ns").start())
    await reset_dut(dut)

    await RisingEdge(dut.clk_in)
    dut.A.value = BinaryValue(FXnum(a, fp_family).toBinaryString().replace(".", ""))
    dut.B.value = BinaryValue(FXnum(b, fp_family).toBinaryString().replace(".", ""))
    dut.valid_in.value = 1

    await RisingEdge(dut.clk_in)
    dut.valid_in.value = 0

    # wait for calculation to complete
    while not dut.done.value:
        await RisingEdge(dut.clk_in)

    # model quotient: covert twice to ensure division is handled consistently
    #                 https://github.com/rwpenney/spfpm/issues/14
    model_val = fp_family(float(fp_family(a)) / float(fp_family(b)))

    # divide dut result by scaling factor
    val = fp_family(dut.Q.value.signed_integer / 2**FRAC_BITS)

    # log numerical signals
    if log:
        dut._log.info("dut a:     " + dut.A.value.binstr)
        dut._log.info("dut b:     " + dut.B.value.binstr)
        dut._log.info("dut val:   " + dut.Q.value.binstr)
        dut._log.info(
            "           " + val.toDecimalString(precision=fp_family.fraction_bits)
        )
        dut._log.info("model val: " + model_val.toBinaryString())
        dut._log.info(
            "           " + model_val.toDecimalString(precision=fp_family.fraction_bits)
        )

    # check output signals on 'done'
    assert dut.busy.value == 0, "busy is not 0!"
    assert dut.done.value == 1, "done is not 1!"
    assert dut.valid_out.value == 1, "valid is not 1!"
    assert dut.zerodiv.value == 0, "dbz is not 0!"
    assert dut.overflow.value == 0, "ovf is not 0!"
    assert val == model_val, "dut val doesn't match model val"

    # check 'done' is high for one tick
    await RisingEdge(dut.clk_in)
    assert dut.done.value == 0, "done is not 0!"


def print_twos_complement(num, bit_size):
    # Mask the number to fit within the specified bit_size
    raw_binary = get_twos_complement(num, bit_size)
    print(f"{num} = {raw_binary}")


def get_twos_complement(num, bit_size):
    raw_binary = format(num & ((1 << bit_size) - 1), f"0{bit_size}b")
    return raw_binary


def pack_values(values, size):
    # pack the values in a string of bits
    return "".join([get_twos_complement(v, size) for v in reversed(values)])


def generate_twos_complement_random(A_size, ffamily=None):
    # Generate a random integer within the range for two's complement with A_size bits
    min_val = -(1 << (A_size - 1))
    max_val = (1 << (A_size - 1)) - 1
    return (
        random.randint(min_val, max_val)
        if ffamily is None
        else ffamily(random.randint(min_val, max_val))
    )


def gen_random_vector(size, A_size, frac_bits, ffamily=None):
    return [
        ffamily(generate_twos_complement_random(A_size) / (2 ** (frac_bits)))
        for _ in range(size)
    ]


def vec_to_bin(vec, bit_size):
	# retruns a string of bits representing the packed vector
    vtype = type(vec[0])

    if vtype == FXnum:
        return "".join([v.toBinaryString().replace(".", "") for v in reversed(vec)])

    if vtype == int:
        return (pack_values(vec, bit_size))

    else:
        raise ValueError("Unsupported type")
