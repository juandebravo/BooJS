"""
FOO BAR
BAR FOO
"""
def ToUpper(item as string):
	return item.toUpperCase()

print(join(map(["foo", "bar"], ToUpper)))
print(join(map(("bar", "foo"), ToUpper)))
