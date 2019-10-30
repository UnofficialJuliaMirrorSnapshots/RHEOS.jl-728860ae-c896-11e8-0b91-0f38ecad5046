function _trapz(tol)
    x = [i for i in -5.0:0.01:5.0]
    y = 3*x.^2

    isapprox(RHEOS.trapz(y, x), 250.0, atol=tol)
end
@test _trapz(tol)

function _derivCD(tol)
    x = Vector(0.0:0.001:1.5)
    y = x.^2
    dy = 2*x
    dy_numeric = RHEOS.derivCD(y, x)

    isapprox(dy_numeric, dy, atol=tol)
end
@test _derivCD(tol)

function _derivBD(tol)
    x = collect(0.0:0.001:1.5)
    y = x.^2
    dy = 2*x
    dy_numeric = RHEOS.derivBD(y, x)
    # note that the backwards difference method has a weaker
    # numerical test than derivCD as it is less accurate
    all(i -> isapprox(dy[i], dy_numeric[i], atol=tol), eachindex(dy_numeric))
end
@test _derivBD(tol)

function _doublederivCD_quadratic(tol)
    x = Vector(0.0:0.001:1.5)
    y = x.^2
    dy = [2.0 for xi in x]
    dy_numeric = RHEOS.doublederivCD(y, x)

    isapprox(dy_numeric, dy, atol=tol)
end
@test _doublederivCD_quadratic(tol)

function _doublederivCD_cubic(tol)
    x = Vector(0.0:0.001:1.5)
    y = 50*x.^2 .- 2*x.^3 .+ x .- 100.0
    dy = [100.0 - 12*xi for xi in x]
    dy_numeric = RHEOS.doublederivCD(y, x)

    N = length(x)
    test1 = all(i -> isapprox(dy[i], dy_numeric[i], atol=tol), 2:(N-1))
    test2 = isapprox(dy[1], dy_numeric[1], atol=1.1*tol)
    test3 = isapprox(dy[N], dy_numeric[N], atol=1.1*tol)

    test1 && test2 && test3
end
@test _doublederivCD_cubic(tol)

function _doublederivCD_cubic_oscillatory(tol)
    x = Vector(0.0:0.001:20.0)
    y = 50*x.^2 .- 2*x.^3 .+ x .- 100.0 .+ 50.0*sin.(x)
    dy = [100.0 - 12*xi - 50*sin(xi) for xi in x]
    dy_numeric = RHEOS.doublederivCD(y, x)

    N = length(x)
    test1 = all(i -> isapprox(dy[i], dy_numeric[i], atol=tol), 2:(N-1))
    test2 = isapprox(dy[1], dy_numeric[1], atol=10*tol)
    test3 = isapprox(dy[N], dy_numeric[N], atol=10*tol)

    test1 && test2 && test3
end
@test _doublederivCD_cubic_oscillatory(tol)

@test RHEOS.constantcheck([1.0, 2.0, 3.0])==true
@test RHEOS.constantcheck([1.0, 2.0, 4.0])==false

@test RHEOS.closestindex([1.0, 2.0, 3.0], 1.7)==2

@test RHEOS.closestindices([1.0, 2.0, 3.0], [1.7, 3.4])==[2, 3]

@test RHEOS.getsigma(10.0, 1000.0)≈1873.9062512927758

function _downsample_1region()
    x0 = collect(0.0:0.01:1.0)
    y0 = x0.^2

    x1 = collect(0.0:0.1:1.0)
    y1 = x1.^2
    
    xout, yout = RHEOS.fixed_resample(x0, y0, [1, length(x0)], [-10])

    xout==x1 && yout==y1 
end
@test _downsample_1region()

function _upsample_1region()
    # must be linear as interpolation for upsampling is linear  
    x0 = collect(0.0:0.1:10.0)
    y0 = 2*x0

    x1 = collect(0.0:0.01:10.0)
    y1 = 2*x1
    
    xout, yout = RHEOS.fixed_resample(x0, y0, [1, length(x0)], [10])
    
    # note that we expect x (generated from range) to be exactly
    # the same as target higher-sampled data. y will only be the
    # same within floating point error, hence the approximate
    # comparison
    xout==x1 && yout≈y1
