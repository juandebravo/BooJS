"""
0
1
2
0
2
4
"""
callable Action(item)

def each(items, action as Action):
	for item in items:
		action(item)

def myprint(item):
	print item

each(range(3), myprint)
each(range(3)) do (item as int):
	print(item*2)

