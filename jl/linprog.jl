# Interior point method (default)

function linprog_interior{T<:Real, P<:Union(GLPInteriorParam, Nothing)}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T},
        lb::VecOrNothing{T}, ub::VecOrNothing{T},
        params::P)

    lp, n = _jl_linprog__setup_prob(f, A, b, Aeq, beq, lb, ub, params)

    ret = glp_interior(lp, params)
    #println("ret=$ret")

    if ret == 0
        z = glp_ipt_obj_val(lp)
        x = zeros(Float64, n)
        for c = 1 : n
            x[c] = glp_ipt_col_prim(lp, c)
        end
        return (z, x, ret)
    else
        # throw exception here ?
        return (nothing, nothing, ret)
    end
end

linprog_interior{T<:Real}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T}) = 
        linprog_interior(f, A, b, nothing, nothing, nothing, nothing, nothing)

linprog_interior{T<:Real}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T}) = 
        linprog_interior(f, A, b, Aeq, beq, nothing, nothing, nothing)

linprog_interior{T<:Real}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T}, lb::VecOrNothing{T},
        ub::VecOrNothing{T}) = 
        linprog_interior(f, A, b, Aeq, beq, lb, ub, nothing)

linprog = linprog_interior


# Simplex Method

function linprog_simplex{T<:Real, P<:Union(GLPSimplexParam, Nothing)}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T},
        lb::VecOrNothing{T}, ub::VecOrNothing{T},
        params::P)
    
    lp, n = _jl_linprog__setup_prob(f, A, b, Aeq, beq, lb, ub, params)

    ret = glp_simplex(lp, params)
    #println("ret=$ret")

    if ret == 0
        z = glp_get_obj_val(lp)
        x = zeros(Float64, n)
        for c = 1 : n
            x[c] = glp_get_col_prim(lp, c)
        end
        return (z, x, ret)
    else
        # throw exception here ?
        return (nothing, nothing, ret)
    end
end

linprog_simplex{T<:Real}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T}) = 
        linprog_simplex(f, A, b, nothing, nothing, nothing, nothing, nothing)

linprog_simplex{T<:Real}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T}) = 
        linprog_simplex(f, A, b, Aeq, beq, nothing, nothing, nothing)

linprog_simplex{T<:Real}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T}, lb::VecOrNothing{T},
        ub::VecOrNothing{T}) = 
        linprog_simplex(f, A, b, Aeq, beq, lb, ub, nothing)



function _jl_linprog__setup_prob{T<:Real, P<:Union(GLPParam, Nothing)}(f::AbstractVector{T}, A::MatOrNothing{T}, b::VecOrNothing{T},
        Aeq::MatOrNothing{T}, beq::VecOrNothing{T},
        lb::VecOrNothing{T}, ub::VecOrNothing{T},
        params::P)

    lp = GLPProb()
    glp_set_obj_dir(lp, GLP_MIN)

    n = size(f, 1)

    m = _jl_linprog__check_A_b(A, b, n)
    meq = _jl_linprog__check_A_b(Aeq, beq, n)

    has_lb, has_ub = _jl_linprog__check_lb_ub(lb, ub, n)

    #println("n=$n m=$m meq=$meq has_lb=$has_lb ub=$has_ub")

    if m > 0
        glp_add_rows(lp, m)
        for r = 1 : m
            #println("  r=$r b=$(b[r])")
            glp_set_row_bnds(lp, r, GLP_UP, 0.0, b[r])
        end
    end
    if meq > 0
        glp_add_rows(lp, meq)
        for r = 1 : meq
            r0 = r + m
            #println("  r=$r r0=$r0 beq=$(beq[r])")
            glp_set_row_bnds(lp, r0, GLP_FX, beq[r], beq[r])
        end
    end

    glp_add_cols(lp, n)

    for c = 1 : n
        glp_set_obj_coef(lp, c, f[c])
        #println("  c=$c f=$(f[c])")
    end

    if has_lb && has_ub
        for c = 1 : n
            #println("  c=$c lb=$(lb[c]) ub=$(ub[c])")
            bounds_type = (lb[c] != ub[c] ? GLP_DB : GLP_FX)
            glp_set_col_bnds(lp, c, bounds_type, lb[c], ub[c])
        end
    elseif has_lb
        for c = 1 : n
            #println("  c=$c lb=$(lb[c])")
            glp_set_col_bnds(lp, c, GLP_LO, lb[c], 0.0)
        end
    elseif has_ub
        for c = 1 : n
            #println("  c=$c ub=$(ub[c])")
            glp_set_col_bnds(lp, c, GLP_UP, 0.0, ub[c])
        end
    end

    if (m > 0 && issparse(A)) && (meq > 0 && issparse(Aeq))
        (ia, ja, ar) = find([A; Aeq])
    elseif (m > 0 && issparse(A)) && (meq == 0)
        (ia, ja, ar) = find(A)
    elseif (m == 0) && (meq > 0 && issparse(Aeq))
        (ia, ja, ar) = find(Aeq)
    else
        (ia, ja, ar) = _jl_linprog__dense_matrices_to_glp_format(m, meq, n, A, Aeq)
    end
    #println("ia=$ia")
    #println("ja=$ja")
    #println("ar=$ar")

    glp_load_matrix(lp, ia, ja, ar)
    return (lp, n)
end




function _jl_linprog__check_A_b{T}(A::MatOrNothing{T}, b::VecOrNothing{T}, n::Int)
    m = 0
    if !_jl_glpk__is_empty(A)
        if size(A, 2) != n
            error("invlid A size: $(size(A))")
        end
        m = size(A, 1)
        if _jl_glpk__is_empty(b)
            error("b is empty but a is not")
        end
        if size(b, 1) != m
            #printf(f"m=%i\n", m)
            error("invalid b size: $(size(b))")
        end
    else
        if !_jl_glpk__is_empty(b)
            error("A is empty but b is not")
        end
    end
    return m
end

function _jl_linprog__check_lb_ub{T}(lb::VecOrNothing{T}, ub::VecOrNothing{T}, n::Int)
    has_lb = false
    has_ub = false
    if ! _jl_glpk__is_empty(lb)
        if size(lb, 1) != n
            error("invlid lb size: $(size(lb))")
        end
        has_lb = true
    end
    if ! _jl_glpk__is_empty(ub)
        if size(ub, 1) != n
            error("invalid ub size: $(size(ub))")
        end
        has_ub = true
    end
    return (has_lb, has_ub)
end

function _jl_linprog__dense_matrices_to_glp_format(m, meq, n, A, Aeq)
    l = (m + meq) * n

    ia = zeros(Int32, l)
    ja = zeros(Int32, l)
    ar = zeros(Float64, l)

    k = 0
    for r = 1 : m
        for c = 1 : n
            k += 1
            ia[k] = r
            ja[k] = c
            ar[k] = A[r, c]
        end
    end
    for r = 1 : meq
        for c = 1 : n
            r0 = r + m
            k += 1
            ia[k] = r0
            ja[k] = c
            ar[k] = Aeq[r, c]
        end
    end
    return (ia, ja, ar)
end