end
@test _upsample_1region()

function _upanddown_multipleregions()
    # data to be resampled
    x0 = collect(-10.0:0.5:10.0)
    y0 = 2*x0

    # data for comparison composed
    # of multiple sections
    x1a = collect(-10.0:0.1:-5.1)
    x1b = collect(-5.0:1.0:0.0)
    x1c = collect(0.05:0.05:4.95)
    x1d = collect(5.0:2.0:10.0)
    x1e = [x0[end]]

    x1 = vcat(x1a, x1b, x1c, x1d, x1e)
    y1 = 2*x1

    indices = [1, RHEOS.closestindex(x0, -5.0), RHEOS.closestindex(x0, 0.0), RHEOS.closestindex(x0, 5.0), length(x0)]

    xout, yout = RHEOS.fixed_resample(x0, y0, indices, [5, -2, 10, -4])

    xout==x1 && yout≈y1
end
@test _upanddown_multipleregions()

@test RHEOS.singularitytest(x->1/x)
@test RHEOS.singularitytest(x->1/(x-5.0), t1 = 5.0)
@test RHEOS.singularitytest(x->NaN)

function _boltzintegral_nonsing_ramp(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = 1 .- exp.(-t)
    ramp_loading = t
    ramp_loading_derivative = RHEOS.derivBD(ramp_loading, t)
    ramp_response = RHEOS.boltzintegral_nonsing(x->exp.(-x), t, ramp_loading_derivative)

    all(i -> isapprox(exact_response[i], ramp_response[i], atol=tol), eachindex(exact_response))
end
@test _boltzintegral_nonsing_ramp(tol)

function _boltzintegral_nonsing_ramp_2sections(tol)
    dt = 0.01
    t = [Vector{RheoFloat}(0.0:dt:(15.0-dt)); Vector{RheoFloat}(15.0:10*dt:20.0)]
    exact_response = 1 .- exp.(-t)
    ramp_loading = t
    ramp_loading_derivative = RHEOS.derivBD(ramp_loading, t)
    ramp_response = RHEOS.boltzintegral_nonsing(x->exp.(-x), t, ramp_loading_derivative)

    all(i -> isapprox(exact_response[i], ramp_response[i], atol=tol), eachindex(exact_response))
end
@test _boltzintegral_nonsing_ramp_2sections(tol)

function _boltzintegral_nonsing_linear_3sections(tol)
    t1 = Vector{RheoFloat}(0.0:0.01:9.99)
    t2 = Vector{RheoFloat}(10.0:0.1:16.9)
    t3 = Vector{RheoFloat}(17.0:0.001:20.0)
    t = [t1;t2;t3]
    exact_response = 1 .- exp.(-t)
    ramp_loading = t
    ramp_loading_derivative = RHEOS.derivBD(ramp_loading, t)
    ramp_response = RHEOS.boltzintegral_nonsing(x->exp.(-x), t, ramp_loading_derivative)

    all(i -> isapprox(exact_response[i], ramp_response[i], atol=tol), eachindex(exact_response))
end
@test _boltzintegral_nonsing_linear_3sections(tol)

function _boltzintegral_step(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = exp.(-t)
    step_loading = ones(length(t))
    step_loading_deriv = RHEOS.derivBD(step_loading,t)
    step_response = RHEOS.boltzintegral_nonsing(x->exp.(-x), t, step_loading_deriv)

    all(i -> isapprox(exact_response[i], step_response[i], atol=tol), eachindex(exact_response))
end
@test _boltzintegral_step(tol)

function _boltzintegral_linearcombo(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    step_loading = ones(length(t))
    step_loading_deriv = RHEOS.derivBD(step_loading,t)
    step_response = RHEOS.boltzintegral_nonsing(x->exp.(-x), t, step_loading_deriv)

    ramp_loading = t
    ramp_loading_deriv = RHEOS.derivBD(ramp_loading, t)
    ramp_response = RHEOS.boltzintegral_nonsing(x->exp.(-x), t, ramp_loading_deriv)

    combined_loading = t .+ ones(length(t))
    combined_loading_deriv = RHEOS.derivBD(combined_loading, t)
    combined_response = RHEOS.boltzintegral_nonsing(x->exp.(-x), t, combined_loading_deriv)

    all(i -> isapprox(combined_response[i], (step_response[i] + ramp_response[i]), atol=tol), eachindex(combined_response))
end
@test _boltzintegral_linearcombo(tol)

function _boltzintegral_nonsing_parabolic(tol)
    # response of Maxwell model to
    # a parabola: 2500 - (t-50)^2
    t = Vector{RheoFloat}(0.0:0.001:20.0)
    exact_response = 102 .- 102*exp.(-t) .- 2t
    
    loading = 2500.0 .- (t .- 50).^2
    loading_derivative = RHEOS.derivBD(loading, t)

    integration_response = RHEOS.boltzintegral_nonsing(x->exp.(-x), t, loading_derivative)

    # note that tol is 5x higher here (and sample rate is higher)
    # as trapezoidal method is relatively innacurate.
    all(i -> isapprox(exact_response[i], integration_response[i], atol=5*tol), eachindex(exact_response))
end
@test _boltzintegral_nonsing_parabolic(tol)

function _boltzintegral_sing_linear(tol)
    # response of a power-law model
    # to a linear loading: t
    t = Vector{RheoFloat}(0.0:0.01:20.0)
    β = 0.5
    exact_response = t.^(1.0 - 0.5) / (1.0 - 0.5)

    loading = t
    loading_derivative = RHEOS.derivBD(loading, t)

    integration_response = RHEOS.boltzintegral_sing(x->x.^(-β), t, loading_derivative)

    all(i -> isapprox(exact_response[i], integration_response[i], atol=4*tol), eachindex(exact_response))
end
@test _boltzintegral_sing_linear(tol)

function _boltzintegral_sing_linear_2sections(tol)
    dt = 0.01
    t = [Vector{RheoFloat}(0.0:dt:(15.0-dt)); Vector{RheoFloat}(15.0:10*dt:20.0)]
    β = 0.5
    exact_response = t.^(1.0 - 0.5) / (1.0 - 0.5)

    loading = t
    loading_derivative = RHEOS.derivBD(loading, t)

    integration_response = RHEOS.boltzintegral_sing(x->x.^(-β), t, loading_derivative)

    all(i -> isapprox(exact_response[i], integration_response[i], atol=4*tol), eachindex(exact_response))
end
@test _boltzintegral_sing_linear_2sections(tol)

# function _boltzintegral_sing_linear_3sections(tol)
#     # note this test identified that going from higher sample period to lower sample period
#       could cause innacuracies due to singularity approximation
#     t1 = Vector{RheoFloat}(0.0:0.1:4.9)
#     t2 = Vector{RheoFloat}(5.0:0.1:9.9)
#     t3 = Vector{RheoFloat}(10.0:0.01:15.0)
#     t = [t1; t2; t3]
#     β = 0.5
#     exact_response = t.^(1.0 - 0.5) / (1.0 - 0.5)

#     loading = t
#     loading_derivative = RHEOS.derivBD(loading, t)

#     integration_response = RHEOS.boltzintegral_sing(x->x.^(-β), t, loading_derivative)

#     all(i -> isapprox(exact_response[i], integration_response[i], atol=4*tol), eachindex(exact_response))
# end
# @test _boltzintegral_sing_linear_3sections(tol)

function _boltzintegral_sing_step(tol)
    # response of a power-law model
    # to a step loading
    t = Vector{RheoFloat}(0.0:0.01:20.0)
    β = 0.5
    exact_response = t.^(-0.5)

    loading = ones(length(t))
    loading_derivative = RHEOS.derivBD(loading, t)

    integration_response = RHEOS.boltzintegral_sing(x->x.^(-β), t, loading_derivative)
    
    # note that first element is skipped due to singularity
    all(i -> isapprox(exact_response[i], integration_response[i], atol=tol), 2:length(t))
end
@test _boltzintegral_sing_step(tol)

function _boltzintegral_sing_parabolic(tol)
    # response of power-law model to
    # a parabola: 2500 - (t-50)^2
    t = Vector{RheoFloat}(0.0:0.001:20.0)
    β = 0.5
    exact_response = (100/(1-β))*t.^(1-β) .- (2/((1-β)*(2-β)))*t.^(2-β)
    
    loading = 2500.0 .- (t .- 50).^2
    loading_derivative = RHEOS.derivBD(loading, t)

    integration_response = RHEOS.boltzintegral_sing(x->x.^(-β), t, loading_derivative)
    # note that first element is skipped due to singularity
    # and the higher tolerance and skipping of many elements
    # this is one of the hardest cases for the trapezoidal
    # method of hereditary integration to handle when then there
    # is a singularity.
    all(i -> isapprox(exact_response[i], integration_response[i], atol=1.0), 250:length(t))
end
@test _boltzintegral_sing_parabolic(tol)

function _obj_var_nonsing_ramp(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = 1 .- exp.(-t)
    ramp_loading = t
    ramp_loading_derivative = RHEOS.derivBD(ramp_loading, t)
    
    cost = RHEOS.obj_var_nonsing(nothing, nothing, (x, params)->exp.(-x), t, ramp_loading_derivative, exact_response) 

    cost < length(t)*tol^2
end
@test _obj_var_nonsing_ramp(tol)

function _obj_var_nonsing_step(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = exp.(-t)
    step_loading = ones(length(t))
    step_loading_deriv = RHEOS.derivBD(step_loading,t)

    cost = RHEOS.obj_var_nonsing(nothing, nothing, (x, params)->exp.(-x), t, step_loading_deriv, exact_response) 

    cost < length(t)*tol^2
end
@test _obj_var_nonsing_step(tol)

function _obj_var_nonsing_parabolic()
    # response of Maxwell model to
    # a parabola: 2500 - (t-50)^2
    t = Vector{RheoFloat}(0.0:0.001:20.0)
    exact_response = 102 .- 102*exp.(-t) .- 2t
    
    loading = 2500.0 .- (t .- 50).^2
    loading_derivative = RHEOS.derivBD(loading, t)

    cost = RHEOS.obj_var_nonsing(nothing, nothing, (x, params)->exp.(-x), t, loading_derivative, exact_response) 
    # note that cost is very high for parabolic as
    # hereditary integral approximation is not
    # good for this case.
    cost < 15*length(t)*tol
end
@test _obj_var_nonsing_parabolic()

function _obj_var_sing_linear(tol)
    # response of a power-law model
    # to a linear loading: t
    t = Vector{RheoFloat}(0.0:0.01:20.0)
    β = 0.5
    exact_response = t.^(1.0 - 0.5) / (1.0 - 0.5)

    loading = t
    loading_derivative = RHEOS.derivBD(loading, t)

    cost = RHEOS.obj_var_sing(nothing, nothing, (x, params)->x.^(-β), t, loading_derivative, exact_response) 
    
    cost < 3*length(t)*tol 
end
@test _obj_var_sing_linear(tol)

function _boltzconvolve_nonsing_ramp(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = 1 .- exp.(-t)
    ramp_loading = t
    ramp_loading_derivative = RHEOS.derivBD(ramp_loading, t)
    ramp_response = RHEOS.boltzconvolve(x->exp.(-x), t, dt, ramp_loading_derivative)

    all(i -> isapprox(exact_response[i], ramp_response[i], atol=tol), eachindex(exact_response))
end
@test _boltzconvolve_nonsing_ramp(tol)

function _boltzconvolve_step(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = exp.(-t)
    step_loading = ones(length(t))
    step_loading_deriv = RHEOS.derivBD(step_loading,t)
    step_response = RHEOS.boltzconvolve(x->exp.(-x), t, dt, step_loading_deriv)

    all(i -> isapprox(exact_response[i], step_response[i], atol=tol), eachindex(exact_response))
end
@test _boltzconvolve_step(tol)

function _boltzconvolve_linearcombo(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    step_loading = ones(length(t))
    step_loading_deriv = RHEOS.derivBD(step_loading,t)
    step_response = RHEOS.boltzconvolve(x->exp.(-x), t, dt, step_loading_deriv)

    ramp_loading = t
    ramp_loading_deriv = RHEOS.derivBD(ramp_loading, t)
    ramp_response = RHEOS.boltzconvolve(x->exp.(-x), t, dt, ramp_loading_deriv)

    combined_loading = t .+ ones(length(t))
    combined_loading_deriv = RHEOS.derivBD(combined_loading, t)
    combined_response = RHEOS.boltzconvolve(x->exp.(-x), t, dt, combined_loading_deriv)

    all(i -> isapprox(combined_response[i], (step_response[i] + ramp_response[i]), atol=tol), eachindex(combined_response))
end
@test _boltzconvolve_linearcombo(tol)

function _boltzconvolve_nonsing_parabolic(tol)
    # response of Maxwell model to
    # a parabola: 2500 - (t-50)^2
    dt = 0.001
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = 102 .- 102*exp.(-t) .- 2t
    
    loading = 2500.0 .- (t .- 50).^2
    loading_derivative = RHEOS.derivBD(loading, t)

    integration_response = RHEOS.boltzconvolve(x->exp.(-x), t, dt, loading_derivative)

    # note that tol is 5x higher here (and sample rate is higher)
    # as trapezoidal method is relatively innacurate.
    all(i -> isapprox(exact_response[i], integration_response[i], atol=5*tol), eachindex(exact_response))
end
@test _boltzconvolve_nonsing_parabolic(tol)

function _boltzconvolve_sing_linear(tol)
    # response of a power-law model
    # to a linear loading: 
    dt = 0.001
    t = Vector{RheoFloat}(0.0:dt:20.0)
    β = 0.5
    exact_response = t.^(1.0 - 0.5) / (1.0 - 0.5)

    loading = t
    loading_derivative = RHEOS.derivBD(loading, t)
    
    t[1] = dt/10.0
    integration_response = RHEOS.boltzconvolve(x->x.^(-β), t, dt, loading_derivative)
    
    all(i -> isapprox(exact_response[i], integration_response[i], atol=5*tol), eachindex(exact_response))
end
@test _boltzconvolve_sing_linear(tol)

function _boltzconvolve_sing_step(tol)
    # response of a power-law model
    # to a step loading
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    β = 0.5
    exact_response = t.^(-0.5)

    loading = ones(length(t))
    loading_derivative = RHEOS.derivBD(loading, t)

    t[1] = dt/10.0
    integration_response = RHEOS.boltzconvolve(x->x.^(-β), t, dt, loading_derivative)
    
    # note that first element is skipped due to singularity
    all(i -> isapprox(exact_response[i], integration_response[i], atol=tol), 2:length(t))
end
@test _boltzconvolve_sing_step(tol)

function _boltzconvolve_sing_parabolic(tol)
    # response of power-law model to
    # a parabola: 2500 - (t-50)^2
    dt = 0.001
    t = Vector{RheoFloat}(0.0:dt:20.0)
    β = 0.5
    exact_response = (100/(1-β))*t.^(1-β) .- (2/((1-β)*(2-β)))*t.^(2-β)
    
    loading = 2500.0 .- (t .- 50).^2
    loading_derivative = RHEOS.derivBD(loading, t)

    t[1] = dt/10.0
    integration_response = RHEOS.boltzconvolve(x->x.^(-β), t, dt, loading_derivative)
    # note that first element is skipped due to singularity
    # and the higher tolerance and skipping of many elements
    # this is one of the hardest cases for the trapezoidal
    # method of hereditary integration to handle when then there
    # is a singularity.
    all(i -> isapprox(exact_response[i], integration_response[i], atol=7.0), 250:length(t))
end
@test _boltzconvolve_sing_parabolic(tol)

function _obj_const_nonsing_ramp(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = 1 .- exp.(-t)
    ramp_loading = t
    ramp_loading_derivative = RHEOS.derivBD(ramp_loading, t)
    
    cost = RHEOS.obj_const_nonsing(nothing, nothing, (x, params)->exp.(-x), t, dt, ramp_loading_derivative, exact_response) 

    cost < length(t)*tol^2
end
@test _obj_const_nonsing_ramp(tol)

function _obj_const_nonsing_step(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = exp.(-t)
    step_loading = ones(length(t))
    step_loading_deriv = RHEOS.derivBD(step_loading,t)

    cost = RHEOS.obj_const_nonsing(nothing, nothing, (x, params)->exp.(-x), t, dt, step_loading_deriv, exact_response) 

    cost < length(t)*tol^2
end
@test _obj_const_nonsing_step(tol)

function _obj_const_nonsing_parabolic()
    # response of Maxwell model to
    # a parabola: 2500 - (t-50)^2
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = 102 .- 102*exp.(-t) .- 2t
    
    loading = 2500.0 .- (t .- 50).^2
    loading_derivative = RHEOS.derivBD(loading, t)

    cost = RHEOS.obj_const_nonsing(nothing, nothing, (x, params)->exp.(-x), t, dt, loading_derivative, exact_response) 
    # note that cost is very high for parabolic as
    # hereditary integral approximation is not
    # good for this case.
    cost < 15*length(t)*tol
end
@test _obj_const_nonsing_parabolic()

function _obj_const_sing_linear(tol)
    # response of a power-law model
    # to a linear loading: t
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    β = 0.5
    exact_response = t.^(1.0 - 0.5) / (1.0 - 0.5)

    loading = t
    loading_derivative = RHEOS.derivBD(loading, t)
      
    t[1] = dt/10.0
    cost = RHEOS.obj_const_sing(nothing, nothing, (x, params)->x.^(-β), t, dt, loading_derivative, exact_response) 
    
    cost < 3*length(t)*tol 
end
@test _obj_const_sing_linear(tol)

function _leastsquares_init_const_nonsing_ramp(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    exact_response = 1.0 .- exp.(-t)
    ramp_loading = t
    ramp_loading_derivative = RHEOS.derivBD(ramp_loading, t)
    #ramp_response = RHEOS.boltzconvolve(x->exp.(-x), t, dt, ramp_loading_derivative)
    modulus = (t, params)->(params[1]*exp.(-t/params[2]))

    init_params = [1.0, 1.0]
    results = RHEOS.leastsquares_init(init_params, [0.90, 0.90], [1.1, 1.1], modulus, t, dt, ramp_loading_derivative, exact_response; constant_sampling = true)

    found_params = results[2]

    isapprox(found_params, init_params, atol=tol)
end
@test _leastsquares_init_const_nonsing_ramp(tol)

function _leastsquares_init_var_nonsing_ramp(tol)
    dt = 0.01
    t = [Vector{RheoFloat}(0.0:dt:(15.0-dt)); Vector{RheoFloat}(15.0:10*dt:20.0)]
    exact_response = 1.0 .- exp.(-t)
    ramp_loading = t
    ramp_loading_derivative = RHEOS.derivBD(ramp_loading, t)
    #ramp_response = RHEOS.boltzconvolve(x->exp.(-x), t, dt, ramp_loading_derivative)
    modulus = (t, params)->(params[1]*exp.(-t/params[2]))

    init_params = [1.0, 1.0]
    results = RHEOS.leastsquares_init(init_params, [0.90, 0.90], [1.1, 1.1], modulus, t, dt, ramp_loading_derivative, exact_response; constant_sampling = false)

    found_params = results[2]

    isapprox(found_params, init_params, atol=tol)
end
@test _leastsquares_init_var_nonsing_ramp(tol)

function _leastsquares_init_const_sing_ramp(tol)
    # response of a power-law model
    # to a linear loading: 
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    β = 0.5
    exact_response = t.^(1.0 - β) / (1.0 - β)

    loading = t
    loading_derivative = RHEOS.derivBD(loading, t)


    modulus = (t, params)->t.^(-params[1])
    init_params = [0.5]
    results = RHEOS.leastsquares_init(init_params, [0.3], [0.7], modulus, t, dt, loading_derivative, exact_response; constant_sampling = true, singularity=true)
    found_params = results[2]

    isapprox(found_params, init_params, atol=tol)
end
@test _leastsquares_init_const_sing_ramp(tol)

function _leastsquares_init_var_sing_ramp(tol)
    # response of a power-law model
    # to a linear loading: 
    dt = 0.01
    t = [Vector{RheoFloat}(0.0:dt:(15.0-dt)); Vector{RheoFloat}(15.0:10*dt:20.0)]
    β = 0.5
    exact_response = t.^(1.0 - β) / (1.0 - β)

    loading = t
    loading_derivative = RHEOS.derivBD(loading, t)


    modulus = (t, params)->t.^(-params[1])
    init_params = [0.5]
    results = RHEOS.leastsquares_init(init_params, [0.3], [0.7], modulus, t, dt, loading_derivative, exact_response; constant_sampling = false, singularity=true)
    found_params = results[2]

    isapprox(found_params, init_params, atol=tol)
end
@test _leastsquares_init_var_sing_ramp(tol)

function _obj_step_nonsing()
    t = Vector{RheoFloat}(0.0:0.001:20.0)
    params = [2.0, 0.5]
    modulus = (x, p)->p[1]*exp.(-x/p[2])
    loading = 1.0
    expected_response = params[1]*exp.(-t/params[2])
    cost = RHEOS.obj_step_nonsing(params, nothing, modulus, t, loading, expected_response) 
    
    cost < tol
end
@test _obj_step_nonsing()

function _obj_step_weighted()
    t = Vector{RheoFloat}(0.0:0.5:20.0)
    params = [2.0, 0.5]
    modulus = (x, p)->p[1]*x.^(-p[2])
    loading = 1.0
    expected_response = loading*params[1]*t.^(-params[2])
    cost = RHEOS.obj_step_weighted(params, nothing, modulus, t, loading, expected_response[2:end], collect(Integer, 2:length(t))) 
    
    cost < tol
end
@test _obj_step_weighted()

function _leastsquares_stepinit_nonsing_ramp(tol)
    dt = 0.01
    t = Vector{RheoFloat}(0.0:dt:20.0)
    params = [2.0, 0.5]
    loading = 1.0
    expected_response = loading*params[1]*exp.(-t/params[2])

    modulus = (x, p)->p[1]*exp.(-x/p[2])
    init_params = [1.0, 1.0]
    results = RHEOS.leastsquares_stepinit(init_params, [0.70, 0.1], [3.0, 1.5], modulus, t, loading, expected_response)

    found_params = results[2]

    isapprox(params, found_params, atol=tol)
end
@test _leastsquares_stepinit_nonsing_ramp(tol)

function _leastsquares_stepinit_sing_ramp(tol)
    dt = 0.1
    t = Vector{RheoFloat}(0.0:dt:20.0)
    params = [2.0, 0.5]
    loading = 1.0
    expected_response = loading*params[1]*t.^(-params[2])

    modulus = (x, p) -> p[1]*x.^(-p[2]) 
    init_params = [1.0, 1.0]
    results = RHEOS.leastsquares_stepinit(init_params, [0.70, 0.1], [3.0, 1.5], modulus, t, loading, expected_response; singularity=true)
    
    found_params = results[2]

    isapprox(params, found_params, atol=tol)
end
@test _leastsquares_stepinit_sing_ramp(tol)