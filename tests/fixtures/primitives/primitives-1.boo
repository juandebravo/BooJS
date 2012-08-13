#IGNORE Data types comparisons are not available in JS runtime

def same(expected, actual):
	assert expected is actual
	
same(System.Void, void)
same(System.Object, duck)
same(System.Object, object)
same(System.Boolean, bool)
same(System.SByte, sbyte)
same(System.Byte, byte)
same(System.Int16, short)
same(System.UInt16, ushort)
same(System.Int32, int)
same(System.UInt32, uint)
same(System.Int64, long)
same(System.UInt64, ulong)
same(System.Single, single)
same(System.Double, double)
same(System.Decimal, decimal)
same(System.Char, char)
same(System.String, string)
same(System.Text.RegularExpressions.Regex, regex)
same(System.DateTime, date)
same(System.TimeSpan, timespan)
same(Boo.Lang.ICallable, typeof(callable))
