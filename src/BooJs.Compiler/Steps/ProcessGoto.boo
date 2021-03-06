namespace BooJs.Compiler.Steps

from Boo.Lang.Compiler.Ast import *
from Boo.Lang.Compiler.Steps import AbstractTransformerCompilerStep


class ProcessGoto(AbstractTransformerCompilerStep):
"""
    Process labels and goto statements

    The supported uses are limited. It's only possible to jump to a label
    previously defined in the same function. No jumps to forward labels are
    allowed.

    Even if fully supporting goto statements with forward jumping is theoretically
    possible (similarly on how generators are transformed for example), it would be
    difficult to implement for the benefits it provides.

    TODO: Check implementation constraints. Referenced label can only be present in 
          the same method and above the goto statement

    TODO: Implementing forward gotos could be made by using exceptions.

        while true:           |  try:
          goto end            |    while true:
          print 'foo'         |      raise Boo.GotoError('end')
        :end                  |      print 'foo'
                              |  except ex as GotoError and ex.message == 'end':
                              |    pass                              
"""
    override def Run():
        if len(Errors) > 0:
            return
        Visit CompileUnit

    def OnLabelStatement(node as LabelStatement):
        # Make sure we only process the statement once
        if node.ContainsAnnotation(self):
            return

        node.Annotate(self)

        parent = node.ParentNode as Block
        index = parent.Statements.IndexOf(node)

        loop = [| 
            while true: pass 
        |]
        loop.Block.Statements = parent.Statements.PopRange(index+1)
        # We need to break out of the loop when we reach the end :)
        loop.Block.Statements.Add(BreakStatement())

        parent.Statements.Add(loop)
                        

