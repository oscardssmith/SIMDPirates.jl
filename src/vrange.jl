@generated function vrange(::Val{W}, ::Type{T}) where {W,T}
    Expr(:block, Expr(:meta, :inline), Expr(:call, :SVec, Expr(:tuple, [Expr(:call, :(Core.VecElement), T(w)) for w ∈ 0:W-1]...)))
end
@generated function vrangeincr(::Val{W}, i::I, ::Val{O}) where {W,I<:Integer,O}
    bytes = I === Int ? min(8, VectorizationBase.prevpow2(VectorizationBase.REGISTER_SIZE ÷ W)) : sizeof(I)
    # bytes = min(8, VectorizationBase.prevpow2(VectorizationBase.REGISTER_SIZE ÷ W))
    bits = 8bytes
    jtypesym = Symbol(:Int, bits)
    iexpr = bytes == sizeof(I) ? :i : Expr(:call, :%, :i, jtypesym)
    typ = "i$(bits)"
    vtyp = "<$W x $typ>"
    rangevec = join(("$typ $(w+O)" for w ∈ 0:W-1), ", ")
    instrs = String[]
    push!(instrs, "%ie = insertelement $vtyp undef, $typ %0, i32 0")
    push!(instrs, "%v = shufflevector $vtyp %ie, $vtyp undef, <$W x i32> zeroinitializer")
    push!(instrs, "%res = add nsw $vtyp %v, <$rangevec>")
    push!(instrs, "ret $vtyp %res")
    quote
        $(Expr(:meta,:inline))
        llvmcall(
            $(join(instrs,"\n")), Vec{$W,$jtypesym}, Tuple{$jtypesym}, $iexpr
        )
    end
end
@generated function vrangeincr(::Val{W}, i::T, ::Val{O}) where {W,T<:FloatingTypes,O}
    typ = llvmtype(T)
    vtyp = "<$W x $typ>"
    rangevec = join(("$typ $(w+O).0" for w ∈ 0:W-1), ", ")
    instrs = String[]
    push!(instrs, "%ie = insertelement $vtyp undef, $typ %0, i32 0")
    push!(instrs, "%v = shufflevector $vtyp %ie, $vtyp undef, <$W x i32> zeroinitializer")
    push!(instrs, "%res = fadd $vtyp %v, <$rangevec>")
    push!(instrs, "ret $vtyp %res")
    quote
        $(Expr(:meta,:inline))
        llvmcall(
            $(join(instrs,"\n")), Vec{$W,$T}, Tuple{$T}, i
        )
    end
end
@generated function vrangemul(::Val{W}, i::I, ::Val{O}) where {W,I<:Integer,O}
    bytes = I === Int ? min(8, VectorizationBase.prevpow2(VectorizationBase.REGISTER_SIZE ÷ W)) : sizeof(I)
    bits = 8bytes
    jtypesym = Symbol(:Int, bits)
    iexpr = bytes == sizeof(I) ? :i : Expr(:call, :%, :i, jtypesym)
    typ = "i$(bits)"
    vtyp = "<$W x $typ>"
    rangevec = join(("$typ $(w+O)" for w ∈ 0:W-1), ", ")
    instrs = String[]
    push!(instrs, "%ie = insertelement $vtyp undef, $typ %0, i32 0")
    push!(instrs, "%v = shufflevector $vtyp %ie, $vtyp undef, <$W x i32> zeroinitializer")
    push!(instrs, "%res = mul nsw $vtyp %v, <$rangevec>")
    push!(instrs, "ret $vtyp %res")
    quote
        $(Expr(:meta,:inline))
        llvmcall(
            $(join(instrs,"\n")), Vec{$W,$jtypesym}, Tuple{$jtypesym}, $iexpr
        )
    end
end
@generated function vrangemul(::Val{W}, i::T, ::Val{O}) where {W,T<:FloatingTypes,O}
    typ = llvmtype(T)
    vtyp = "<$W x $typ>"
    rangevec = join(("$typ $(w+O).0" for w ∈ 0:W-1), ", ")
    instrs = String[]
    push!(instrs, "%ie = insertelement $vtyp undef, $typ %0, i32 0")
    push!(instrs, "%v = shufflevector $vtyp %ie, $vtyp undef, <$W x i32> zeroinitializer")
    push!(instrs, "%res = fmul fast $vtyp %v, <$rangevec>")
    push!(instrs, "ret $vtyp %res")
    quote
        $(Expr(:meta,:inline))
        llvmcall(
            $(join(instrs,"\n")), Vec{$W,$T}, Tuple{$T}, i
        )
    end
