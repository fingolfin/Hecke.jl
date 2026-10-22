# Precompile workload: caches native code for common entry points in the
# package image.
#
# The workload fills global caches with objects that hold pointers into FLINT
# memory, which must not be serialized into the image. So the entries added to
# module-level arrays and dictionaries are removed afterwards; emptying them
# instead would also wipe data tables.

function _workload_snapshot()
  snap = Tuple{Any, Any}[]
  seen = Base.IdSet{Any}()
  for M in (AbstractAlgebra, AbstractAlgebra.Generic, Nemo, Hecke)
    for (_, z) in find_cache(M)
      (z in seen || z === val) && continue
      push!(seen, z)
      if z isa AbstractDict
        push!(snap, (z, Set{Any}(keys(z))))
      elseif z isa Vector
        push!(snap, (z, length(z)))
      end
    end
  end
  return snap
end

# Drop the entries the workload added.
function _workload_restore(snap)
  for (z, old) in snap
    if z isa AbstractDict
      for k in collect(keys(z))
        k in old || delete!(z, k)
      end
    elseif length(z) > old
      resize!(z, old)
    end
  end
  # scratch space of add_scaled_row may hold GMP pointers
  for i in 1:length(val)
    val[i] = 0
  end
end

PrecompileTools.@setup_workload begin
  # registers verbosity and assertion scopes, which the workload needs
  __init__()
  _snap = _workload_snapshot()
  PrecompileTools.@compile_workload begin
    Qx, x = polynomial_ring(QQ, :x; cached = false)
    K, a = number_field(x^3 - 2, :a; cached = false)
    OK = maximal_order(K)
    class_group(OK)
    unit_group(OK)
    prime_decomposition(OK, 5)
    Kt, t = polynomial_ring(K, :t; cached = false)
    factor(t^3 - a)
    L, b = number_field(t^2 - a, :b; cached = false)
    maximal_order(L)
    is_integral(b)
    Lns, _ = number_field([t^2 - a, t^2 - 3]; cached = false)
    maximal_order(Lns)

    G = integer_genera((0, 4), 9)
    representatives(G[1])

    F, c = number_field(x^2 - 2, :c; cached = false)
    OF = maximal_order(F)
    pl = real_places(F)
    for g in quadratic_genera(F; rank = 2, det = 2 * OF, signatures = Dict(pl[1] => 0, pl[2] => 0))
      representative(g)
    end
  end
  _workload_restore(_snap)
end
