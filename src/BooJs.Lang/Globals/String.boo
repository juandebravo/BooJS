namespace BooJs.Lang.Globals

import BooJs.Lang.Extensions

import System.Collections(IEnumerable)

class String(Object, IEnumerable):
    # IMPORTANT: Boo requires explicit/implicit operators to use the actual types
    [Transform( parseInt($1) )]
    static def op_Explicit(value as String) as NumberInt:
        pass

    [Transform($1 == $2)]
    static def op_Equality(lhs as string, rhs as string) as bool:
        pass

    [Transform($1 + $2)]
    static def op_Addition(lhs as string, rhs as string) as string:
        pass

    [Transform($1 + $2)]
    static def op_Addition(lhs as string, rhs as double) as string:
        pass

    # Multiply operator: 'foo' * 2 --> 'foofoo'
    [Transform( Boo.String.op_Multiply($1, $2) )]
    static def op_Multiply(lhs as string, rhs as int) as string:
        pass
    # Formatting: '{0} {1}' % ('foo', 'bar')
    [Transform( Boo.String.op_Modulus($1, $2) )]
    static def op_Modulus(lhs as string, rhs as IEnumerable) as string:
        pass

    # Static methods

    static def fromCharCode(code as int) as string:
        pass


    # Instance members
    
    self[index as int] as string:
         get: pass

    public length as uint


    def charAt(idx as int) as string:
        pass
    def charCodeAt(idx as int) as int:
        pass
    def concat(str as string) as string:
        pass
    def indexOf(str as string) as int:
        pass
    def lastIndexOf(str as string) as int:
        pass

    def match(re as RegExp) as bool:
        pass
    def replace(re as RegExp, repl as string) as string:
        pass
    def replace(substr as string, repl as string) as string:
        pass
    def replace(re as RegExp, repl as callable) as string:
        pass
    def replace(substr as string, repl as callable) as string:
        pass

    def split(sep as string) as (string):
        pass

    def substr(start as uint, length as int) as string:
        pass
    def substring(start as uint, stop as int) as string:
        pass

    def toUpperCase() as string:
        pass

    def toLowerCase() as string:
        pass

    def trim() as string:
        pass

