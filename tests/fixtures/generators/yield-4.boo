"""
2
1
0
"""
def onetwothree():
	i = 3
	yield --i
	yield --i
	yield --i
	
e = onetwothree()
for itm in e:
	print(itm)
