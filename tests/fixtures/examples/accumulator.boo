"""
6
16
"""

def accumulator(sum):
	return {n| sum += n}

x = accumulator(1)
print x(5)
print x(10)