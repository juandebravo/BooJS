namespace BooJs.Compiler.Steps

from Boo.Lang.Environments import my
from Boo.Lang.Compiler.Ast import *
from Boo.Lang.Compiler.Steps import AbstractTransformerCompilerStep
from Boo.Lang.Compiler.TypeSystem import *
from Boo.Lang.Compiler import CompilerContext
from Boo.Lang.PatternMatching import *

from BooJs.Compiler.TypeSystem import RuntimeMethodCache


class NormalizeLoops(AbstractTransformerCompilerStep):
"""
    Normalize loops

    The current implementation is very naive, it won't inspect the type system to
    choose a proper loop strategy. This should be done in the future using a compiler
    step.

    - If it contains a return convert to a while loop
    - If it contains a yield statement it's converted to an equivalent while loop.
    - If it has an Or or Then block it's converted to a while loop
    - If it is an array we convert it to a for in range
    - When the iterator is the range method it's left to be optimized when converting 
      to the Mozilla AST
    - If iterator is not an array iterate it with Boo.each()


    for i in arr:
    ---
    for _idx_ in range(len(arr)):
        i = arr[_idx_]

    for x, y in arr:
    ---
    for _idx_ in range(len(arr)):
        x, y = arr[_idx_]

    for i in iter:
    ---
    Boo.each(iter) do (i):
        pass


    for i in ducky():
    ---
    _for1_ = Boo.generator(ducky())
    try:
        while @(i = _for_.next(), true):
            pass
    except e if e is Boo.STOP:
        pass
    ensure:
        _for1_.close()


    Boo's for statement does not allow to specify a receiving variable for the key like it's
    done in CoffeeScript (for v, k in hash), however it allows to define multiple variables
    for unpacking. So the solution is to disable the support for unpacking and use it instead
    to obtain the key.

        for v, k in obj: ...
        ---
        Boo.each(obj, {v,k| ...})
"""

    class ClosureWrapper(DepthFirstTransformer):
    """ Boo ensures that closures inside loops capture also the state of the loop
        declarations. To allow this in JavaScript we wrap closures in self executing
        functions.

        for i in range(3):              | for i in range(3):
            result[i] = { i + 2 }       |     result[i] = {i| { i + 2 } }(i)
    """
        _decls as DeclarationCollection

        def constructor(decls as DeclarationCollection):
            _decls = decls

        def OnBlockExpression(node as BlockExpression):
            wrapper = [| { return $node } |]
            mie = MethodInvocationExpression(node.LexicalInfo)
            mie.Target = wrapper

            for decl in _decls:
                pd = ParameterDeclaration(decl.LexicalInfo, Name: decl.Name, Type: decl.Type)
                wrapper.Parameters.Add(pd)
                mie.Arguments.Add(ReferenceExpression(decl.Name))

            ReplaceCurrentNode(mie)


    class NodeFinder(DepthFirstVisitor):
        property Accepted as (NodeType)
        property Skipped as (NodeType) = (,)

        _found as bool

        def Run(node as Node) as bool:
            _found = false
            Visit(node)
            return _found

        override def Visit(node as Node):
            if node is null or _found:
                return
            elif node.NodeType in Accepted:
                _found = true
                return
            elif node.NodeType in Skipped:
                return
            else:
                super(node)

    _yieldFinder = NodeFinder(
        Accepted: (NodeType.YieldStatement,),
        Skipped: (NodeType.Method, NodeType.BlockExpression)
    )

    _returnFinder = NodeFinder(
        Accepted: (NodeType.ReturnStatement,),
        Skipped: (NodeType.Method, NodeType.BlockExpression)
    )

    [getter(MethodCache)]
    _methodCache as RuntimeMethodCache

    property CurrentMethod as Method

    override def OnMethod(node as Method):
        prev = CurrentMethod
        CurrentMethod = node
        super(node)
        CurrentMethod = prev

    override def OnConstructor(node as Constructor):
        prev = CurrentMethod
        CurrentMethod = node
        super(node)
        CurrentMethod = prev

    override def Initialize(ctxt as CompilerContext):
        super(ctxt)
        _methodCache = my(RuntimeMethodCache)

    override def Run():
        if len(Errors) > 0:
            return
        Visit CompileUnit

    protected def HasYield(node as Node):
        return _yieldFinder.Run(node)

    protected def HasReturn(node as Node):
        return _returnFinder.Run(node)

    protected def IsLiteralRange(node as Node):
        # We only support optimizations for simple ranges with positive integers
        if mie = node as MethodInvocationExpression and entity = mie.Target.Entity:
            if entity is MethodCache.Range1 and ile = mie.Arguments[0] as IntegerLiteralExpression:
                return ile.Value >= 0
            if entity is MethodCache.Range2 and ile1 = mie.Arguments[0] as IntegerLiteralExpression and \
               ile2 = mie.Arguments[1] as IntegerLiteralExpression:
                return ile1.Value >= 0 and ile1.Value <= ile2.Value

        return false

    protected def IsArray(node as Expression):
        # TODO: Detect Globals.Array here too?
        type = GetExpressionType(node)
        return type and type.IsArray

    protected def WrapClosures(node as ForStatement):
        wrapper = ClosureWrapper(node.Declarations)
        wrapper.Visit(node.Block)

    protected def ForToWhile(node as ForStatement) as Statement:
        # Make sure any nested loops are processed too
        Visit node.Block
        Visit node.OrBlock
        Visit node.ThenBlock

        mie = CodeBuilder.CreateMethodInvocation([| Boo.generator |], MethodCache.Generator, node.Iterator)
        tmpref = TempLocalInMethod(CurrentMethod, mie.ExpressionType, Context.GetUniqueName('for'))

        eval = CodeBuilder.CreateEvalInvocation(node.LexicalInfo)
        if len(node.Declarations) > 1:
            tmpupk = TempLocalInMethod(CurrentMethod, node.Iterator.ExpressionType, Context.GetUniqueName('upk'))
            eval.Arguments.Add([| $tmpupk = $(tmpref).next() |])
            for i as int, decl as Declaration in enumerate(node.Declarations):
                eval.Arguments.Add([| $(ReferenceExpression(decl.Name)) = $tmpupk[$i] |])
        else:
            eval.Arguments.Add([| $(ReferenceExpression(node.Declarations[0].Name)) = $(tmpref).next() |])

        # Make sure we always enter the loop
        eval.Arguments.Add(BoolLiteralExpression(Value: true))

        whilest = WhileStatement(node.LexicalInfo)
        whilest.Condition = [| $tmpref and $eval |]
        whilest.Block = node.Block

        result = [|
            $tmpref = $mie
            try:
                $whilest
            # HACK: The generator rewriter is a bit dumb, let's help him
            #except _ex_ if _ex_ is Boo.STOP:
            #    pass
            except _ex_:
                if _ex_ is not Boo.STOP:
                    raise
            ensure:
                $tmpref.close()
        |]

        # Handle `or` and `then` blocks. Or is executed when the iterator
        # is empty while Then executes when the iterator has been fully
        # exhausted. 
        if node.OrBlock or node.ThenBlock:
            # Create a flag with Or and Then enabled by default
            flagref = TempLocalInMethod(CurrentMethod, TypeSystemServices.IntType, Context.GetUniqueName('flag'))
            result.Insert(1, [| $flagref = Boo.LOOP_OR | Boo.LOOP_THEN |])

            if node.OrBlock:
                # Unset the Or flag once we enter the loop
                whilest.Block.Insert(0, [| $flagref &= ~Boo.LOOP_OR |])
                st = [|
                    if $flagref & Boo.LOOP_OR:
                        $(node.OrBlock)
                |]
                result.Add(st)

            if node.ThenBlock:
                # Unset the Then flag if we find a break in the loop body
                FlagBreaks(flagref, whilest.Block)
                st = [|
                    if $flagref & Boo.LOOP_THEN:
                        $(node.ThenBlock)
                |]
                result.Add(st)

        return result

    protected def ForToEach(node as ForStatement) as Statement:
        # Handle nested loops
        Visit node.Block

        ProcessContinueBreakForEach(node.Block)

        # TODO: Unlike Boo, the loop declarations are bound to the loop scope
        callback = BlockExpression(Body: node.Block)
        for decl in node.Declarations:
            param = ParameterDeclaration(decl.Name, decl.Type, LexicalInfo: decl.LexicalInfo)
            callback.Parameters.Add(param)

        # Use the runtime helper to iterate
        each = CodeBuilder.CreateMethodReference(MethodCache.Each)
        mie = [| $each($(node.Iterator), $callback) |]
        return ExpressionStatement(mie)

    protected def ForToIndex(node as ForStatement) as Statement:
    """ Converts a for-in loop iterating over the values of an Array to a loop
        iterating over the indexes in that Array. The is allow to later optimize
        the `range` based loop.

            for v in items:
            ---
            for i in range(items.length):
                v = items[i]

    """

        Visit node.Block

        result = Block()
        result.Add(node)

        # If the target iterator is already a reference there is no need to alias it to a temp
        iter as ReferenceExpression
        if node.Iterator.NodeType == NodeType.ReferenceExpression:
            iter = node.Iterator
        else:
            ent as IType
            if node.Iterator.NodeType == NodeType.ArrayLiteralExpression:
                ent = ((node.Iterator as ArrayLiteralExpression).Type.Entity as ITypedEntity).Type
            else:
                ent = node.Iterator.ExpressionType.ElementType

            iter = TempLocalInMethod(CurrentMethod, ent, Context.GetUniqueName('for'))
            result.Insert(0, [| $iter = $(node.Iterator) |])

        # Create a temporary variable to hold the iteration index
        tmpidx = TempLocalInMethod(CurrentMethod, TypeSystemServices.IntType, Context.GetUniqueName('idx'))

        # Handle declaration unpacking
        decls = node.Declarations
        if len(decls) > 1:
            eval = CodeBuilder.CreateEvalInvocation(node.LexicalInfo)
            tmpupk = TempLocalInMethod(CurrentMethod, node.Iterator.ExpressionType, Context.GetUniqueName('upk'))
            eval.Arguments.Add([| $tmpupk = $iter[$tmpidx] |])
            for i as int, decl as Declaration in enumerate(decls):
                eval.Arguments.Add([| $(ReferenceExpression(decl.Name)) = $tmpupk[$i] |])
            node.Block.Insert(0, eval)
        else:
            node.Block.Insert(0, [| $(ReferenceExpression(decls[0].Name)) = $iter[$tmpidx] |])

        # Replace any declarations by the temporal variable holding the index
        decls.Clear()
        decls.Add(Declaration(Name: tmpidx.Name))

        # Override the iterator so we iterate over the indexes
        node.Iterator = CodeBuilder.CreateMethodInvocation(
            [| BooJs.Lang.Builtins.range |], 
            MethodCache.Range1, 
            [| $iter.length |])

        return result

    override def OnForStatement(node as ForStatement):
        # Make sure we only normalize once
        return if node.ContainsAnnotation('for-normalized')
        node['for-normalized'] = true

        # If it contains a yield statement or has and Or or Then block
        if HasYield(node) or node.OrBlock or node.ThenBlock:
            WrapClosures(node)
            ReplaceCurrentNode ForToWhile(node)
        # Check if it can be optimized in the generated output
        elif IsLiteralRange(node.Iterator):
            WrapClosures(node)
            # Nothing to do here, we will process it before generating the Javascript
            TempLocalInMethod(CurrentMethod, TypeSystemServices.IntType, node.Declarations[0].Name)
            Visit node.Block
        # If it's an array create an optimizable version of the loop
        elif IsArray(node.Iterator):
            WrapClosures(node)
            ReplaceCurrentNode ForToIndex(node)
        # If it has a return statement use a while
        elif HasReturn(node):
            WrapClosures(node)
            ReplaceCurrentNode ForToWhile(node)
        # Any other case uses the Boo.each runtime method to handle the iteration
        else:
            ReplaceCurrentNode ForToEach(node)

    override def LeaveWhileStatement(node as WhileStatement):
        if node.OrBlock or node.ThenBlock:
            ReplaceCurrentNode ProcessWhile(node)

    protected def ProcessWhile(node as WhileStatement) as Statement:
        tmpref = TempLocalInMethod(CurrentMethod, TypeSystemServices.IntType, Context.GetUniqueName('flag'))
        result = [|
            $tmpref = Boo.LOOP_OR | Boo.LOOP_THEN
            while $(node.Condition):
                $tmpref &= ~Boo.LOOP_OR
                $(node.Block)
        |]

        if node.OrBlock and not node.OrBlock.IsEmpty:
            st = [|
                if $tmpref & Boo.LOOP_OR:
                    $(node.OrBlock)
            |]
            result.Add(st)

        if node.ThenBlock and not node.ThenBlock.IsEmpty:
            FlagBreaks(tmpref, node.Block)
            st = [|
                if $tmpref & Boo.LOOP_THEN:
                    $(node.ThenBlock)
            |]
            result.Add(st)

        return result

    protected def TempLocalInMethod(method as Method, type as IType, name as string):
        def exists(name):
            found = false
            for local in method.Locals:
                if local.Name == name:
                    found = true
                    break
            return found

        # Find a name that doesn't exists
        cnt = 1
        while exists(name):
            name = name + cnt
            cnt++

        # Reference the local in the method
        CodeBuilder.DeclareLocal(method, name, type)
        return ReferenceExpression(Name:name)

    protected def ProcessContinueBreakForEach(node as Block) as void:
    """ Replaces the continue keyword with a return and the break one with a return of Boo.STOP
    """
        for st in node.Statements:
            match st:
                case ContinueStatement():
                    node.Replace(st, ReturnStatement(st.LexicalInfo))
                case BreakStatement():
                    boo = CodeBuilder.CreateTypedReference('Boo', TypeSystemServices.BuiltinsType)
                    node.Replace(st, ReturnStatement(st.LexicalInfo, Expression: [| $boo.STOP |]))
                case bst=Block():
                    ProcessContinueBreakForEach(bst)
                case ist=IfStatement():
                    ProcessContinueBreakForEach(ist.TrueBlock)
                    ProcessContinueBreakForEach(ist.FalseBlock) if ist.FalseBlock
                case tst=TryStatement():
                    ProcessContinueBreakForEach(tst.ProtectedBlock)
                    for hdlr in tst.ExceptionHandlers:
                        ProcessContinueBreakForEach(hdlr.Block)
                    ProcessContinueBreakForEach(tst.EnsureBlock) if tst.EnsureBlock
                otherwise:
                    continue

    protected def FlagBreaks(tmpref as ReferenceExpression, block as Block):
    """ Prepends all break statements with an unflagging operation for the Then block
    """
        for st in block.Statements:
            match st:
                case blk=Block():  # HACK: Work around nested blocks from transformations
                    FlagBreaks(tmpref, blk)
                case ist=IfStatement():
                    FlagBreaks(tmpref, ist.TrueBlock)
                    FlagBreaks(tmpref, ist.FalseBlock) if ist.FalseBlock
                case ust=UnlessStatement():
                    FlagBreaks(tmpref, ust.Block)
                case tst=TryStatement():
                    FlagBreaks(tmpref, tst.ProtectedBlock)
                    FlagBreaks(tmpref, tst.EnsureBlock) if tst.EnsureBlock
                    for hdlr in tst.ExceptionHandlers:
                        FlagBreaks(tmpref, hdlr.Block)
                        # TODO: Generators replace break statements for exception handlers
                        #       looking for `Boo.STOP`. Here we assume that any exception
                        #       handler that reaches the end is a `Boo.STOP`, not 100% correct
                        #       but should cover most cases.
                        hdlr.Block.Add([| $tmpref &= ~Boo.LOOP_THEN |])
                case fst=ForStatement():
                    FlagBreaks(tmpref, fst.OrBlock) if fst.OrBlock
                    FlagBreaks(tmpref, fst.ThenBlock) if fst.ThenBlock
                case BreakStatement():
                    idx = block.Statements.IndexOf(st)
                    block.Insert(idx, [| $tmpref &= ~Boo.LOOP_THEN |])
                    return
                otherwise:
                    continue
