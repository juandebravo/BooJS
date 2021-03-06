namespace BooJs.Lang.Globals

from BooJs.Lang.Extensions import TransformAttribute


class Object:
"""
Serves as base for all JS types
"""
    [Transform( $1 + $2 )]
    static def op_Addition(lhs as object, rhs as string) as string:
        pass

    static def getPrototypeOf(obj as object) as object:
        pass
    static def getOwnPropertyDescriptor(obj as object, prop as string) as PropertyDescriptor:
        pass
    static def getOwnPropertyNames(obj as object) as string*:
        pass
    static def create(obj as object) as object:
        pass
    static def create(obj as object, properties as PropertyDescriptorMap) as object:
        pass
    static def defineProperty(obj as object, p as string, attributes as PropertyDescriptor) as object:
        pass
    static def defineProperties(obj as object, properties as PropertyDescriptorMap) as object:
        pass
    static def seal(obj as object) as object:
        pass
    static def freeze(obj as object) as object:
        pass
    static def preventExtensions(obj as object) as object:
        pass
    static def isSealed(obj as object) as bool:
        pass
    static def isFrozen(obj as object) as bool:
        pass
    static def isExtensible(obj as object) as bool:
        pass
    static def keys(obj as object) as string*:
        pass


    public prototype as Object

    def hasOwnProperty(key as string) as bool:
        pass

    def isPrototypeOf(obj as object) as bool:
        pass

    virtual def toString() as string:
        pass

    virtual def toLocaleString() as string:
        pass

    def valueOf() as Object:
        pass

    def propertyIsEnumerable(name as string) as bool:
        pass


    # ECMAScript 5th Edition

    # These are no real classes in Javascript
    internal class PropertyDescriptor:
        configurable as bool?
        enumerable as bool?
        value as object
        writable as bool?
        _get as callable
        _set as callable

    internal class PropertyDescriptorMap:
        self[key as string] as PropertyDescriptor:
            get: pass
            set: pass


