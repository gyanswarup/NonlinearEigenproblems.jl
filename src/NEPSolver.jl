module NEPSolver
  using NEPCore
  export newton_raphson
  
  function newton_raphson(nep::NEP;
                         errmeasure=NaN,
                         tolerance=eps()*100,
                         maxit=10,
                         λ=0,
                         v=randn(nep.n,1),
                         c=v,
                         displaylevel=0)
      if (~isa(errmeasure,Function))
          # If no relresnorm available use resnorm
          if (isdefined(nep, :relresnorm))
              errmeasure=nep.relresnorm;
          else
              errmeasure=nep.resnorm;
              if (displaylevel>0)
                  println("Using resnorm")
              end
          end
      end
      err=Inf;
      v=v/(c'*v);
      try 
          for k=1:maxit
              if (displaylevel>0)
                  println("Iteration:",k,
                          " resnorm:",
                          errmeasure(λ,v))
              end
              err=errmeasure(λ,v)
              if (err< tolerance)
                  return (λ,v)
              end

              # Compute NEP matrix and derivative 
              M=nep.Md(λ)
              Md=nep.Md(λ,1)

              # Create jacobian
              J=[M Md*v; c' 0];
              F=[M*v; c'*v-1];

              # Compute update
              delta=-J\F;

              # Update eigenvalue and eigvec
              v=v+delta[1:nep.n];
              λ=λ+delta[nep.n+1];
              
          end
      catch e
          isa(e, Base.LinAlg.SingularException) || rethrow(e)  
          # This should not cast an error since it means that λ is
          # already an eigenvalue.
          if (displaylevel>0)
              println("We have an exact eigenvalue.")
          end
          if (errmeasure(λ,v)>tolerance)
              # We need to compute an eigvec somehow
              v=(nep.Md(λ,0)+eps()*speye(nep.n))\v; # Requires matrix access
              v=v/(c'*v)
          end
          return (λ,v)
      end          
      msg="Number of iterations exceeded. maxit=$(maxit)."
      throw(NoConvergenceException(λ,v,err,msg))
  end

      
end

