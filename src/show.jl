import HierarchicalUtils: NodeType, LeafNode, InnerNode, children, nodeshow, nodecommshow

@nospecialize

NodeType(::Type{<:Union{LeafEntry, Nothing}}) = LeafNode()
NodeType(::Type{<:Schema}) = InnerNode()
NodeType(::Type{<:LeafExtractor}) = LeafNode()
NodeType(::Type{<:Extractor}) = InnerNode()

children(e::Union{ArrayEntry, ArrayExtractor}) = isnothing(e.items) ? () : (e.items,)
children(e::Union{DictEntry, DictExtractor}) = e.children
children(e::PolymorphExtractor) = e.extractors
children(e::StableExtractor) = children(e.e)

@specialize

function Base.show(io::IO, ::MIME"text/plain", @nospecialize(e::Union{Schema, Extractor}))
    HierarchicalUtils.printtree(io, e; htrunc=5, vtrunc=10, breakline=false)
end

function Base.show(io::IO, ::MIME"text/plain",
    @nospecialize(e::Union{LeafExtractor, StableExtractor{<:LeafExtractor}}))
    print(io, nameof(typeof(e)))
    get(io, :compact, false) || _show_details(io, e)
end

function Base.show(io::IO, m::MIME"text/plain", @nospecialize(e::LeafEntry))
    print(io, "LeafEntry storing ")
    _show_types(io, e)
    if isempty(e.counts)
        print(io, ".")
    else
        s = sprint((io, x) -> show(io, m, x), e.counts; context=io)
        print(io, ":\n", split(s, '\n'; limit=2)[2])
    end
end

function Base.show(io::IO, @nospecialize(e::Union{Schema, Extractor}))
    print(io, nameof(typeof(e)))
    get(io, :compact, false) || _show_details(io, e)
end

_show_details(_, _) = nothing
_show_details(io::IO, e::ScalarExtractor) = print(io, "(c=", e.c, ", s=", e.s, ")")
_show_details(io::IO, e::NGramExtractor) = print(io, "(n=", e.n, ", b=", e.b, ", m=", e.m, ")")
_show_details(io::IO, e::CategoricalExtractor) = print(io, "(n=", 1 + length(e.category_map), ")")
function _show_details(io::IO, e::StableExtractor)
    print(io, "(")
    show(io, e.e)
    print(io, ")")
end

function _show_details(io, e::LeafEntry)
    print(io, " (")
    _show_types(io, e)
    print(io, ")")
end

function _show_types(io, e::LeafEntry)
    print(io, length(e.counts), " unique `", keytype(e.counts), "` values")
end

nodecommshow(io::IO, @nospecialize(e::Schema)) = print(io, e.updated, "x updated")
