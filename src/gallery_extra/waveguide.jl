

export gallery_waveguide
export matlab_debug_WEP_FD #ONLY FOR DEBUGGING

"
Creates the NEP associated with example in
E. Ringh, and G. Mele, and J. Karlsson, and E. Jarlebring, 
Sylvester-based preconditioning for the waveguide eigenvalue problem,
Linear Algebra and its Applications, 2017

and

E. Jarlebring, and G. Mele, and O. Runborg
The waveguide eigenvalue problem and the tensor infinite Arnoldi method
SIAM J. Sci. Comput., 2017
"
function gallery_waveguide( nx::Integer = 3*5*7, nz::Integer = 3*5*7, waveguide::String = "TAUSCH", discretization::String = "FD", NEP_format_type::String = "SPMF",  delta::Number = 0.1)
    waveguide = uppercase(waveguide)
    NEP_format_type = uppercase(NEP_format_type)
    discretization = uppercase(discretization)
    if !isodd(nz)
        error("Variable nz must be odd! You have used nz = ", nz, ".")
    end

    # Generate the matrices for the sought waveguide
    if discretization == "FD"
        K, hx, hz, k = generate_wavenumber_fd( nx, nz, waveguide, delta)
        Dxx, Dzz, Dz, C1, C2T = generate_fd_matrices( nx, nz, hx, hz)
    elseif discretization == "FEM"
        error("FEM discretization of WEP is not implemented yet.")
        #K, hx, hz = generate_wavenumber_fem( nx, nz, waveguide, delta)
        # generate_fem_matrices(nx, nz, hx, hz)
    else
        error("The discretization '", discretization, "' is not supported.")
    end

    P, p_P = generate_P_matrix(nz, hx, k)


    # Formulate the problem is the sought format
    if NEP_format_type == "SPMF"
        nep = K #assemble_waveguide_spmf TODO: This is a Placeholder!
    else
        error("The NEP-format '", NEP_format_type, "' is not supported.")
    end


    return nep
end 


###########################################################
# Waveguide eigenvalue problem (WEP)
# Sum of products of matrices and functions (SPMF)
        
"""
 Waveguide eigenvalue problem (WEP)
Sum of products of matrices and functions (SPMF)
"""
function assemble_waveguide_spmf( )
    #return SPMF_NEP(AA,fii::Array)
end    


###########################################################
# Generate discretization matrices for FINITE DIFFERENCE
    """
 Genearate the discretization matrices for Finite Difference.
"""
function generate_fd_matrices( nx, nz, hx, hz)
    ex = ones(nx)
    ez = ones(nz)

    # DISCRETIZATION OF THE SECOND DERIVATIVE
    Dxx = spdiagm((ex[1:end-1], -2*ex, ex[1:end-1]), (-1, 0, 1), nx, nx)
    Dzz = spdiagm((ez[1:end-1], -2*ez, ez[1:end-1]), (-1, 0, 1), nz, nz)
    #IMPOSE PERIODICITY IN Z-DIRECTION
    Dzz[1, end] = 1;
    Dzz[end, 1] = 1;

    Dxx = Dxx/(hx^2);
    Dzz = Dzz/(hz^2);

    # DISCRETIZATION OF THE FIRST DERIVATIVE
    Dz  = spdiagm((-ez[1:end-1], ez[1:end-1]), (-1, 1), nz, nz);

    #IMPOSE PERIODICITY
    Dz[1, end] = -1;
    Dz[end, 1] = 1;

    Dz = Dz/(2*hz);

    # BUILD THE SECOND BLOCK C1
    e1 = spzeros(nx,1)
    e1[1] = 1
    en = spzeros(nx,1)
    en[end] = 1
    Iz = speye(nz,nz)
    C1 = [kron(e1,Iz) kron(en,Iz)]/(hx^2);


    # BUILD THE THIRD BLOCK C2^T
    d1 = 2/hx;
    d2 = -1/(2*hx);
    vm = spzeros(1,nx);
    vm[1] = d1;
    vm[2] = d2;
    vp = spzeros(1,nx);
    vp[end] = d1;
    vp[end-1] = d2;
    C2T = [kron(vm,Iz); kron(vp,Iz)];

    return Dxx, Dzz, Dz, C1, C2T
