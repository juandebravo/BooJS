namespace BooJs.Compiler.Visitors

import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.TypeSystem
import Boo.Lang.PatternMatching

import BooJs.Compiler.Mozilla as Moz


class MozillaAstVisitor(FastDepthFirstVisitor):
"""
Transforms a Boo AST into a Mozilla AST
"""
    # Holds the latest conversion from Boo node to a Moz node
    _return as Moz.Node

    protected def Return(node as Moz.Node):
        _return = node

    protected def Apply(node as Node) as Moz.Node:
        _return = null
        Visit node
        return _return

    protected def loc(node as Node):
        obj = Moz.SourceLocation()
        obj.source = node.LexicalInfo.FileName
        obj.start = Moz.Position(line: node.LexicalInfo.Line, column: node.LexicalInfo.Column-1)

        # Compute an approximate end position if not available
        if node.EndSourceLocation and node.EndSourceLocation.Line >= 0:
            line, column = (node.EndSourceLocation.Line, node.EndSourceLocation.Column-1)
        else:
            parts = node.ToCodeString().Split(char('\n'))
            line, column = (node.LexicalInfo.Line, node.LexicalInfo.Column-1)
            if len(parts) > 1:
                line += len(parts) - 1
                column = 0
            column += len(parts[-1])

        obj.end = Moz.Position(line: line, column: column)

        return obj

    def Run(node as Node) as Moz.Node:
        Visit node
        return _return

    def OnBoolLiteralExpression(node as BoolLiteralExpression):
        Return Moz.Literal(loc: loc(node), value: node.Value)

    def OnNullLiteralExpression(node as NullLiteralExpression):
        Return Moz.Literal(loc: loc(node), value: null)

    def OnIntegerLiteralExpression(node as IntegerLiteralExpression):
        n as Moz.IExpression
        if node.Value < 0:
            n = Moz.Literal(loc: loc(node), value: -node.Value)
            n = Moz.UnaryExpression(loc: loc(node), operator: '-', argument: n)
         else:
            n = Moz.Literal(loc: loc(node), value: node.Value)

        Return n

    def OnDoubleLiteralExpression(node as DoubleLiteralExpression):
        n as Moz.IExpression
        if node.Value < 0:
            n = Moz.Literal(loc: loc(node), value: -node.Value)
            n = Moz.UnaryExpression(loc: loc(node), operator: '-', argument: n)
         else:
            n = Moz.Literal(loc: loc(node), value: node.Value)

        Return n

    def OnStringLiteralExpression(node as StringLiteralExpression):
        Return Moz.Literal(loc: loc(node), value: node.Value)

    def OnRELiteralExpression(node as RELiteralExpression):
        Return Moz.Literal(loc: loc(node), value: node.Value)

    def OnSelfLiteralExpression(node as SelfLiteralExpression):
        Return Moz.ThisExpression(loc: loc(node))

    def OnListLiteralExpression(node as ListLiteralExpression):
        n = Moz.ArrayExpression(loc: loc(node))
        for itm in node.Items:
            exp = Apply(itm)
            n.elements.Add(exp)
        Return n

    def OnHashLiteralExpression(node as HashLiteralExpression):
        n = Moz.ObjectExpression(loc: loc(node))
        for pair in node.Items:
            prop = Moz.ObjectExpressionProp(key: Apply(pair.First), value: Apply(pair.Second))
            n.properties.Add(prop)
        Return n

    def OnEnumDefinition(node as EnumDefinition):
        o = Moz.ObjectExpression(loc: loc(node))
        for member as EnumMember in node.Members:
            assert member.Initializer != null, 'Enum definition without an initializer value!'
            prop = Moz.ObjectExpressionProp(key: Moz.Literal(value: member.Name), value: Apply(member.Initializer))
            o.properties.Add(prop)

        # Assign the object to a variable
        v = Moz.VariableDeclarator(loc: loc(node))
        v.id = Moz.Identifier(loc: loc(node), name: node.FullName)
        v.init = o
        n = Moz.VariableDeclaration(loc: loc(node), kind: 'var')
        n.declarations.Add(v)

        Return n

    def OnModule(node as Module):
        n = Moz.Program(loc: loc(node))

        st as Moz.IStatement
        for member in node.Members:
            st = Apply(member)
            if st is null:
                continue

            if st isa Moz.BlockStatement:
                n.body += (st as Moz.BlockStatement).body
            else:
                n.body.Add(st)

        for global in node.Globals.Statements:
            st = Apply(global)
            n.body.Add(st)

        n['module'] = node

        Return n

    def OnClassDefinition(node as ClassDefinition):
        n = Moz.BlockStatement()

        st as Moz.IStatement
        for member in node.Members:
            st = Apply(member)
            if st is null:
                continue
            elif st isa Moz.BlockStatement:
                n.body += (st as Moz.BlockStatement).body
            else:
                n.body.Add(st)

        Return n

    def OnField(node as Field):
        pass

    def OnConstructor(node as Constructor):
        pass

    def OnMethod(node as Method):
        n = Moz.FunctionDeclaration(loc: loc(node))
        n.id = Moz.Identifier(loc: loc(node), name: node.Name)
        for param in node.Parameters:
            p = Moz.Identifier(loc: loc(param), name: param.Name)
            n.params.Add(p)

        b = Moz.BlockStatement()
        for local in node.Locals:
            st = Apply(local)
            b.body.Add(st) if st

        b.body += (Apply(node.Body) as Moz.BlockStatement).body
        n.body = b
        Return n

    def OnDeclarationStatement(node as DeclarationStatement):
        # TODO: Generate type annotated comments
        v = Moz.VariableDeclarator(loc: loc(node))
        v.id = Moz.Identifier(name: node.Declaration.Name)
        v.init = Apply(node.Initializer)

        vd = Moz.VariableDeclaration(loc: loc(node), kind: 'var')
        vd.declarations.Add(v)
        Return vd


    def OnBlock(node as Block):
        b = Moz.BlockStatement(loc: loc(node))
        for st in node.Statements:
            mst = Apply(st) as Moz.IStatement
            if mst:
                b.body.Add(mst)

        Return b

    def OnExpressionStatement(node as ExpressionStatement):
        n = Moz.ExpressionStatement(loc: loc(node))
        n.expression = Apply(node.Expression)
        Return n

    def OnReturnStatement(node as ReturnStatement):
        n = Moz.ReturnStatement(loc: loc(node))
        n.argument = Apply(node.Expression)
        Return n

    def OnIfStatement(node as IfStatement):

        ifst = Moz.IfStatement(loc: loc(node))
        ifst.test = Apply(node.Condition)
        ifst.consequent = Apply(node.TrueBlock)
        if node.FalseBlock:
            blk = node.FalseBlock
            if len(blk.Statements) == 1 and blk.FirstStatement isa IfStatement:
                ifst.alternate = Apply(blk.FirstStatement)
            else:
                ifst.alternate = Apply(blk)

        Return ifst

    def OnWhileStatement(node as WhileStatement):
        wst = Moz.WhileStatement(loc: loc(node))
        wst.test = Apply(node.Condition)
        wst.body = Apply(node.Block)

        Return wst

    def OnTryStatement(node as TryStatement):

        assert 1 == len(node.ExceptionHandlers), 'Multiple exceptions handlers should be processed in previous steps'

        n = Moz.TryStatement(loc: loc(node))
        n.block = Apply(node.ProtectedBlock)

        hdl = node.ExceptionHandlers[0]
        h = Moz.CatchClause(loc: loc(hdl))
        h.param = Moz.Identifier(loc: loc(hdl.Declaration), name: hdl.Declaration.Name)
        h.body = Apply(hdl.Block)

        n.handlers.Add(h)

        if node.EnsureBlock:
            n.finalizer = Apply(node.EnsureBlock)

        Return n

    def OnBreakStatement(node as BreakStatement):
        Return Moz.BreakStatement(loc: loc(node))

    def OnContinueStatement(node as ContinueStatement):
        Return Moz.ContinueStatement(loc: loc(node))

    def OnLabelStatement(node as LabelStatement):
        n = Moz.LabeledStatement(loc: loc(node))
        n.label = Moz.Identifier(loc: loc(node), name: node.Name)

        # In Mozilla AST the label statements are associated with an statement.
        stmts = (node.ParentNode as Block).Statements
        idx = stmts.IndexOf(node)
        st = stmts[idx + 1]
        stmts.RemoveAt(idx + 1)

        if st.NodeType not in (NodeType.ForStatement, NodeType.WhileStatement):
            raise 'Javascript only allows label on looping statements'
        n.body = Apply(st)

        Return n

    def OnGotoStatement(node as GotoStatement):
        n = Moz.ContinueStatement(loc: loc(node))
        n.label = Moz.Identifier(loc: loc(node.Label), name: node.Label.Name)
        Return n

    def OnRaiseStatement(node as RaiseStatement):
        # TODO: Move this to clean step
        /*
        if false and Context.Parameters.Debug:
            n = Moz.CallExpression(loc: loc(node))
            n.callee = Moz.MemberExpression(
                loc: loc(node),
                object: Moz.Identifier(name: 'Boo'),
                property: Moz.Identifier(name: 'raise')
            )
            # TODO: We should make sure it's a constructor
            if node.Exception isa MethodInvocationExpression:
                c = Moz.NewExpression(loc: loc(node.Exception))
                c._constructor = Apply(node.Exception)
                n.arguments.Add(c)
            else:
                n.arguments.Add(Apply(node.Exception))

            lex = node.Exception.LexicalInfo
            n.arguments.Add(Moz.Literal(value: lex.FileName))
            n.arguments.Add(Moz.Literal(value: lex.Line))

            Return Moz.ExpressionStatement(loc: loc(node), expression: n)
        else:
        */
        t = Moz.ThrowStatement(loc: loc(node))
        t.argument = Apply(node.Exception)
        # TODO: We should make sure it's a constructor
        /*
        if false and node.Exception isa MethodInvocationExpression:
            c = Moz.NewExpression(loc: loc(node.Exception))
            c._constructor = Apply(node.Exception)
            t.argument = c
        else:
        */

        Return t

    def OnReferenceExpression(node as ReferenceExpression):
        Return Moz.Identifier(loc: loc(node), name: node.Name)

    def OnMemberReferenceExpression(node as MemberReferenceExpression):
        # TODO: handle computed expressions
        n = Moz.MemberExpression(loc: loc(node), property: Moz.Identifier(loc: loc(node), name: node.Name))
        n.object = Apply(node.Target)
        Return n

    def OnConditionalExpression(node as ConditionalExpression):
    """ Convert to the ternary operator.
            (10 if true else 20)  -->  true ? 10 : 20
    """
        c = Moz.ConditionalExpression(loc: loc(node))
        c.test = Apply(node.Condition)
        c.consequent = Apply(node.TrueValue)
        c.alternate = Apply(node.FalseValue)
        Return c

    def OnSlicingExpression(node as SlicingExpression):
        n = Moz.MemberExpression(
            loc: loc(node),
            object: Apply(node.Target),
            property: Apply(node.Indices[0].Begin),
            computed: true
        )

        Return n

    def OnMethodInvocationExpression(node as MethodInvocationExpression):
        # Detect constructors
        if node.Target.Entity isa IConstructor:
            c = Moz.NewExpression(loc: loc(node))
            c._constructor = Apply(node.Target)
            for arg in node.Arguments:
                c.arguments.Add(Apply(arg))
            Return c
        else:
            n = Moz.CallExpression(loc: loc(node))
            n.callee = Apply(node.Target)
            for arg in node.Arguments:
                n.arguments.Add(Apply(arg))
            Return n

    def OnBlockExpression(node as BlockExpression):
        n = Moz.FunctionExpression(loc: loc(node))
        for param in node.Parameters:
            p = Moz.Identifier(loc: loc(param), name: param.Name)
            n.params.Add(p)

        n.body = Apply(node.Body)
        Return n

    def OnBinaryExpression(node as BinaryExpression):
        n = Moz.BinaryExpression(loc: loc(node))
        match node.Operator:
            case BinaryOperatorType.Equality:
                n.operator = '=='
            case BinaryOperatorType.Inequality:
                n.operator = '!='
            case BinaryOperatorType.ReferenceEquality:
                n.operator = '==='
            case BinaryOperatorType.ReferenceInequality:
                n.operator = '!=='
            case BinaryOperatorType.Member:
                n.operator = 'in'
            case BinaryOperatorType.Addition:
                n.operator = '+'
            case BinaryOperatorType.Subtraction:
                n.operator = '-'
            case BinaryOperatorType.Multiply:
                n.operator = '*'
            case BinaryOperatorType.Division:
                n.operator = '/'
            case BinaryOperatorType.Modulus:
                n.operator = '%'
            case BinaryOperatorType.BitwiseAnd:
                n.operator = '&'
            case BinaryOperatorType.BitwiseOr:
                n.operator = '|'
            case BinaryOperatorType.ExclusiveOr:
                n.operator = '^'
            case BinaryOperatorType.GreaterThan:
                n.operator = '>'
            case BinaryOperatorType.GreaterThanOrEqual:
                n.operator = '>='
            case BinaryOperatorType.LessThan:
                n.operator = '<'
            case BinaryOperatorType.LessThanOrEqual:
                n.operator = '<='
            case BinaryOperatorType.ShiftLeft:
                n.operator = '<<'
            case BinaryOperatorType.ShiftRight:
                n.operator = '>>'

            case BinaryOperatorType.Assign:
                n = Moz.AssignmentExpression(loc: loc(node), operator: '=')

            case BinaryOperatorType.And:
                n = Moz.LogicalExpression(loc: loc(node), operator: '&&')
            case BinaryOperatorType.Or:
                n = Moz.LogicalExpression(loc: loc(node), operator: '||')

            otherwise:
                raise 'Operator not supported ' + node.Operator

        n.left = Apply(node.Left)
        n.right = Apply(node.Right)
        Return n

    def OnUnaryExpression(node as UnaryExpression):
        match node.Operator:
            case UnaryOperatorType.UnaryNegation:
                n = Moz.UnaryExpression(loc: loc(node), operator: '-')
            case UnaryOperatorType.LogicalNot:
                n = Moz.UnaryExpression(loc: loc(node), operator: '!')
            case UnaryOperatorType.OnesComplement:
                n = Moz.UnaryExpression(loc: loc(node), operator: '~')
            case UnaryOperatorType.Increment:
                n = Moz.UpdateExpression(loc: loc(node), operator: '++', prefix: true)
            case UnaryOperatorType.Decrement:
                n = Moz.UpdateExpression(loc: loc(node), operator: '--', prefix: true)
            case UnaryOperatorType.PostIncrement:
                n = Moz.UpdateExpression(loc: loc(node), operator: '++', prefix: false)
            case UnaryOperatorType.PostDecrement:
                n = Moz.UpdateExpression(loc: loc(node), operator: '--', prefix: false)
            otherwise:
                raise 'Operator not supported ' + node.Operator

        n.argument = Apply(node.Operand)
        Return n