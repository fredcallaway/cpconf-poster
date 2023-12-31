using Distributed
addprocs()
@everywhere begin
    include("base.jl")
    include("curve_fitting.jl")
    include("tree.jl")
    using ProgressMeter

    function control_ratio(t, p_slip)
        d1 = VDist(t; p_slip)
        d0 = VDist(t; p_slip=.5)

        h1 = fit(Histogram, d1.v, Weights(d1.p), -3.25:.5:3.25)
        h0 = fit(Histogram, d0.v, Weights(d0.p), -3.25:.5:3.25)

        x = centers(h0.edges[1])
        p0 = StatsBase.normalize(h0, mode=:pdf).weights
        p1 = StatsBase.normalize(h1, mode=:pdf).weights
        p1 ./ p0
    end

    αs = [.6, .7, .8, .9]
    p_slips = 1 .- αs
end

# %% ==================== individual ====================

curves = cache("cache/curves") do
    map(p_slips) do p_slip
        repeatedly(30) do
            t = tree(14, Normal(0, 1));
            control_ratio(t, p_slip)
        end
    end
end

# %% --------


figure("tree_indiv_big"; pdf=true) do
    x = -3:.5:3
    plots = map(curves, p_slips) do curve, p_slip
        p = plot(titlefontsize=8, ylim=(0, 120))
        xs = reduce(vcat, fill(x, 30))
        ys = reduce(vcat, curve)
        plot!(x, reduce(hcat, curve), color=:black, alpha=0.3, w=1)
        plot!(-3:.01:3, exponential(-3:.01:3, fit_exponential(xs, ys)), ls=:dot, color=CBIAS)
        p
    end
    plot(plots..., size=(770, 250), layout=(1, 4), grid=false,
        xlim = (-1, 3),
        # xticks=[-3, 0, 3], yticks=[0, 20, 40]
        ticks=false, widen=false, framestyle=:origin
    )
end



# %% ==================== averages ====================


# p_slips = logrange(.05, .5; length=5)[1:end-1]
hists = cache("cache/hists") do
    edges = -6:.01:6
    n_sim = Int(1e6)
    map(p_slips) do p_slip
        weights = @showprogress @distributed (+) for i in 1:n_sim
            # i % 100 == 0 && yield()
            d = VDist(tree(14, Normal(0, 1)); p_slip);
            fit(Histogram, d.v, Weights(d.p), edges).weights
        end
        Histogram(edges, weights)
    end
end
# %% --------

pdfs = map(hists) do hist
    StatsBase.normalize(hist, mode=:pdf).weights
end

x = centers(hists[1].edges[1])
y0 = pdf.(Normal(0,1), x)

using SmoothingSplines

figure("tree_returns_big"; pdf=true) do
    ys = [[y0]; pdfs]
    pal = range(parse(Colorant, groups.low.color), stop=parse(Colorant, groups.high.color), length=length(ys))
    foreach(enumerate(ys)) do (i, y1 )
        m = fit(SmoothingSpline, x, y1, 1e-3)
        plot!(x, predict(m, x), color=pal[i])
    end
    plot!(ticks=false, grid=false, size=(450, 250), framestyle=:origin, widen=false)
end
# %% --------

figure("tree_fits") do
    ps = map(pdfs) do y1
        plot()
        i = max(1, findfirst(y1 ./ y0 .> 0))
        plot_fit!(x, y1 ./ y0)
        # plot!(xlim=(-2, 5), ylim=(-3, 10))
    end
    plot(ps..., size= 1.5 .* (800,200), layout=(1,5))
end

