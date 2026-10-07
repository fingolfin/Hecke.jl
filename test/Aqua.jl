using Aqua

@testset "Aqua.jl" begin
  Aqua.test_all(
    Hecke;
    # TODO: `rand(rng, R, v...)` clashes with RandomExtensions; the other two
    # are ambiguous for a FractionFieldMap{T, T}
    ambiguities=(exclude=[rand, Hecke.decompose, Hecke._has_preimage],),
    piracies=false          # TODO: fix piracy
  )
end
