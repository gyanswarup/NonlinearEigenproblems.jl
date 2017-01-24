module NEPTypes
    # Specializalized NEPs 
    export DEP
    export PEP

    export interpolate
    
    using NEPCore

    # We overload these
    import NEPCore.compute_Mder
    import NEPCore.compute_Mlincomb
    import NEPCore.compute_MM
    import Base.size


    export compute_Mder
    export compute_Mlincomb
    export compute_MM
    export size
    
    ############################################
    # Delay eigenvalue problem - DEP
    #

    """
    Delay eigenvalue problem
  A DEP is defined by the sum the sum  -λI + Σ_i A_i exp(-tau_i λ)\\
  where all of the matrices are of size n times n\\
  Constructor: DEP(AA,tauv) where AA is an array of the\\
  matrices A_i, and tauv is a vector of the values tau_i
"""
    type DEP <: NEP
        n::Integer
        A     # An array of matrices (full or sparse matrices)
        tauv::Array{Float64,1} # the delays
        function DEP(AA,tauv=[0,1.0])
            n=size(AA[1],1)
            this=new(n,AA,tauv);
            return this;
        end
    end

    """
    compute_Mder(nep::DEP,λ::Number,i::Integer=0)
 Compute the ith derivative of a DEP
"""
    function compute_Mder(nep::DEP,λ::Number,i::Integer=0)
        local M,I;
        if issparse(nep.A[1])
            M=spzeros(nep.n,nep.n)
            I=speye(nep.n,nep.n)
        else
            M=zeros(nep.n,nep.n)
            I=eye(nep.n,nep.n)        
        end
        if i==0; M=-λ*I;  end
        if i==1; M=-I; end
        for j=1:size(nep.A,1)
            M+=nep.A[j]*(exp(-nep.tauv[j]*λ)*(-nep.tauv[j])^i)
        end
        return M
    end



    """
    compute_MM(nep::DEP,S,V)
 Computes the sum Σ_i M_i V f_i(S) for a DEP
"""
    function compute_MM(nep::DEP,S,V)
        Z=-V*S;
        for j=1:size(nep.A,1)
            Z+=nep.A[j]*V*expm(-nep.tauv[j]*S)
        end
        return Z
    end

"""
    size(nep::DEP,dim=-1)
 Overloads the size functions for a DEP.
"""
    function size(nep::DEP,dim=-1)
        if (dim==-1)
            return (nep.n,nep.n)
        else
            return nep.n
        end
    end


    ############################################
    # Polynomial eigenvalue problem - PEP
    #

    """
    Polynomial eigenvalue problem
  A PEP is defined by the sum the sum  Σ_i A_i λ^i,\\
  where i = 0,1,2,..., and  all of the matrices are of size n times n\\
  Constructor: PEP(AA) where AA is an array of the matrices A_i
"""

    type PEP <: NEP
        n::Integer
        A::Array   # Monomial coefficients of PEP 
        function PEP(AA)
            n=size(AA[1],1)
            return new(n,AA)
        end
    end

    """
    compute_MM(nep::DEP,S,V)
 Computes the sum Σ_i M_i V f_i(S) for a DEP
"""
    function compute_MM(nep::PEP,S,V)
        Z=zeros(size(V))
        Si=eye(size(S,1))
        for i=1:size(nep.A,1)
            Z+=nep.A[i]*V*Si;
            Si=Si*S;
        end
        return Z
    end

    """
    compute_Mder(nep::PEP,λ::Number,i::Integer=0)
 Compute the ith derivative of a PEP
"""
    function compute_Mder(nep::PEP,λ::Number,i::Integer=0)
        Z=zeros(size(nep,1),size(nep,1));
        for j=(i+1):size(nep.A,1)
            # Derivatives of monimials
            Z+= nep.A[j]*(λ^(j-i-1)*factorial(j-1)/factorial(j-i-1))
        end
        return Z
    end


"""
    size(nep::PEP,dim=-1)
 Overloads the size functions for a DEP.
"""
    function size(nep::PEP,dim=-1)
        if (dim==-1)
            return (nep.n,nep.n)
        else
            return nep.n
        end
    end

"""
    interpolate(nep::NEP, intpoints)
 Interpolates a NEP in the points intpoints and returns a PEP
"""
    function interpolate{T<:Number}(nep::NEP, intpoints::Array{T,1})
        n = size(nep, 1)
        d = length(intpoints)
        if (T != Complex64)
            intpoints=Array{Complex64}(intpoints)
        end

        b = Array{T}(n*d,n)
        for i = 1:d
            b[(1:n)+(i-1)*n,:] = compute_Mder(nep,intpoints[i])
        end
        V = Array{T}(d,d)
        pwr = ones(d,1)
        for i = 1:d
            V[:,i] = pwr
            pwr = pwr.*intpoints
        end

        I = speye(n,n)
        V = kron(V,I)
        A = \(V,b)

        AA = Array{Array{T,2}}(d)
        for i = 1:d
          AA[i] = A[(1:n)+(i-1)*n,:]
        end

        return PEP(AA)
    end


end