end

@inline svrangeincr(::Val{W}, i, ::Val{O}) where {W,O} = SVec(vrangeincr(Val{W}(), i, Val{O}()))
@inline svrangemul(::Val{W}, i, ::Val{O}) where {W,O} = SVec(vrangemul(Val{W}(), i, Val{O}()))


@inline vrange(i::_MM{W}) where {W} = vrangeincr(Val{W}(), i.i, Val{0}())
@inline svrange(i::_MM{W}) where {W} = SVec(vrangeincr(Val{W}(), i.i, Val{0}()))
@inline Base.:(+)(i::_MM{W}, j::_MM{W}) where {W} = SVec(vadd(vrange(i), vrange(j)))
@inline Base.:(+)(i::_MM{W}, j::Vec{W}) where {W} = vadd(vrange(i), j)
@inline Base.:(+)(i::Vec{W}, j::_MM{W}) where {W} = vadd(i, vrange(j))
@inline Base.:(*)(i::_MM{W}, j::Vec{W}) where {W} = vmul(vrange(i), j)
@inline Base.:(*)(i::Vec{W}, j::_MM{W}) where {W} = vmul(i, vrange(j))
@inline Base.:(+)(i::_MM{W}, j::AbstractStructVec{W}) where {W} = SVec(vadd(vrange(i), extract_data(j)))
@inline Base.:(+)(i::AbstractStructVec{W}, j::_MM{W}) where {W} = SVec(vadd(extract_data(i), vrange(j)))
@inline Base.:(*)(i::_MM{W}, j::AbstractStructVec{W}) where {W} = SVec(vmul(vrange(i), extract_data(j)))
@inline Base.:(*)(i::AbstractStructVec{W}, j::_MM{W}) where {W} = SVec(vmul(extract_data(i), vrange(j)))
@inline vadd(i::_MM{W}, j::_MM{W}) where {W} = SVec(vadd(vrange(i), vrange(j)))
@inline vadd(i::_MM{W}, j::Vec{W}) where {W} = vadd(vrange(i), j)
@inline vadd(i::Vec{W}, j::_MM{W}) where {W} = vadd(i, vrange(j))
@inline vadd(i::_MM{W}, j::AbstractStructVec{W}) where {W} = SVec(vadd(vrange(i), extract_data(j)))
@inline vadd(i::AbstractStructVec{W}, j::_MM{W}) where {W} = SVec(vadd(extract_data(i), vrange(j)))
@inline vmul(i::_MM{W}, j::Vec{W}) where {W} = vmul(vrange(i), j)
@inline vmul(i::_MM{W}, j::AbstractStructVec{W}) where {W} = SVec(vmul(vrange(i), extract_data(j)))
@inline vmul(j::Vec{W}, i::_MM{W}) where {W} = vmul(j, vrange(i))
@inline vmul(j::AbstractStructVec{W}, i::_MM{W}) where {W} = SVec(vmul(extract_data(j), vrange(i)))
@inline Base.:(/)(i::_MM, j::T) where {T<:Number} = SVec(vfdiv(vrange(i,T), j))
@inline Base.:(/)(j::T, i::_MM) where {T<:Number} = SVec(vfdiv(j, vrange(i,T)))
@inline Base.:(/)(i::_MM, j::SVec{W,T}) where {W,T<:Number} = SVec(vfdiv(vrange(i,T), j))
@inline Base.:(/)(j::SVec{W,T}, i::_MM) where {W,T<:Number} = SVec(vfdiv(j, vrange(i,T)))
@inline Base.:(/)(i::_MM, j::_MM) = SVec(vfdiv(vrange(i), vrange(j)))
@inline Base.inv(i::_MM) = inv(svrange(i))


@inline vrange(::Val{W}) where {W} = vrange(Val{W}(), Float64)
@inline svrange(::Val{W}) where {W} = svrange(Val{W}(), Float64)

