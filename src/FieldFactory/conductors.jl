###############################################################################
#
#  Conductors
#
###############################################################################

function _conductors_using_cocycles(F::FieldsTower, st::Vector{Int}, l_cond::Vector, E)
  lp = ramified_primes(F)
  auts = automorphisms(F.field, copy = false)
  cocycles = F.admissible_cocycles
  G = GAP.Globals.ImagesSource(cocycles[1].projection)
  E = GAP.Globals.Source(cocycles[1].projection)
  D = F.isomorphism
  n = prod(st)
  O = maximal_order(F)
  for p in lp
    lP = prime_decomposition(O, p)
    Hp = inertia_subgroup(lP[1][1])
    gHp = small_generating_set(Hp)
    els = [D[g] for g in gHp]
    sub = GAP.Globals.Subgroup(G, GAP.julia_to_gap(els))
    ord = GAP.Globals.Size(sub)
    sizes_preimages = Int[]
    for c in cocycles
      proj = c.projection
      subgs = Vector{Vector{Main.ForeignGAP.MPtr}}(undef, n)
      for i = 1:n
        subgs[i] = Vector{Main.ForeignGAP.MPtr}(undef, length(els))
      end
      for j = 1:length(els)
        pels = GAP.Globals.List(GAP.Globals.PreImages(proj, els[j]))
        for i = 1:length(pels)
          subgs[i][j] = pels[i]
        end
      end
      for lelem in subgs
        sub = GAP.Globals.Subgroup(E, GAP.julia_to_gap(lelem))
        onew = GAP.Globals.Size(sub)
        push!(sizes_preimages, onew)
      end
    end
    if minimum(sizes_preimages) != ord
      #The prime must ramify!
      l1 = Vector{Tuple{Int, Dict{NfOrdIdl, Int}}}()
      if !divisible(fmpz(n), p)
        for x in l_cond
          if divisible(fmpz(x[1]), p) 
            push!(l1, x)
          end
        end
      else
        for x in l_cond
          if !isempty(x[2])
            lI = keys(x[2])
            found = false
            for k in lI
              if minimum(k) == p
                found = true
                break
              end
            end
            if found
              push!(l1, x)
            end
          end
        end
      end
      l_cond = l1
    elseif maximum(sizes_preimages) == ord && !divisible(fmpz(n), p)
      #The prime must be unramified!
      l1 = Vector{Tuple{Int, Dict{NfOrdIdl, Int}}}()
      if !divisible(fmpz(n), p)
        for x in l_cond
          if !divisible(fmpz(x[1]), p) 
            push!(l1, x)
          end
        end
      else
        for x in l_cond
          if !isempty(x[2])
            lI = keys(x[2])
            found = false
            for k in lI
              if minimum(k) == p
                found = true
                break
              end
            end
            if !found
              push!(l1, x)
            end
          end
        end
      end
      l_cond = l1
    end
  end
  return l_cond

end

function conductors_with_restrictions(F::FieldsTower, st::Vector{Int}, IdG::Main.ForeignGAP.MPtr, bound::fmpz)

  O = maximal_order(F)
  l_cond = Hecke.conductors(O, st, bound)
  G = GAP.Globals.SmallGroup(IdG)
  new_conds = _conductors_using_cocycles(F, st, l_cond, G)
  if length(st) != 1 || !isprime(st[1]) || isempty(new_conds)
    return new_conds
  end
  #If the extension is cyclic, I take care of the discriminant being a square or not for the wild ramification
  issquare = is_discriminant_square(IdG)
  p = st[1]
  v = valuation(discriminant(O), p)
  is_square_disc_base_field = iszero(mod(v*p, 2))
  td = prime_decomposition_type(O, p)
  if iszero(mod(length(td) * td[1][1]*(p-1), 2))
    #Regardless of the exponents, the norm of the discriminant will be a square
    if issquare && is_square_disc_base_field
      return new_conds
    elseif issquare 
      return typeof(new_conds)()
    else
      return new_conds
    end
  end 
  #Now, p must be 2.
  if issquare && is_square_disc_base_field
    #Only the even exponents are allowed!
    newer_conds = typeof(new_conds)()
    for i = 1:length(new_conds)
      if isempty(new_conds[i][2])
        push!(newer_conds, new_conds[i])
        continue
      end 
      if iszero(mod(first(values(new_conds[i][2])), 2))
        push!(newer_conds, new_conds[i])
      end
    end
  elseif issquare
    #Only the odd exponents are allowed!
    newer_conds = typeof(new_conds)()
    for i = 1:length(new_conds)
      if !isempty(new_conds[i][2]) && !iszero(mod(first(values(new_conds[i][2])), 2))
        push!(newer_conds, new_conds[i])
      end
    end
  else
    newer_conds = new_conds
  end

  #Now, tame ramification.
  list_tame = Int[x[1] for x in newer_conds]
  list_tame = coprime_base(list_tame)
  l = length(list_tame)
  for i = 1:length(list_tame)
    x = list_tame[i]
    if !isone(x) && !isprime(x)
      append!(list_tame, Hecke.divisors(x))
    end
  end
  list_tame = coprime_base(list_tame)
  for q in list_tame
    q == 1 && continue
    #@assert isprime(q)
    v = valuation(discriminant(O), q)
    is_square_disc_base_field = iszero(mod(v*p, 2))
    td = prime_decomposition_type(O, q)
    if iszero(mod(length(td) * td[1][1] * (p-1), 2))
      #Regardless of the exponents, the norm of the discriminant will be a square
      if issquare && is_square_disc_base_field
        continue
      elseif issquare || is_square_disc_base_field
        return typeof(new_conds)()
      else
        continue
      end
    end 
    #Now, p must be 2.
    if issquare && is_square_disc_base_field
      #Only the even exponents are allowed!
      #Therefore the prime can't ramify
      newest_conds = typeof(new_conds)()
      for i = 1:length(newer_conds)
        if !iszero(mod(newer_conds[i][1], q))
          push!(newer_conds, newer_conds[i])
        end
      end
    elseif issquare
      #Only the odd exponents are allowed!
      #Therefore the prime must ramify
      newest_conds = typeof(new_conds)()
      for i = 1:length(newer_conds)
        if iszero(mod(newer_conds[i][1], q))
          push!(newest_conds, newer_conds[i])
        end
      end
    else
      newest_conds = newer_conds
    end
    newer_conds = newest_conds
  end
  return newer_conds
end
