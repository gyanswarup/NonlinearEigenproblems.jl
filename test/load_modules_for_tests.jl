push!(LOAD_PATH, string(@__DIR__, "/../src"))
push!(LOAD_PATH, string(@__DIR__, "/../src/utils"))
push!(LOAD_PATH, string(@__DIR__, "/../src/gallery_extra"))
push!(LOAD_PATH, string(@__DIR__, "/../src/nleigs"))

using NEPCore
using NEPTypes
using NleigsTypes
using LinSolvers
using NEPSolver
using Gallery
using IterativeSolvers
using LinearMaps
using GalleryPeriodicDDE
using GalleryWaveguide
using Serialization

global global_modules_loaded = true