@inline vrange(i::_MM{W}, ::Type{T}) where {W,T} = vrangeincr(Val{W}(), T(i.i), Val{0}())
@inline vrange(i::_MM{W}, ::Type{T}) where {W,T <: Integer} = vrangeincr(Val{W}(), i.i % T, Val{0}())
@inline svrange(i::_MM, ::Type{T}) where {T} = SVec(vrange(i, T))


@inline Base.:(<<)(i::_MM, j::Integer) = svrange(i) << j
@inline Base.:(>>)(i::_MM, j::Integer) = svrange(i) >> j
@inline Base.:(>>>)(i::_MM, j::Integer) = svrange(i) >>> j

@inline Base.:(*)(i::_MM{W}, j::T) where {W,T} = vmul(svrange(i), j)
@inline Base.:(*)(j::T, i::_MM{W}) where {W,T} = vmul(svrange(i), j)
@inline vmul(i::_MM{W}, j::T) where {W,T} = vmul(svrange(i), j)
@inline vmul(j::T, i::_MM{W}) where {W,T} = vmul(svrange(i), j)
@inline vmul(i::_MM{W}, ::Static{j}) where {W,j} = vmul(svrange(i), j)
@inline vmul(::Static{j}, i::_MM{W}) where {W,j} = vmul(svrange(i), j)
@inline vconvert(::Type{SVec{W,T}}, i::_MM{W}) where {W,T} = svrange(i, T)




@inline Base.:(-)(i::Integer, j::_MM{W}) where {W} = vsub(i, svrange(j))
@inline Base.:(-)(::Static{i}, j::_MM{W}) where {W,i} = vsub(i, svrange(j))
@inline Base.:(-)(i::_MM{W}, j::_MM{W}) where {W} = vsub(svrange(i), svrange(j))
@inline Base.:(-)(i::_MM{W}) where {W} = -svrange(i)
@inline vsub(i::Integer, j::_MM{W}) where {W} = vsub(i, svrange(j))
@inline vsub(::Static{i}, j::_MM{W}) where {W,i} = vsub(i, svrange(j))
@inline vsub(i::_MM{W}, j::_MM{W}) where {W} = vsub(svrange(i), svrange(j))
@inline vsub(i::_MM{W}) where {W} = -svrange(i)


for op ∈ [:(<), :(>), :(≥), :(≤), :(==), :(!=), :(&), :(|), :(⊻), :(%)]
    @eval @inline Base.$op(i::_MM, j::Integer) = $op(svrange(i), j)
    @eval @inline Base.$op(i::Integer, j::_MM) = $op(i, svrange(j))
    @eval @inline Base.$op(i::_MM, ::Static{j}) where {j} = $op(svrange(i), j)
    @eval @inline Base.$op(::Static{i}, j::_MM) where {i} = $op(i, svrange(j))
    @eval @inline Base.$op(i::_MM, j::_MM) = $op(svrange(i), svrange(j))
end
@inline Base.:(*)(i::_MM, j::_MM) = SVec(vmul(vrange(i), vrange(j)))
@inline vmul(i::_MM, j::_MM) = SVec(vmul(vrange(i), vrange(j)))


using VectorizationBase: Static, Zero, One
@inline vadd(::_MM{W,Zero}, v::AbstractSIMDVector{W,T}) where {W,T} = vadd(vrange(Val{W}(), T), v)
@inline vadd(v::AbstractSIMDVector{W,T}, ::_MM{W,Zero}) where {W,T} = vadd(vrange(Val{W}(), T), v)
@inline vadd(::_MM{W,Zero}, ::_MM{W,Zero}) where {W} = vrangemul(Val{W}(), 2, Val{0}())
# @inline vmul(::_MM{W,Zero}, i) where {W} = svrangemul(Val{W}(), i, Val{0}())
# @inline vmul(i, ::_MM{W,Zero}) where {W} = svrangemul(Val{W}(), i, Val{0}())

@inline vmul(::_MM{W,Static{N}}, i) where {W,N} = svrangemul(Val{W}(), i, Val{N}())
@inline vmul(i, ::_MM{W,Static{N}}) where {W,N} = svrangemul(Val{W}(), i, Val{N}())


