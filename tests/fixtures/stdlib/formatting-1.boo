"""
0, 2, 10
9 Foofoo valve's cost $211.50
Percentage: 75%, Total: 1001.568
2+2: 4
"""
# NOTE: .Net formatting options not supported

print "{0}, {1}, {5}" % array(x*2 for x in range(10))
n = 9
name = "Foofoo valve"
cost = 23.5
#print("{0} {1}'s cost {2:$#,##0.00}" % [n, name, n*cost])
print("{0} {1}'s cost \${2}0" % [n, name, n*cost])

#s = "Percentage: " + "{0:#%}, Total: {1:#.##0}" % (0.75,1001.5679)
s = 'Percentage: {0}%, Total: {1}' % ( 0.75 * 100, 1001.5679.toFixed(3))
print(s)

print("{0}: {1}" % ("2+2", 2+2))
