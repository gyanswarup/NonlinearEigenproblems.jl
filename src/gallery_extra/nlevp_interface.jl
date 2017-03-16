export nlevp_gallery_import
export nlevp_make_native
# We have to explicitly specify functions that we want "overload"
import NEPCore.compute_Mder
import NEPCore.size

"""
    nlevp_gallery(name)
Loads a NEP from the Berlin-Manchester collection of nonlinear
eigenvalue problems
"""
function nlevp_gallery_import(name::String,nlevp_path::String="../../nlevp3")
    nep=NLEVP_NEP(name,nlevp_path)
    return nep
end

"""
         NLEVP_NEP represents a NEP in the NLEVP-toolbox
    Example usage: nep=NLEVP_NEP("gun")
    """
type NLEVP_NEP <: NEP
    n::Integer
    name::String
    Ai::Array
    function NLEVP_NEP(name,nlevp_path)
        if (~isfile(joinpath(nlevp_path,"nlevp.m")))
            error("nlevp.m not found. You need to install the Berlin-Manchester collection (http://www.maths.manchester.ac.uk/our-research/research-groups/numerical-analysis-and-scientific-computing/numerical-analysis/software/nlevp/) and specify a nlevp_path.")
        end
        @mput name nlevp_path
        @matlab begin
            addpath(nlevp_path)
            Ai,funs=nlevp(name)
            @matlab end
        @mget Ai # fetch and store the matrices

        this=new(size(Ai[1],1),name,Ai);
    end
end

function compute_Mder(nep::NLEVP_NEP,λ::Number,i::Integer=0)
    lambda=Complex{Float64}(λ)  # avoid type conversion problems
    #println("type",typeof(lambda))
    ## The following commented code is calling nlevp("eval",...)
    ## directly and does not work. We use functions instead
    #        nep_name::String=nep.name
    #        @mput lambda nep_name
    #        if (i==0)
    #            println(λ)
    #            @matlab begin
    #                ll=1+0.1i
    #                M=nlevp("eval",nep_name,lambda
    #            @matlab end
    #            @mget M
    #            return M
    #        else
    #            @matlab begin
    #                (M,Mp)=nlevp("eval",nep_name,lambda)
    #            @matlab end
    #            @mget Mp
    #            return Mp
    #        end
    #    return f,fp
    D=call_current_fun(lambda,i)
    f=D[i+1,:]
    M=zeros(nep.Ai[1]);
    for i=1:length(nep.Ai)
        M=M+nep.Ai[i]*f[i]
    end
    return M
end

# Return function values and derivatives of the current matlab session "funs"
# stemming from a previous call to [Ai,funs]=nlevp(nepname).
# The returned matrix containing derivatives has (maxder+1) rows 
function call_current_fun(lambda,maxder::Integer=0)        
    l::Complex64=Complex64(lambda)  # avoid type problems
    @mput l maxder
    eval_string("C=cell(maxder+1,1); [C{:}]=funs(l); D=cell2mat(C);")
    @mget D
    return D
end


# size for NLEVP_NEPs
function size(nep::NLEVP_NEP,dim=-1)
    if (dim==-1)
        return (nep.n,nep.n)
    else
        return nep.n
    end
end

"""
   nlevp_make_native(nep::NLEVP_NEP)

Tries to convert the NLEVP_NEP a NEP of NEP-PACK types
"""
function nlevp_make_native(nep::NLEVP_NEP)
    if (nep.name == "gun")
        minusop= S-> -S
        oneop= S -> eye(size(S,1),size(S,2))
        sqrt1op= S -> 1im*sqrtm(full(S))
        sqrt2op= S -> 1im*sqrtm(full(S)-108.8774^2*eye(S))
        nep2=SPMF_NEP(nep.Ai,[oneop,minusop,sqrt1op,sqrt2op])
        return nep2
    elseif (nep.name == "cd_player")
        return PEP(nep.Ai);
    else
        error("Unable to make NEP native")
    end

end