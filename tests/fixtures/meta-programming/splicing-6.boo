#UNSUPPORTED: Meta programming not supported yet
"""
def foo(m as string):
	print(m)
"""
typeRef = "string"
print [|
	def foo(m as $typeRef):
		print(m)
|].ToCodeString()
