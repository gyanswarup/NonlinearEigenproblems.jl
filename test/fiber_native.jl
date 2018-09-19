push!(LOAD_PATH, @__DIR__); using TestUtils
using NonlinearEigenproblems
using Test
using LinearAlgebra


@bench @testset "fiber native" begin
    nep = nep_gallery("nlevp_native_fiber")
    n = size(nep, 1)

    # An exact eigenvalue according (reported in NLEVP collection)
    sol_val= 7.139494306065948e-07;

    (λ,v)=quasinewton(nep,λ=7.14e-7,v=ones(n),
                      displaylevel=1, armijo_factor=0.5,armijo_max=10)

    @test abs(λ-sol_val)<1e-10;

    # check that we "maintain" real arithmetic
    vv=real(v/v[1]);
    (λ1,v)=resinv(Float64,nep,λ=7.14e-7,v=vv,
                      displaylevel=1)
    @test abs(λ-sol_val)<1e-10;

    @test eltype(v)==Float64

end