namespace BooJs.Lang.Globals

import BooJs.Lang.Extensions

import System.Collections(IList, IEnumerable, ICollection)

class Array(Object, IList):

    [Transform( Boo.Array.op_Equality($1, $2) )]
    static def op_Equality(lhs as Array, rhs as Array) as bool:
        pass
    #[Transform( Boo.Array.op_Equality($1, $2) )]
    #static def op_Equality(lhs as object*, rhs as object*) as bool:
    #    pass
    [Transform( Boo.Array.op_Member($1, $2) )]
    static def op_Member(lhs as Array, rhs as object) as bool:
        pass
    [Transform( not Boo.Array.op_Member($1, $2) )]
    static def op_NotMember(lhs as Array, rhs as object) as bool:
        pass
    [Transform( Boo.Array.op_Addition($1, $2) )]
    static def op_Addition(lhs as Array, rhs as Array) as Array:
        pass
    [Transform( Boo.Array.op_Multiply($1, $2) )]
    static def op_Multiply(lhs as Array, rhs as int) as Array:
        pass


    self[index as int] as object:
        [Transform( $0[$1] )]
        get: pass
        [Transform( $0[$1] = $2 )]
        set: pass

    public length as uint

    def constructor():
        pass
    def constructor(n as int):
        pass

    # HACK: Emulate multiple params in a Javascript compatible way (up to 3 elements)
    def push(itm as object) as uint:
        pass
    def push(itm1 as object, itm2 as object) as uint:
        pass
    def push(itm1 as object, itm2 as object, itm3 as object) as uint:
        pass

    def pop() as object:
        pass

    def reverse() as Array:
        return self

    def shift() as object:
        pass

    def sort() as Array:
        return self

    def sort(comp as callable) as Array:
        return self

    def splice(index as int, cnt as int, *elems as (object)) as Array:
        return self
        
    def splice(index as int, cnt as int) as Array:
        return self

    def splice(index as int) as Array:
        return self

    # HACK: Emulate multiple params in a Javascript compatible way (up to 3 elements)
    def unshift(itm1 as object) as uint:
        pass
    def unshift(itm1 as object, itm2 as object) as uint:
        pass
    def unshift(itm1 as object, itm2 as object, itm3 as object) as uint:
        pass

    # HACK: Emulate multiple params in a Javascript compatible way (up to 3 elements)
    def concat(itm1 as Array) as Array:
        pass
    def concat(itm1 as Array, itm2 as Array) as Array:
        pass
    def concat(itm1 as Array, itm2 as Array, itm3 as Array) as Array:
        pass

    def join(sep as string) as string:
        pass

    def slice(start as int, stop as int) as Array:
        pass

    def slice(start as int) as Array:
        pass

    def indexOf(itm as object, start as int) as int:
        pass

    def indexOf(itm as object) as int:
        pass

    def lastIndexOf(itm as object, start as int) as int:
        pass

    def lastIndexOf(itm as object) as int:
        pass


    def filter(callback as callable, context as object) as Array:
        pass
    def filter(callback as callable) as Array:
        pass

    def forEach(callback as callable, context as object) as void:
        pass
    def forEach(callback as callable) as void:
        pass

    def every(callback as callable, context as object) as bool:
        pass
    def every(callback as callable) as bool:
        pass

    def map(callback as callable, context as object) as Array:
        pass
    def map(callback as callable) as Array:
        pass

    def some(callback as callable, context as object) as bool:
        pass
    def some(callback as callable) as bool:
        pass

    def reduce(callback as callable, initialValue as object) as object:
        pass
    def reduce(callback as callable) as object:
        pass

    def reduceRight(callback as callable, initialValue as object) as object:
        pass
    def reduceRight(callback as callable) as object:
        pass


    # Ecma 5th edition

    static def isArray(arg as object) as bool:
        pass