end


###########################################################
# Generate Wavenumber FINITE DIFFERENCE
    """
 Genearate a wavenumber for Finite Difference.
"""
function generate_wavenumber_fd( nx::Integer, nz::Integer, wg::String, delta::Number)
    if wg == "TAUSCH"
        return generate_wavenumber_fd_tausch( nx, nz, delta)
    elseif wg == "JARLEBRING"
        return generate_wavenumber_fd_jarlebring( nx, nz, delta) 
    end
    # Use early-bailout principle. If a supported waveguide is found, compute and return. Otherwise end up here and throw and error
    error("No wavenumber loaded: The given Waveguide '", wg ,"' is not supported in 'FD' discretization.")
end


    """
 Genearate the wavenumber in FD discretization for the waveguide
described by TAUSCH.
"""
function generate_wavenumber_fd_tausch( nx::Integer, nz::Integer, delta::Number)
    xm = 0;
    xp = (2/pi) + 0.4;
    zm = 0;
    zp = 1;

    xm = xm - delta;
    xp = xp + delta;

    # Domain (First generate including the boundary)
    X = linspace(xm, xp, nx+2);
    const hx = step(X);
    X = collect(X);
    Z =linspace(zm, zp, nz+1);
    const hz = step(Z);
    Z = collect(Z);
    # Removing the boundary
    X = X[2:end-1];
    Z = Z[2:end];


    # The actual wavenumber
    const k1 = sqrt(2.3)*pi;
    const k2 = sqrt(3)*pi;
    const k3 = pi;
    k = function(x,z)
            z_ones = ones(size(z)) #Placeholder of ones to expand x-vector
            k1*(x .<= 0) .* z_ones +
            k2*(x.>0) .* (x.<=2/pi) .* z_ones +
            k2*(x.>2/pi) .* (x.<=(2/pi+0.4)) .* (z.>0.5) +
            k3*(x.>2/pi) .* (z.<=0.5) .* (x.<=(2/pi+0.4)) +
            k3*(x.>(2/pi+0.4)) .* z_ones;
        end

    const K = k(X', Z).^2;

    return K, hx, hz, k
end


    """
 Genearate the wavenumber in FD discretization for the waveguide
described by JARLEBRING.
"""
function generate_wavenumber_fd_jarlebring( nx::Integer, nz::Integer, delta::Number)
    xm = -1;
    xp = 1;
    zm = 0;
    zp = 1;

    xm = xm - delta;
    xp = xp + delta;

    # Domain (First generate including the boundary)
    X = linspace(xm, xp, nx+2);
    const hx = step(X);
    X = collect(X);
    Z =linspace(zm, zp, nz+1);
    const hz = step(Z);
    Z = collect(Z);
    # Removing the boundary
    X = X[2:end-1];
    Z = Z[2:end];


    # The actual wavenumber
    const k1 = sqrt(2.3)*pi;
    const k2 = 2*sqrt(3)*pi;
    const k3 = 4*sqrt(3)*pi;
    const k4 = pi;
    k = function(x,z)
            z_ones = ones(size(z)) #Placeholder of ones to expand x-vector
            x_ones = ones(size(x)) #Placeholder of ones to expand z-vector
            k1 *(x.<=-1) .* z_ones  +
            k4 *(x.>1) .* z_ones  +
            k4 *(x.>(-1+1.5)) .* (x.<=1) .* (z.<=0.4) +
            k3 *(x.>(-1+1)) .* (x.<=(-1+1.5)) .* z_ones +
            k3 *(x.>(-1+1.5)) .* (x.<=1) .* (z.>0.4) +
            k3 *(x.>-1) .* (x.<=(-1+1)) .* (z.>0.5) .* (z.*x_ones-(x.*z_ones)/2.<=1) +
            k2 *(x.>-1) .* (x.<=(-1+1)) .* (z.>0.5) .* (z.*x_ones-(x.*z_ones)/2.>1) +
            k3 *(x.>-1) .* (x.<=(-1+1)) .* (z.<=0.5) .* (z.*x_ones+(x.*z_ones)/2.>0) +
            k2 *(x.>-1) .* (x.<=(-1+1)) .* (z.<=0.5) .* (z.*x_ones+(x.*z_ones)/2.<=0);
        end

    const K = k(X', Z).^2;
    return K, hx, hz, k
end


###########################################################
# Generate discretization matrices for FINITE ELEMENT
    """
 Genearate the discretization matrices for Finite Difference.
"""
function generate_fem_matrices( nx, nz, hx, hz)
        error("FEM discretization currently not supported.")
end


###########################################################
# Generate Wavenumber FINITE ELEMENT
    """
 Genearate a wavenumber for Finite Element.
"""
function generate_wavenumber_fem( nx::Integer, nz::Integer, wg::String, delta::Number)
    # Use early-bailout principle. If a supported waveguide is found, compute and return. Otherwise end up here and throw and error (see FD implementation)
    error("No wavenumber loaded: The given Waveguide '", wg ,"' is not supported in 'FEM' discretization.")
end


###########################################################
# Generate P-matrix
function generate_P_matrix(nz::Integer, hx, k::Function)
    # The scaled FFT-matrix R
    const p = (nz-1)/2;
    const bb = exp(-2im*pi*((1:nz)-1)*(-p)/nz);  # scaling to do after FFT
    const F = plan_fft(ones(Complex128, nz), 1 , flags = FFTW.ESTIMATE)
    function R(X)
        return flipdim(bb .* (F*X), 1);
    end
    bbinv = 1./bb; # scaling to do before inverse FFT
    const Finv = plan_ifft(ones(Complex128, nz), 1 , flags = FFTW.ESTIMATE)
    function Rinv(X)
        return Finv*(bbinv .* flipdim(X,1));
    end

    # Constants from the problem
    const Km = k(-Inf, 1/2)[1];
    const Kp = k(Inf, 1/2)[1];
    const d0 = -3/(2*hx);
    const a = ones(Complex128,nz);
    const b = 4*pi*1im * (-p:p);
    const cM = Km^2 - 4*pi^2 * ((-p:p).^2);
    const cP = Kp^2 - 4*pi^2 * ((-p:p).^2);


    function betaM(γ)
        return a*γ^2 + b*γ + cM
    end
    function betaP(γ)
        a*γ^2 + b*γ + cP
    end

    const signM = 1im*sign(imag(betaM(-1-1im))); # OBS! LEFT HALF-PLANE!
    const signP = 1im*sign(imag(betaP(-1-1im))); # OBS! LEFT HALF-PLANE!

    sM = γ -> signM.*sqrt(betaM(γ))+d0;
    sP = γ -> signP.*sqrt(betaP(γ))+d0;

    p_sM = γ -> signM.*(2*a*γ+b)./(2*sqrt(a*γ^2+b*γ+cM));
    p_sP = γ -> signP.*(2*a*γ+b)./(2*sqrt(a*γ^2+b*γ+cP));

    # BUILD THE FOURTH BLOCK P
    function P(γ,x::Union{Array{Complex128,1}, Array{Float64,1}})
        return [R(Rinv(x[1:Int64(end/2)]) .* sM(γ));
                R(Rinv(x[Int64(end/2)+1:end]) .* sP(γ))  ];
    end

    # BUILD THE DERIVATIVE OF P
    function p_P(γ,x::Union{Array{Complex128,1}, Array{Float64,1}})
        return [R(Rinv(x[1:Int64(end/2)]) .* p_sM(γ));
                R(Rinv(x[Int64(end/2)+1:end]) .* p_sP(γ))  ];
    end

    return P, p_P
end



######################## DEBUG ############################
###########################################################
# DEBUG: Test the generated matrices against MATLAB code
using MATLAB
function matlab_debug_WEP_FD(nx::Integer, nz::Integer, delta::Number)
    if(nx > 200 || nz > 200)
        warn("This debug is 'naive' and might be slow for the discretization used.")
    end

    #The error observed likely comes from difference in linspace-implementation.
    #include("../bugs/test_linspace.jl")

    γ = -rand() - 1im*rand()
    gamma = γ


    for waveguide = ["TAUSCH", "JARLEBRING"]
    println("\n")
    println("Testing waveguide: ", waveguide)

    K, hx, hz, k = generate_wavenumber_fd( nx, nz, waveguide, delta)
    Dxx, Dzz, Dz, C1, C2T = generate_fd_matrices( nx, nz, hx, hz)
    P, p_P = generate_P_matrix(nz, hx, k)

    if waveguide == "JARLEBRING"
        waveguide_str = "CHALLENGE"
    else
        waveguide_str = waveguide
    end

    println("  -- Matlab printouts start --")
    WEP_path = "../matlab/WEP"
    @mput nx nz delta WEP_path waveguide_str gamma
    @matlab begin
        addpath(WEP_path)
        nxx = double(nx)
        nzz = double(nz)
        options = struct
        options.delta = delta
        options.wg = waveguide_str
        matlab_nep = nep_wg_generator(nxx, nzz, options)

        P_m = NaN(2*nz, 2*nz);
        Iz = eye(2*nz);
        eval("for i = 1:2*nz;   P_m(:,i) = matlab_nep.P(gamma, Iz(:,i));    end")
        C1_m = matlab_nep.C1;
        C2T_m = matlab_nep.C2T;
        K_m = matlab_nep.K;
        hx_m = matlab_nep.hx;
        hz_m = matlab_nep.hz;

    @matlab end
    @mget K_m C2T_m C1_m hx_m hz_m P_m
    println("  -- Matlab printouts end --")

    P_j = zeros(Complex128, 2*nz,2*nz)
    Iz = eye(2*nz, 2*nz)
    for i = 1:2*nz
        P_j[:,i] = P(γ, Iz[:,i])
    end

    println("Difference hx_m - hx = ", abs(hx_m-hx))
    println("Relative difference (hx_m - hx)/hx = ", abs(hx_m-hx)/abs(hx))
    println("Difference hz_m - hz = ", abs(hz_m-hz))
    println("Difference K_m  -K = ", norm(K_m-K))
    println("Difference C1_m - C1 = ", norm(full(C1_m-C1)))
    println("Relative difference norm(C1_m - C1)/norm(C1) = ", norm(full(C1_m-C1))/norm(full(C1)))
    println("Difference C1_m[1,1] - C1[,1] = ", abs(C1_m[1,1]-C1[1,1]))
    println("Relative difference (C1_m[1,1] - C1[,1])/C1[1,1] = ", abs(C1_m[1,1]-C1[1,1])/abs(C1[1,1]))
    println("C1_m[1,1] = ", C1_m[1,1])
    println("C1[1,1]   = ", C1[1,1])
    println("Difference C2T_m - C2T = ", norm(full(C2T_m-C2T)))
    println("Relative difference norm(C2T-m - C2T)/norm(C2T) = ", norm(full(C2T_m-C2T))/norm(full(C2T)))
    println("Difference P_m(γ) - P(γ) = ", norm(P_m-P_j))
    println("Relative difference norm(P_m(γ) - P(γ))/norm(P(γ)) = ", norm(P_m-P_j)/norm(P_j))

    end
end



