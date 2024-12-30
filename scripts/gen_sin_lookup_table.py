# write a function that generates a sin lookup table with values from 0 to 2pi with n increment starting from 0 to 2pi inclusive
import math
from FixedPoint import FXnum, FXfamily
import numpy as np

norm_fam = FXfamily(14, 2)


def gen_lookup_table(n, offset=0, func=math.sin):
	# sin_table = []
	# for i in range(n):
	# 	sin_table.append(math.sin(i * 2 * math.pi / n))
	# return sin_table

	table = []
	for i in range(n):
		table.append(func(i * 2 * math.pi / n + offset))

	return table


# avg error
def avg_error(n, sin_table):
	error = 0
	for i in range(n):
		error += float(
			abs(float(norm_fam(sin_table[i])) - math.sin(i * 2 * math.pi / n))
		)

	return error / n


def bin_to_hex(bin_str):
	integer_value = int(bin_str, 2)
	hex_value = hex(integer_value)

	return f"{hex_value[2:]:0>4}"


def table_to_brom(filename, num_fam, table):
	# with open(filename, "w") as file:

	lines = [num_fam(entry).toBinaryString().replace(".", "") + "\n" for entry in table]
	lines = [bin_to_hex(line) + "\n" for line in lines]
	print(lines[0], len(lines[0]))
	assert len(lines[0].strip()) == 4
	with open(filename, "w") as file:
		file.writelines(lines)


def main():
	HRES = 320
	VRES = 180
	theta_sin_table = gen_lookup_table(HRES, func=math.sin, offset=-math.pi)
	theta_cos_table = gen_lookup_table(HRES, func=math.cos, offset=-math.pi)

	phi_sin_table = gen_lookup_table(VRES, func=math.sin)
	phi_cos_table = gen_lookup_table(VRES, func=math.cos)

	table_to_brom("./mem/theta_sin_table.mem", norm_fam, theta_sin_table)
	table_to_brom("./mem/theta_cos_table.mem", norm_fam, theta_cos_table)
	table_to_brom("./mem/phi_sin_table.mem", norm_fam, phi_sin_table)
	table_to_brom("./mem/phi_cos_table.mem", norm_fam, phi_cos_table)

	# print(table)
	# print(avg_error(HRES, table))


main()
