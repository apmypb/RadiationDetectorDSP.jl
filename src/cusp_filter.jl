# This file is a part of RadiationDetectorDSP.jl, licensed under the MIT License (MIT).


"""
    struct CUSPChargeFilter <: AbstractRadFIRFilter

CUSP filter.

For the definition the filter and a discussion of the filter properties, see

Constructors:

* ```$(FUNCTIONNAME)(; fields...)```

Fields:

$(TYPEDFIELDS)
"""
@with_kw struct CUSPChargeFilter{
    T <: RealQuantity, U <: Real
} <: AbstractRadFIRFilter
    "equivalent of shaping time (τₛ)"
    sigma::T = 450

    "length of flat top (FT)"
    toplen::T = 10

    "decay constant of the exponential"
    tau::T = 20

    "scaling factor"
    beta::U = 1.0

    "total length of the filter (L)"
    length::T = 100
end

export CUSPChargeFilter

Adapt.adapt_structure(to, flt::CUSPChargeFilter) = flt

function fltinstance(flt::CUSPChargeFilter, fi::SamplingInfo)
    fltinstance(ConvolutionFilter(CUSPChargeFilter(
        round(Int, ustrip(NoUnits, flt.sigma / step(fi.axis))),
        round(Int, ustrip(NoUnits, flt.toplen / step(fi.axis))),
        round(Int, ustrip(NoUnits, flt.tau / step(fi.axis))),
        round(Int, ustrip(NoUnits, flt.length / step(fi.axis))),
        flt.beta
    )), fi)
end

function ConvolutionFilter(flt::CUSPChargeFilter)
    coeffs = zac_charge_filter_coeffs(
        flt.length, flt.sigma, flt.toplen, flt.tau, flt.beta)
    ConvolutionFilter(FFTConvolution(), coeffs)
end

"""
    cusp_charge_filter_coeffs(N::Int, sigma::Int, FT::Int, tau::Int)

return a vector representing the cusp filter applicaible on a charge 
signal, where `N` is the total length of the filter, `FT` the length of 
the flat top, `sigma` the filter shaping time,`tau` the decay constant 
and `a` the scaling factor.
"""
function cusp_charge_filter_coeffs(N::Int, sigma::Int, FT::Int, tau::Int, beta)
    L::Int = ((N - FT) % 2 == 0) ? (N - FT)÷2 : (N - (FT+=1))÷2
    FF = Vector{Float64}(undef, N-1)
    
    α::Float64 = -exp(-1.0/tau)
    C::Float64 = sinh(L/sigma)
    β::Float64 = beta/N/C         # scaling factor
    Δ::Float64 = (α + 1)*beta/N
    
    # directly compute CUSP convolved with inverse response function
    # FF[i] = α * CUSP[i] + CUSP[i+1]
    for i in Base.OneTo(L)
        FF[i] = β*(α*sinh((i - 1)/sigma) + sinh(i/sigma))
        FF[end-i+1] = β*(α*sinh(i/sigma) + sinh((i - 1)/sigma))
    end
    for i in Base.OneTo(FT-1)
        FF[L+i] = Δ
    end
    FF
end