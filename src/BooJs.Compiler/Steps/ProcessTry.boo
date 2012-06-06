namespace BooJs.Compiler.Steps

import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.Steps

class ProcessTry(AbstractTransformerCompilerStep):
"""
    Process try/except/ensure statements

    The main difference between Boo and JS is that in Boo we can define multiple except
    blocks and also offers a failure block. This modification will reduce the number of excepts
    to just one, including the additional branching as if conditions inside it.

        try:
            raise 'error'
        except a == b:
            print 'Exception cached when a==b'
        except as Exception:
            print 'Exception catched'
        except e as Exception:
            print e.ToString()
        except e:
            print e.message
        failure:
            print 'failed (but not catched)'
        ensure:
            pass

        --- gets converted to ---

        try:
            raise 'error'
        except __e:
            if a == b:                  # except a==b
                print 'Exception cached when a==b'
            elif __e isa Exception:     # except as Exception
                print 'Exception catched'
            elif __e isa Exception:     # except e as Exception
                e = __e
                print e.ToString()
            elif true:                  # except e
                e = __e
                print e.message
            else:                       # failure
                print 'failed (but not catched)'
                raise __e
        ensure:
            print 'run if all ok or not catched'
"""
    override def Run():
        if len(Errors) > 0:
            return
        Visit CompileUnit

    def OnTryStatement(node as TryStatement):
        # Generate a fixed handler
        handler = ExceptionHandler()
        handler.Declaration = Declaration(Name:'__e')

        # TODO: FilterCondition can apply even if a declaration is given
        #   ie: except ex as MyError if a == b:

        # Convert excepts to if conditions
        block = handler.Block
        for hdl in node.ExceptionHandlers:
            cond = IfStatement()
            block.Add(cond)

            # except e as Exception
            if hdl.Declaration and hdl.Declaration.Name and hdl.Declaration.Type:
                reference = ReferenceExpression(Name: hdl.Declaration.Name)
                cond.Condition = [| __e isa $(hdl.Declaration.Type) and $reference = __e |]
            # except e
            elif hdl.Declaration and hdl.Declaration.Name:
                cond.Condition = [| $(hdl.Declaration.Name) = __e |]
            # except as Exception
            elif hdl.Declaration and hdl.Declaration.Type:
                cond.Condition = [| __e isa $(hdl.Declaration.Type) |]

            # except a == b
            if hdl.FilterCondition:
                cond.Condition = [| $(cond.Condition) and $(hdl.FilterCondition) |]

            # Add the statements to the condition
            cond.TrueBlock = hdl.Block
            block = cond.FalseBlock = Block()

        # If none of the conditions match include the failure block
        if node.FailureBlock:
            for st in node.FailureBlock.Statements:
                block.Add(st as Statement)

            # Rethrow again the error
            block.Add([| raise __e |])
            node.FailureBlock = null

        # Replace original handlers with the generated one
        node.ExceptionHandlers.Clear()
        node.ExceptionHandlers.Add(handler)

        # Recurse into the single handler and the ensure block
        Visit node.ProtectedBlock
        Visit node.ExceptionHandlers
        Visit node.EnsureBlock
