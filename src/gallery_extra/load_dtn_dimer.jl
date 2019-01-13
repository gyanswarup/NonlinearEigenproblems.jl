# Script which loads the DtN nep.
import Base.size
using SpecialFunctions,Printf, SparseArrays;
import NonlinearEigenproblems.compute_Mder;
import NonlinearEigenproblems.compute_Mlincomb;


# A DtN-nep
struct DtN_NEP <: NEP
    A::SparseMatrixCSC{ComplexF64}
    M::SparseMatrixCSC{ComplexF64}
    Q::Matrix{ComplexF64};
    P::Vector{SparseMatrixCSC{ComplexF64}} # Full matrix coefficents
    ind2::Vector;
    n::Int;
end

size(nep::DtN_NEP) = (nep.n,nep.n)
size(nep::DtN_NEP,dim::Int) = nep.n

function besselh_quotient(nu,S)
# Compute: besselh'(nu,s)/besselh(nu,s)
    Fder=0.5*(besselh(nu-1,S)-besselh(nu+1,S));
    return besselh(nu,S)\Fder;
end


function besselh_quotient_der(nu,S)
    # Compute: derivative of besselh'(nu,s)/besselh(nu,s)
    Fderder=0.25*(besselh(nu-2,S)-2*besselh(nu,S)+besselh(nu+2,S));
    Fder=0.5*(besselh(nu-1,S)-besselh(nu+1,S))
    F=besselh(nu,S);
    return (F^2)\(Fderder*F-Fder*Fder);
end



function compute_Mder(nep::DtN_NEP, λ::Number, der::Int=0)
    if (der>0)
        error("Not implemented");
    end
    A=copy(nep.A);
    A -= nep.M*λ^2;
    a=1.0;
    for i=1:length(nep.ind2)
        # add:  - s B'_m(s)/B_m(s)
        m=nep.ind2[i];
        f= S ->  -S*besselh_quotient(m,a*S);
        A += f(λ)*nep.P[i]
    end
    return A;
end

function compute_Mlincomb(nep::DtN_NEP, λ::Number, V::AbstractVecOrMat)

    if (size(V,2)>2)
        error("Higher derivatives not implemented")
    end
    TT=promote_type(eltype(V),typeof(λ),eltype(nep.A));
    n=size(nep,1);
    v=nep.A*V[:,1]

    v .-= nep.M*(λ^2*V[:,1]);


    a=1.0;
    for i=1:length(nep.ind2)
        # add:  - s B'_m(s)/B_m(s)
        m=nep.ind2[i];
        f= S ->  -S*besselh_quotient(m,a*S);
        v .+= f(λ)*nep.Q[:,i]*(nep.Q[:,i]'*V[:,1])
    end
    if (size(V,2)>1)
       # First derivative:
       v .-= 2*nep.M*(λ*V[:,2]); # The quadratic term
       for i=1:length(nep.ind2)
          # add derivative of: - s B'_m(s)/B_m(s)
          m=nep.ind2[i];
          f= S ->  -besselh_quotient(m,a*S)-a*S*besselh_quotient_der(m,a*S)
          v .+= f(λ)*nep.Q[:,i]*(nep.Q[:,i]'*V[:,2])
       end
    end
    return v;
end

## Load the matrices

include("petsc_naive_bin_read.jl")

# l=40; # Number of terms

"""
    function load_dtn_dimer(data_dir::String,l::Int)

 Loads the DtN example in the NEP described in J. Araujo-Cabarcas, C. Engström and E. Jarlebring, Efficient resonance computations for Helmholtz problems based on a Dirichlet-to-Neumann map, J. Comput. Appl. Math., 330:177-192, 2018  (http://arxiv.org/pdf/1606.09547)
"""
function load_dtn_dimer(data_dir::String,l::Int)

    A = naive_petsc_read(joinpath(data_dir,"K.bin"))
    M = naive_petsc_read(joinpath(data_dir,"M.bin"))
    n = size(A,1);

    # config_fem.m contains dofs and dofs_boundaries.
    # This should be the same as dof-dofs_boundaries
    q1 = naive_petsc_read(joinpath(data_dir,"q1.bin"))
    start_dtn_dofs=findfirst(abs.(q1).>0)-1;

    dtn_a = 1;

    # Determine the number of saved terms.
    searchdir(path,key) = filter(x->startswith(x,key), readdir(path))
    files=searchdir(data_dir,"q") # All the Q-vectors
    # Mid of the number of saved terms.
    mid=round(Int,(size(files,1)-1)/2+1);

    l=min((mid-1),l); # make sure we don't exceed the dimension

    ind=Vector((mid-l):(mid+l));
    ind2=ind .- mid;

    Q=Matrix{ComplexF64}(undef,n,size(ind,1)); # Factorized matrices
    P=Vector{SparseMatrixCSC}(undef,size(ind,1)) # A vector of rank one matrices
    for i=1:size(ind,1)
        # This corresponds to the term q*q'*bessel_quotient(ind2[i],s)
        # Load the q-vector.
        fname=@sprintf("q%d.bin",ind[i]);
        q = naive_petsc_read(joinpath(data_dir,fname))/(sqrt(2*pi)*sqrt(dtn_a))
        Q[:,i]= q;
        # Multiply it out (a bit complicated since since we want to save memory)
        # NNZ part of the q-vector
        qnz = q[(start_dtn_dofs+1):end]
        Qnz=sparse(qnz*qnz')
        (I,J,V)=findnz(Qnz)
        P[i]=sparse(I.+start_dtn_dofs,J.+start_dtn_dofs,V);
    end

    print("Loading DtN. Only first derivative implemented. compute_Mder is slow due to inconsistent sparsity pattern.")
    nep=DtN_NEP(A,M,Q,P,ind2,n);

    return nep


end
