namespace BooJs.Compiler.Utils

from Boo.Lang.Compiler import *
from Boo.Lang.Compiler.TypeSystem import *
from Boo.Lang.Compiler.TypeSystem.Services import *
from Boo.Lang.Compiler.Ast import *

from Boo.Lang.Environments import my
from Boo.Lang.PatternMatching import *

from BooJs.Lang.Extensions import ExternAttribute


def isExtern(node as Node):
    entity = node.Entity as Reflection.ExternalType
    return false if not entity
    return isExtern(entity.ActualType)

def isExtern(fqn as string):
    srv = my(NameResolutionService)
    entity = srv.ResolveQualifiedName(fqn) as Reflection.ExternalType
    return false if not entity
    return isExtern(entity.ActualType)

def isExtern(info as System.Reflection.MemberInfo):
    attr = System.Attribute.GetCustomAttribute(info, typeof(BooJs.Lang.Extensions.ExternAttribute), false)
    return attr is not null

def isFactory(node as Node):
    match node.Entity:
        case it=Internal.InternalConstructor():
            # TODO: Obtain attribute from internal type
            return false
        case et=Reflection.ExternalType():
            attr as ExternAttribute = System.Attribute.GetCustomAttribute(et.ActualType, typeof(ExternAttribute), false)
            return (attr.Factory if attr else false)
        otherwise:
            return false


def resolveRuntimeMethod(methodName as string):
    return resolveMethod(typeSystem().RuntimeServicesType, methodName)
    
def resolveMethod(type as IType, name as string):
    return nameResolutionService().ResolveMethod(type, name)
    
def bindingFor(node as Node):
    return typeSystem().GetEntity(node)
    
def bindingFor(node as Method) as IMethod:
    return typeSystem().GetEntity(node)
    
def erasureFor(type as IType):
    if type isa IGenericParameter:
        return typeSystem().ObjectType
    
    #genericInstance = type.ConstructedInfo
    #if genericInstance is not null:
    #   return genericInstance.GenericDefinition
        
    return type
        
def definitionFor(m as IMethodBase) as IMethodBase:
    if m.DeclaringType.ConstructedInfo is null:
        return m
    # TODO: What do we need this for
    #return Boojs.Compilation.TypeSystem.GenericMethodDefinitionFinder(m).find()
    raise 'GenericMethodDefinitionFinder not implemented'

def typeOf(e as Expression) as IType:
    match e:
        case [| null |]:
            return Null.Default
        case [| true |] | [| false |]:
            return typeSystem().BoolType
        otherwise:
            return typeSystem().GetExpressionType(e)

def typeSystem():
    return my(TypeSystemServices)
    
def nameResolutionService():
    return my(NameResolutionService)
    
def context():
    return CompilerContext.Current
    
def uniqueName():
    return context().GetUniqueName("$")
    
def uniqueReference():
    return ReferenceExpression(uniqueName())
