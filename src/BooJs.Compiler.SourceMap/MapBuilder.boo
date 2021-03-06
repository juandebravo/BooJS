namespace BooJs.Compiler.SourceMap

from System.Collections.Generic import Dictionary
import System.Web.Script.Serialization(JavaScriptSerializer) from 'System.Web.Extensions'


class MapBuilder:
""" 
    Spec: https://docs.google.com/a/pollinimini.net/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k

    Note: We can use this visualization tool to check if the generated source maps
          are any good: http://sokra.github.io/source-map-visualization

    TODO: Support 'data urls' to embed the source map in the generated js file comment
    TODO: Support `sourcesContent` to provide original Boo code embedded in the map
"""

    final static VERSION = 3

    [Property(SourceRoot)]
    sourceRoot as string

    [Property(File)]
    file as string

    sources = List[of string]()
    names = List[of string]()
    mappings = List[of string]()
    segments = List[of string]()

    last_source as int
    last_tcolumn as int
    last_tline as int
    last_name as int
    last_scolumn as int
    last_sline as int

    protected def SourceIdx(source as string):
        idx = sources.IndexOf(source)
        if idx < 0:
            idx = len(sources)
            sources.Add(source)
        return idx

    protected def NameIdx(name as string):
        idx = names.IndexOf(name)
        if idx < 0:
            idx = len(names)
            names.Add(name)
        return idx

    protected def encode(value as int):
        return Base64VLQ.encode(value)

    protected def encode(value as int, offset as int):
        return encode(value - offset)

    def Map(source as string, sline as int, scolumn as int, tline as int, tcolumn as int, ident as string):
        # Adjust new lines
        while last_tline < tline:
            last_tcolumn = 0
            last_tline += 1
            mappings.Add(join(segments, ','))
            segments.Clear()

        # The generated column
        segment = encode(tcolumn, last_tcolumn)
        last_tcolumn = tcolumn

        # The source file
        idx = SourceIdx(source)
        segment += encode(idx, last_source)
        last_source = idx

        # The source line and column
        segment += encode(sline, last_sline)
        last_sline = sline
        segment += encode(scolumn, last_scolumn)
        last_scolumn = scolumn

        if ident:
            idx = NameIdx(ident)
            segment += encode(idx, last_name)
            last_name = idx

        segments.Add(segment)


    def ToDict():
        # Make sure we have added all the segments
        if len(segments):
            mappings.Add(segments.Join(','))

        d = Dictionary[of string,object]()
        d.Add('version', VERSION)
        d.Add('file', file)
        d.Add('sourceRoot', SourceRoot) if SourceRoot
        d.Add('sources', sources.ToArray())
        d.Add('names', names.ToArray())
        d.Add('mappings', mappings.Join(';'))

        return d

    def ToJSON() as string:
        js = JavaScriptSerializer()
        return js.Serialize(ToDict())
