#IGNORE range slicing not supported yet
a = "12345"

assert "123" == a[-10:3]
assert "345" == a[-3:10]
