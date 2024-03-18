@doc raw"""
    partial_transpose(ρ::QuantumObject, mask::Vector{Bool})

Return the partial transpose of a density matrix ``\rho``, where `mask` is an array/vector with length that equals the length of `ρ.dims`. The elements in `mask` are boolean (`true` or `false`) which indicates whether or not the corresponding subsystem should be transposed.

# Arguments
- `ρ::QuantumObject`: The density matrix (the type must be `OperatorQuantumObject`).
- `mask::Vector{Bool}`: A boolean vector selects which subsystems should be transposed.

# Returns
- `ρ_pt::QuantumObject`: The density matrix with the selected subsystems transposed.
"""
function partial_transpose(ρ::QuantumObject{T, OperatorQuantumObject}, mask::Vector{Bool}) where T
    if length(mask) != length(ρ.dims) 
        error("The length of \`mask\` should be equal to the length of \`ρ.dims\`.")
    end
    return _partial_transpose(ρ, mask)
end

# for dense matrices
function _partial_transpose(ρ::QuantumObject{<:AbstractMatrix, OperatorQuantumObject}, mask::Vector{Bool})
    mask2 = [1 + Int(i) for i in mask]
    # mask2 has elements with values equal to 1 or 2
    # 1 - the subsystem don't need to be transposed
    # 2 - the subsystem need be transposed

    nsys = length(mask2)
    pt_dims = reshape(Vector(1:(2 * nsys)), (nsys, 2))
    pt_idx  = [
        [pt_dims[n,     mask2[n]] for n in 1:nsys]; # origin   value in mask2
        [pt_dims[n, 3 - mask2[n]] for n in 1:nsys]  # opposite value in mask2 (1 -> 2, and 2 -> 1)
    ]
    return QuantumObject(
        reshape(permutedims(reshape(ρ.data, (ρ.dims..., ρ.dims...)), pt_idx), size(ρ)),
        OperatorQuantumObject,
        ρ.dims
    )
end

# for sparse matrices
function _partial_transpose(ρ::QuantumObject{<:AbstractSparseArray, OperatorQuantumObject}, mask::Vector{Bool})
    M, N = size(ρ)
    dimsTuple = Tuple(ρ.dims)
    colptr = ρ.data.colptr
    rowval = ρ.data.rowval
    nzval  = ρ.data.nzval
    len = length(nzval)

    # for partial transposed data
    I_pt = Vector{Int}(undef, len)
    J_pt = Vector{Int}(undef, len)
    V_pt = Vector{eltype(ρ)}(undef, len)

    n = 0
    for j in 1:(length(colptr) - 1)
        for p in colptr[j]:(colptr[j + 1] - 1)
            n += 1
            i = rowval[p]
            if i == j
                I_pt[n] = i
                J_pt[n] = j
            else
                ket_pt = [Base._ind2sub(dimsTuple, i)...]
                bra_pt = [Base._ind2sub(dimsTuple, j)...]
                for sys in findall(m -> m, mask)
                    @inbounds ket_pt[sys], bra_pt[sys] = bra_pt[sys], ket_pt[sys]
                end
                I_pt[n] = Base._sub2ind(dimsTuple, ket_pt...)
                J_pt[n] = Base._sub2ind(dimsTuple, bra_pt...)
            end
            V_pt[n] = nzval[p]
        end
    end

    return QuantumObject(
        sparse(I_pt, J_pt, V_pt, M, N),
        OperatorQuantumObject,
        ρ.dims
    )
end