function [V,T,omega] = Lanczos_nep_full(nep,k,q1)
%LANCZOS Indefinite Lanczos method
%   Implementation of the indefinite Lanczos method as 
%   described in the manuscript. Three vertors are used.
%
% TODO:
% Fix now the multiplication with the matrix L

n=nep.n;
% projection matrix
T=zeros(k+1,k);
% initialize vectors of the three term recurrence
Q=zeros(n,k+1); Qp=zeros(n,k+1); Qn=zeros(n,k+1);
Q(:,1)=q1; 
% initialize the vector containing the B-norms
omega=zeros(k+1,1);

omega(1)=Q(:,1)'*(nep.Md(1,Q(:,1)));
% initialize the matrix that will contain the
% first block row of the Krylov basis
V=zeros(n,k+1);
V(:,1)=q1;

% precompute the matrix that factorizes SB
G=zeros(2*k+2,2*k+2);G(1,:)=1./(1:(2*k+2));  G(:,1)=1./(1:(2*k+2));  
C=gen_matrix_c(2*k+2);  
for j=1:2*k+2   % later try to avoid for loops
    for i=2:2*k+2
        G(i,j)=C(i-1,j)/j;
    end
end
G=G(1:k+1,1:k+1);



W=zeros(n,k+1);
Z=zeros(n,k+1);
p=length(nep.f);

for j=1:k
    
    % action of A^(-1) B 
    W(:,2:j+1)=bsxfun(@rdivide,Q(:,1:j),1:j);
    W(:,1)=nep.Mlincomb(ones(j,1),W(:,2:j+1));
    W(:,1)=-nep.Minv(W(:,1));
    
    
    % B-multiplcation 
    % TODO: this should be profiled and we should
    % approximate G with a low rank matrix and do
    % the trick with circulant matrices
    Z=0*Z;
    for t=1:p
        Z(:,1:j+1)=Z(:,1:j+1)+(nep.A{t}*W(:,1:j+1))*(G(1:j+1,1:j+1).*nep.FHD{t}(1:j+1,1:j+1));
    end
    
        
    % orthogonlization (three terms recurrence)
    alpha=sum(sum(bsxfun(@times,conj(Z),Q)));%=Z(:)'*Q(:);
    if j>1
        beta=sum(sum(bsxfun(@times,conj(Z),Qp)));%=Z(:)'*Qp(:);
    end
    gamma=sum(sum(bsxfun(@times,conj(Z),W)));%=Z(:)'*W(:);
    
    % from this point nothing changes
    T(j,j)=alpha/omega(j);    
    if j>1
        T(j-1,j)=beta/omega(j-1);
    end
    
    W_orth=W-T(j,j)*Q;
    if j>1
        W_orth=W_orth-T(j-1,j)*Qp;
    end
    
    T(j+1,j)=norm(W_orth,'fro');% =norm(W_orth(:))
    Qn=W_orth/T(j+1,j);
    
    omega(j+1)=gamma-2*T(j,j)*alpha+T(j,j)^2*omega(j);
    if j>1
        omega(j+1)=omega(j+1)-2*T(j-1,j)*beta+T(j-1,j)^2*omega(j-1);
    end
    omega(j+1)=omega(j+1)/T(j+1,j)^2;

    V(:,j+1)=Qn(:,1);       
    % shift the vectors
    Qp=Q;   Q=Qn;
    
end

end

function [ c ] = gen_matrix_c( m )
%GEN_COEFFS generate the coefficients involved in the B matrix
%   Detailed explanation goes here

c=zeros(m);
for i=1:m
    c(i,1)=1/(i+1);
end

for j=2:m
    for i=m:-1:2
        c(i-1,j)=c(i,j-1)*j/i;
    end
end

end



