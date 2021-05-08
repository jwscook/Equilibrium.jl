mutable struct NumericalEquilibrium{T<:Real, S<:AbstractRange{Float64},
                                    R<:AbstractMatrix{Float64},
                                    Q<:AbstractVector{Float64}} <: AbstractEquilibrium
    cocos::COCOS       # COCOS
    r::S               # Radius/R range
    z::S               # Elevation/Z range
    psi::S             # Polodial Flux range (polodial flux from magnetic axis)
    psi_rz::R          # Polodial Flux on RZ grid (polodial flux from magnetic axis)
    g::Q               # Polodial Current
    p::Q               # Plasma pressure
    q::Q               # Q profile
    phi::Q             # Electric Potential
    axis::NTuple{2, T} # Magnetic Axis (raxis,zaxis)
    sigma::Int         # sign(dot(J,B))

    function NumericalEquilibrium(cc::COCOS, r::S, z::S, psi::S, psi_rz, g, p,
                                  q, phi, axis::NTuple{2,T}, sigma::Int) where {T,S<:AbstractRange}

        psi_rz_itp = CubicSplineInterpolation((r,z), psi_rz, extrapolation_bc=Flat())
        if step(psi) > 0
            g_itp = CubicSplineInterpolation(psi, g, extrapolation_bc=Flat())
            p_itp = CubicSplineInterpolation(psi, p, extrapolation_bc=Flat())
            q_itp = CubicSplineInterpolation(psi, q, extrapolation_bc=Flat())
            phi_itp = CubicSplineInterpolation(psi, phi, extrapolation_bc=Flat())
        else # CubicSplineInterpolation doesn't like decreasing psi so reverse them
            g_itp = CubicSplineInterpolation(reverse(psi), reverse(g), extrapolation_bc=Flat())
            p_itp = CubicSplineInterpolation(reverse(psi), reverse(p), extrapolation_bc=Flat())
            q_itp = CubicSplineInterpolation(reverse(psi), reverse(q), extrapolation_bc=Flat())
            phi_itp = CubicSplineInterpolation(reverse(psi), reverse(phi), extrapolation_bc=Flat())
        end
        R = typeof(psi_rz_itp)
        Q = typeof(g_itp)
        new{T,S,R,Q}(cc, r, z, psi, psi_rz_itp, g_itp, p_itp, q_itp, phi_itp, axis, Int(sigma))
    end
end

function Base.show(io::IO, N::NumericalEquilibrium)
    print(io, "NumericalEquilibrium{$(eltype(N.psi))}")
end

Base.broadcastable(N::NumericalEquilibrium) = (N,)

cocos(N::NumericalEquilibrium) = N.cocos

function (N::NumericalEquilibrium)(r,z)
    return N.psi_rz(r,z)
end

function magnetic_axis(N::NumericalEquilibrium)
    return N.axis
end

function B0Ip_sign(N::NumericalEquilibrium)
    return N.sigma
end

function limits(N::NumericalEquilibrium)
    return extrema(N.r), extrema(N.z)
end

function psi_limits(N::NumericalEquilibrium)
    return N.psi[1], N.psi[end]
end

function psi_gradient(N::NumericalEquilibrium,r,z)
    return SVector{2}(Interpolations.gradient(N.psi_rz, r, z))
end

function poloidal_current(N::NumericalEquilibrium, psi)
    return N.g(psi)
end

function poloidal_current_gradient(n::NumericalEquilibrium, psi)
    return Interpolations.gradient(n.g, psi)[1]
end

function pressure(N::NumericalEquilibrium, psi)
    return N.p(psi)
end

function pressure_gradient(n::NumericalEquilibrium, psi)
    return Interpolations.gradient(n.p, psi)[1]
end

function safety_factor(N::NumericalEquilibrium, psi)
    return N.q(psi)
end

function phi_gradient(N::NumericalEquilibrium, psi)
    return Interpolations.gradient(N.phi, psi)[1]
end
