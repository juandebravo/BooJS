#UNSUPPORTED: Meta programming not supported yet
"""
def foo():
	print('Hello, world')
"""
literal = [|
	def foo():
		print("Hello, world")
|]

print literal.ToCodeString()
