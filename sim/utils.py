import random
import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from FixedPoint import FXfamily, FXnum
import numpy as np
import math
from PIL import Image


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
        return pack_values(vec, bit_size)

    else:
        raise ValueError("Unsupported type")


def generate_triangle_fast(viewport_width, viewport_height):
    def is_collinear(p):
        # Use NumPy to calculate the determinant for collinearity
        return np.isclose(
            (p[1, 0] - p[0, 0]) * (p[2, 1] - p[0, 1]),
            (p[2, 0] - p[0, 0]) * (p[1, 1] - p[0, 1]),
        )

    while True:
        # Generate three random points within the viewport
        points = np.random.rand(3, 2) * [viewport_width, viewport_height]
        if not is_collinear(points):
            return points


def triangle_area(tri):
    return 0.5 * (
        tri[0, 0] * (tri[1, 1] - tri[2, 1])
        + tri[1, 0] * (tri[2, 1] - tri[0, 1])
        + tri[2, 0] * (tri[0, 1] - tri[1, 1])
    )


def is_point_in_triangle(triangle, point):
    """
    Determines if a 2D point is inside a given triangle.

    Args:
                                                                    triangle (tuple): A tuple of three points (p1, p2, p3) defining the triangle.
                                                                                                                                                                                                                                                                                                                                      Each point is a tuple (x, y).
                                                                    point (tuple): The 2D point to check, given as (x, y).

    Returns:
                                                                    bool: True if the point is inside the triangle, False otherwise.
    """

    def area(p1, p2, p3):
        # Compute the signed area of the triangle formed by three points
        return 0.5 * abs(
            float(p1[0]) * (float(p2[1]) - float(p3[1]))
            + float(p2[0]) * (float(p3[1]) - float(p1[1]))
            + float(p3[0]) * (float(p1[1]) - float(p2[1]))
        )

    # Unpack triangle vertices
    p1, p2, p3 = triangle

    # Compute the total area of the triangle
    total_area = area(p1, p2, p3)

    # Compute areas of sub-triangles formed with the point
    area1 = area(point, p2, p3)
    area2 = area(p1, point, p3)
    area3 = area(p1, p2, point)

    # Check if the sum of sub-triangle areas equals the total area
    return math.isclose(total_area, area1 + area2 + area3, rel_tol=1e-9)


def split_bit_array(raw_bits, n):
    assert (
        len(raw_bits) % n == 0
    ), f"len(raw_bits)={len(raw_bits)} must be divisible by n={n}"
    increment = len(raw_bits) // n
    return [raw_bits[i * (increment) : (i + 1) * increment] for i in range(0, n)]


def barycentric_raw_areas(x, y, triangle):
    """
    Calculates the raw areas of the three sub-triangles for barycentric interpolation.

    Args:
                                    i (float): x-coordinate of the point.
                                    j (float): y-coordinate of the point.
                                    triangle (tuple): A tuple of three vertices ((x1, y1), (x2, y2), (x3, y3)).

    Returns:
                                    tuple: Raw signed areas (area1, area2, area3) of the sub-triangles.
    """
    x1, y1 = triangle[0]
    x2, y2 = triangle[1]
    x3, y3 = triangle[2]

    D = (x1 * (y2 - y3)) + (x2 * (y3 - y1)) + (x3 * (y1 - y2))
    D1 = (x * (y2 - y3)) + (x2 * (y3 - y)) + (x3 * (y - y2))
    D2 = (x1 * (y - y3)) + (x * (y3 - y1)) + (x3 * (y1 - y))
    D3 = (x1 * (y2 - y)) + (x2 * (y - y1)) + (x * (y1 - y2))

    assert abs(D - (D1 + D2 + D3)) < 1e-6

    return D1, D2, D3


# Function to display the bitmap in the terminal
def display_bitmap(bitmap):
    # Loop through each row in the bitmap
    for row in bitmap:
        # Convert each row of 0s and 1s to characters (e.g., 1 -> "#" and 0 -> " ")
        print("".join("#" if val else " " for val in row))


def display_frame_pixelized(I):
    # save this frame as an image file with name = id(frame).png
    # the image would be grayscale
    m = min(2000, I.max())
    I8 = (((I - 0)) / (m - 0) * 255.9).astype(np.uint8)

    img = Image.fromarray(I8)
    name = f"./imgs/{random.random()}.png"
    img.save(name)

    # # draw the tri_coords as an exact triangle and save it as a separate image with same name but with _tri.png
    # tri_coords = tri_coords.astype(int)
    # img = Image.new("RGB", (len(I), len((I[0]))), color=(0, 0, 0))
