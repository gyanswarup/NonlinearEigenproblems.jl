# Solves a basic eigenvalue problem defined through different NEP types through NLEIGS

# Intended to be run from nep-pack/ directory or nep-pack/test directory
if !isdefined(:global_modules_loaded)
    workspace()

    push!(LOAD_PATH, string(@__DIR__, "/../../src"))
    push!(LOAD_PATH, string(@__DIR__, "/../../src/nleigs"))

    using NEPCore
    using NEPTypes
    using NleigsTypes
    using Gallery
    using IterativeSolvers
    using Base.Test
end

include("nleigs_test_utils.jl")
include("../../src/nleigs/method_nleigs.jl")

n = 2
B = Vector{Matrix{Float64}}([[1 3; 5 6], [3 4; 6 6]])
C = Vector{Matrix{Float64}}([[1 0; 0 1]])
f = [λ -> λ^2]

Sigma = [-10.0-2im, 10-2im, 10+2im, -10+2im]

struct CustomNLEIGSNEP <: NEP
    n::Int  # problem size; this is the only required field in a custom NEP type when used with NLEIGS
end

# implement a few methods used by the solver
import NEPCore.compute_Mder, NEPCore.compute_Mlincomb, Base.size
pep = PEP([B; C])
compute_Mder(::CustomNLEIGSNEP, λ::Number) = compute_Mder(pep, λ)
compute_Mlincomb(::CustomNLEIGSNEP, λ::Number, x) = compute_Mlincomb(pep, λ, x)
size(::CustomNLEIGSNEP, _) = n

# define and solve the same problem in many different ways
problems = [
    ("SPMF_NEP", SPMF_NEP([B; C], [λ -> 1; λ -> λ; λ -> λ^2])),
    ("PEP", PEP([B; C])),
    ("PEP + SPMF", SumNEP(PEP(B), SPMF_NEP(C, f))),
    ("PEP + LowRankFactorizedNEP", SumNEP(PEP(B), LowRankFactorizedNEP([LowRankMatrixAndFunction(sparse(C[1]), f[1])]))),
    ("Custom NEP type", CustomNLEIGSNEP(n))]

for problem in problems
    @testset "NLEIGS: $(problem[1])" begin
        @time X, lambda = nleigs(problem[2], Sigma, maxit=10, v=ones(n), blksize=5)
        nleigs_verify_lambdas(4, problem[2], X, lambda)
    end
end