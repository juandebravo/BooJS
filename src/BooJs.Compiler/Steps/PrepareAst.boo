namespace BooJs.Compiler.Steps

import Boo.Lang.Compiler
import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.Steps

import Boo.Lang.Environments
import Boo.Lang.Compiler.TypeSystem.Services.RuntimeMethodCache as BooRuntimeMethodCache
import BooJs.Compiler.TypeSystem(RuntimeMethodCache)
import BooJs.Lang.Extensions


class PrepareAst(AbstractTransformerCompilerStep):
"""
    Prepare the AST for its conversion to Javascript

        - Remove unneeded nodes
        - Convert builtins and runtime references

"""
    [getter(MethodCache)]
    private _methodCache as RuntimeMethodCache

    [getter(BooMethodCache)]
    private _booMethodCache as BooRuntimeMethodCache


    protected def GetAttribute[of T(System.Attribute)](node as Node) as T:
        entity = node.Entity as TypeSystem.IExternalEntity
        return (GetAttribute[of T](entity) if entity else null as T)

    protected def GetAttribute[of T(System.Attribute)](entity as TypeSystem.IExternalEntity) as T:
        return System.Attribute.GetCustomAttribute(entity.MemberInfo, typeof(T))

    protected def IsBuiltin(node as Node) as bool:
        entity = node.Entity as TypeSystem.Reflection.ExternalType
        if not entity and centity = node.Entity as TypeSystem.ExternalMethod:
            entity = centity.DeclaringType

        return false if not entity
        return true if entity.Type is TypeSystemServices.BuiltinsType
        return entity.DeclaringType == TypeSystemServices.BuiltinsType

    protected def IsGlobal(node as Node) as bool:
        if entity = node.Entity as TypeSystem.Reflection.ExternalType:
            return entity.ActualType.Namespace == 'BooJs.Lang.Globals'

        return false

    def Initialize(context as CompilerContext):
        super(context)

        _methodCache = EnvironmentProvision[of RuntimeMethodCache]()
        _booMethodCache = EnvironmentProvision[of BooRuntimeMethodCache]()

    def EnterModule(node as Module):
        if node.Name == 'CompilerGenerated':
            RemoveCurrentNode()
            return false

        return true

    def EnterClassDefinition(node as ClassDefinition):
        if node.Name == 'CompilerGeneratedExtensions':
            RemoveCurrentNode()
            return false
        return true

    def OnExpressionStatement(node as ExpressionStatement):
        # Ignore the assignment of locals produced by closures instrumentation
        be = node.Expression as BinaryExpression
        if be and be.Operator == BinaryOperatorType.Assign and be.Left.ToString() == '$locals':
            RemoveCurrentNode
            return

        super(node)

    protected def ProcessReference(node as ReferenceExpression) as Node:
        if TransformAttribute.HasAttribute(node):
            result = TransformAttribute.Resolve(node, null)
            Visit result
            return result

        # Check for builtins references
        if IsBuiltin(node):
            name = node.Name.Split(char('.'))[-1]
            refe = [| Boo.$(ReferenceExpression(Name: name)) |].withLexicalInfoFrom(node)
            refe.Entity = node.Entity
            return refe

        # Entities in the Global namespace are never prefixed
        if IsGlobal(node):
            node.Name = node.Name.Split(char('.'))[-1]
            return node

        # Members of the module are placed in the top scope
        ientity = node.Entity as TypeSystem.IMember
        if ientity and ientity.DeclaringType and ientity.DeclaringType.IsClass and ientity.DeclaringType.IsFinal:
            name = node.Name.Split(char('.'))[-1]
            return [| $(ReferenceExpression(Name: name)) |].withLexicalInfoFrom(node)

        return node

    def OnReferenceExpression(node as ReferenceExpression):
        ReplaceCurrentNode ProcessReference(node)


    def OnMemberReferenceExpression(node as MemberReferenceExpression):
        if TransformAttribute.HasAttribute(node):
            result = TransformAttribute.Resolve(node, null)
            Visit result
            ReplaceCurrentNode result
            return

        # Convert from `$locals.$variable` to `variable`
        if node.Target.NodeType == NodeType.ReferenceExpression:
            if (node.Target as ReferenceExpression).Name == '$locals':
                refexp = ReferenceExpression(node.Name[1:], LexicalInfo: node.LexicalInfo)
                ReplaceCurrentNode refexp
                return

        # Members of the module are placed in the top scope
        ientity = node.Target.Entity as TypeSystem.Internal.AbstractInternalType
        if node.Target.IsSynthetic and ientity and ientity.IsClass and ientity.IsFinal:
            refexp = ReferenceExpression(node.Name, LexicalInfo: node.LexicalInfo)
            ReplaceCurrentNode refexp
            return

        # Check for builtins references
        if IsBuiltin(node.Target):
            node.Target = [| Boo |].withLexicalInfoFrom(node.Target)

        super(node)

    def OnMethodInvocationExpression(node as MethodInvocationExpression):
        # Convert Transform attribute metadata to an AST annotation
        if TransformAttribute.HasAttribute(node.Target):
            result = TransformAttribute.Resolve(node.Target, node.Arguments)
            result = VisitNode(result)
            ReplaceCurrentNode result
            return


        # Eval calls take the form: @( stmt1, stmt2, ...., return_stmt )
        # We convert them to a self invoking anonymous function that returns the last argument.
        #
        # TODO: Isn't this equivalent to Js ( expr1, expr2, expr3 ) ???
        #
        # Note: variables are declared in the enclosing scope, not wrapped in the function.
        if false and '@' == node.Target.ToString():
            bexpr = BlockExpression(LexicalInfo: node.Target.LexicalInfo)
            st as Statement
            for i, arg as Expression in enumerate(node.Arguments):

                if i == len(node.Arguments)-1:
                    st = ReturnStatement(LexicalInfo: arg.LexicalInfo, Expression: arg)
                else:
                    st = ExpressionStatement(LexicalInfo: arg.LexicalInfo, Expression: arg)

                bexpr.Body.Add(st)

            mie = MethodInvocationExpression(LexicalInfo: node.LexicalInfo)
            mie.Target = bexpr
            ReplaceCurrentNode mie
            Visit mie
            return

        super(node)

    def OnMethod(node as Method):
    """ Process locals and detect the Main method to move its statements into the Module globals
    """
        # Skip compiler generated methods
        if node.IsSynthetic and node.IsInternal:
            RemoveCurrentNode
            return

        # Convert locals back to simple declaration statements
        found = ['$locals']
        for local in node.Locals:
            # Avoid duplicates
            if local.Name is null or local.Name in found:
                continue

            found.Push(local.Name)

            decl = Declaration(LexicalInfo: local.LexicalInfo)
            decl.Name = local.Name

            # Detect local type
            initializer as Expression = NullLiteralExpression()
            entity = local.Entity as TypeSystem.Internal.InternalLocal
            if entity:
                if entity.OriginalDeclaration:
                    # Skip declarations for those flagged as global
                    continue if entity.OriginalDeclaration.ContainsAnnotation('global')
                    decl.Type = entity.OriginalDeclaration.Type
                else:
                    # TODO: Can we generate proper type annotations with this?
                    decl.Type = SimpleTypeReference(Entity: entity)

                # Initialize with a default value
                if TypeSystemServices.IsNumber(entity.Type):
                    initializer = IntegerLiteralExpression(0)
                elif entity.Type == TypeSystemServices.TimeSpanType:
                    initializer = IntegerLiteralExpression(0)
                elif entity.Type == TypeSystemServices.BoolType:
                    initializer = BoolLiteralExpression(false)
                elif entity.Type == TypeSystemServices.StringType:
                    initializer = StringLiteralExpression('')

            st = DeclarationStatement(LexicalInfo: local.LexicalInfo, Declaration: decl, Initializer: initializer)
            node.Body.Insert(0, st)


        # Detect the Main method and move its statements to the Module globals
        if ContextAnnotations.GetEntryPoint(Context) is node:
            Visit node.Body
            node.EnclosingModule.Globals = node.Body
            RemoveCurrentNode
            return

        super(node)

    def OnCastExpression(node as CastExpression):
        mie = [| Boo.$(ReferenceExpression('cast'))() |]
        mie.Arguments.Add(node.Target)
        mie.Arguments.Add(node.Type as Expression)
        ReplaceCurrentNode mie

    def OnTryCastExpression(node as TryCastExpression):
        mie = [| Boo.trycast() |]
        mie.Arguments.Add(node.Target)
        mie.Arguments.Add(node.Type as Expression)
        ReplaceCurrentNode mie

    def OnCharLiteralExpression(node as CharLiteralExpression):
    """ There is no char type in BooJs. char('c') and char(int) are converted to a string of length 1
    """
        ReplaceCurrentNode StringLiteralExpression(LexicalInfo: node.LexicalInfo, Value: node.Value.ToString())

    def OnRELiteralExpression(node as RELiteralExpression):
    """ Almost a direct translation to Javascript regexp literals. The only modification
        is that we ignore whitespace to allow the regexps to be somehow more readable while
        Boo's handling is to escape it as part of the match.

            / foo | bar /i  ->  /foo|bar/i
            @/ foo | bar /  ->  /foo|bar/i

        TODO: The ones prefixed with @ should be preprocessed to support new lines
    """
        re = node.Value
        start = re.IndexOf('/')
        stop = re.LastIndexOf('/')

        modifier = re[stop:]
        re = re[start:stop]

        # Ignore white space
        re = /\s+/.Replace(re, '')

        # Javascript does not support the single-line modifier (dot matches new lines).
        # We emulate it by converting dots to the [\s\S] expression in the regex.
        # NOTE: The algorithm will break when a dot is preceeded by an escaped back slash (\\.)
        if modifier.Contains('s'):
            re = /(?<!\\)\./.Replace(re, '[\\s\\S]')
            modifier = modifier.Replace('s', '')

        node.Value = re + modifier

    def OnArrayLiteralExpression(node as ArrayLiteralExpression):
    """ In BooJs arrays are muttable (Boo's Lists)
    """
        list = ListLiteralExpression(LexicalInfo: node.LexicalInfo, Items: node.Items)
        Visit list
        ReplaceCurrentNode list

    def OnUnlessStatement(node as UnlessStatement):
    """ Negate the condition to convert it into a simple if statement
    """
        ifst = IfStatement(LexicalInfo: node.LexicalInfo)
        ifst.Condition = UnaryExpression(
            Operator: UnaryOperatorType.LogicalNot,
            Operand: node.Condition,
            LexicalInfo: node.LexicalInfo
        )
        ifst.TrueBlock = node.Block

        ReplaceCurrentNode ifst

    def OnBinaryExpression(node as BinaryExpression):
        if node.Operator == BinaryOperatorType.TypeTest:
            mie = MethodInvocationExpression(node.LexicalInfo)
            mie.Target = ReferenceExpression(node.LexicalInfo, 'Boo.isa')
            mie.Arguments.Add(node.Left)
            mie.Arguments.Add(node.Right)
            Visit mie.Arguments
            ReplaceCurrentNode mie
            return

        super(node)

    def OnTypeofExpression(node as TypeofExpression):
        if st = node.Type as SimpleTypeReference:

            # Primitives are just enclosed as strings
            if TypeSystemServices.IsPrimitive(st.Name):
                ReplaceCurrentNode StringLiteralExpression(node.LexicalInfo, st.Name)
                return

            # If we have an entity use it
            if exent = st.Entity as TypeSystem.Reflection.ExternalType:
                refe = CodeBuilder.CreateReference(node.LexicalInfo, exent.ActualType)
                ReplaceCurrentNode ProcessReference(refe)
                return

            # Just rely on the type name
            refe = ReferenceExpression(node.LexicalInfo, st.Name)
            ReplaceCurrentNode ProcessReference(refe)

        else:
            raise 'Unsupported TypeReference: ' + node.Type + ' (' + node.Type.NodeType + ')'
