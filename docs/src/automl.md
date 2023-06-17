# Integrating with Hyperopt.jl

`JsonGrinder.jl` and `Mill.jl` went long way to simplify creation of classifiers from data stored in JSONs, but they purposefully skipped the optimization of the architecture, as we authors believe this should be handled by other special-purpose libraries. Below, we show how to use `Hyperopt.jl` to do this optimization for us. Even though it is far from optimal, we can run it and forget it. The example will be based on DeviceID example, but it is quite oblivious. We start by explaining the core concepts and at the end we will include it into a full-fleged example. 

First, we create a simple function, which creates a feed-forward neural networks with input dimenions `idim`, `nlayers` number of hidden layers, `nneurons` number of neurons in hidden and output layer, `fun`  nonlinearity, and `bnfun`  nonlinearity ( `nothing` meanins disabled)

```julia
function ffnn(idim, nneurons, nlayers, fun, bnfun)
  c = []
  for i in 1:nlayers
    idim = i == 1 ? idim : nneurons
    push!(c, Dense(idim, nneurons, fun))
    if bnfun != nothing
      push!(c, BatchNorm(nneurons, bnfun))
    end
  end
  Chain(c...)
end
```

In our example, we will use *Hyperband* algorithm for its simplicity (and hopefully good results). It requires us to define two functions: first initializes the model, the second trains it for predefined number of iterations while supporting warm-start.
```julia 
function evaluatemodel(specimen, nneurons, nlayers, fun, bnfun, η)
  model = reflectinmodel(specimen, 
    d -> ffnn(d, nneurons, nlayers, fun, bnfun),
    SegmentedMeanMax, 
    fsm = Dict("" => d -> Chain(ffnn(d, nneurons, nlayers, fun, bnfun)..., Dense(nneurons, 2)))
    )
  opt = Adam(η)
  evaluatemodel(2000, model, opt)
end

function evaluatemodel(iterations, model, opt)
  ps = Flux.params(model);
  train!((x...) -> loss(model, x...), ps, minibatch, opt, iterations)
  e =  error(validation_set)
  (e, (model, opt, cby))
end
```

The call of Hyperband from `hyperband.jl`, where we prescribed the possible values for each value (for futher details see docs of `Hyperopt.jl`). (`Hyperband` does not use the parameter `i`, therefore I set it to zero. Parameter `R` determines number of resources, which corresponds to the number of tried confgiurations created by `RandomSamples` and `η` determines fraction of distarded solutions (which means that 18 solutions will be discarded in the second step). The invokation of hyperband looks like
```julia
ho = @hyperopt for i=0,
            sampler = Hyperband(R=27, η=3, inner=RandomSampler()),
            nneurons = [8,16,32,64,128],
            nlayers = [1,2,3],
            fun = [relu, tanh],
            # bnfun = [nothing, identity, relu, tanh],
            bnfun = [nothing],
            η = [1e-2,1e-3,1e-4]
  if state === nothing
    @show (nneurons, nlayers, fun, bnfun, η)
    res = evaluatemodel(specimen, nneurons, nlayers, fun, bnfun, η)
  else
     
      res = evaluatemodel(3000, state...)
  end
  res
end

model, opt = ho.minimizer
```

and we can fine-tune the model
```julia
final = evaluatemodel(20000, model, opt)
trn = = accuracy(model, trnfiles)
```
