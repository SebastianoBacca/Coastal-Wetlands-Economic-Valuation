#avoided_damage_run

using Pkg

# Activate environment (checks dependencies)
Pkg.activate("C:/Users/sebas/DIVA/diva_library")
# Installs missing dependencies
Pkg.instantiate()

# Includes DIVACoast.jl module
include("C:/Users/sebas/DIVA/diva_library/src/DIVACoast.jl")
#mac include("C:/Users/sebas/DIVA/diva_library/src/DIVACoast.jl")

using .DIVACoast

using CSV
using NearestNeighbors
using DataFrames
using Distances
using LsqFit
using Distributions
using NCDatasets
using Logging
using IterTools

cd(@__DIR__)

#ENV["DIVA_PROJECTS"] = "C:/Users/sebas/DIVA/diva_projects"
# mac env

global_logger(DIVALogger("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper/wetlands_run.log"))

country_data = (CSV.read("$(ENV["DIVA_DATA"])/population/totalpop_GHSL_2015_COUNTRY.csv", DataFrame))
country_pop = Dict(country_data.countryid .=> country_data.totalpop)

@info "load SSP scenarios"
population_scenario = SSPScenarioReader{AnnualGrowthPercentage}(CSV.read("$(ENV["DIVA_DATA"])/scenarios/ssp/IIASA_pop_growth.csv", DataFrame))
gdp_scenario = SSPScenarioReader{AnnualGrowthPercentage}(CSV.read("$(ENV["DIVA_DATA"])/scenarios/ssp/OECD_GDP_growth.csv", DataFrame))

#2015 prices
const global low_income = 1025
const global lower_middle_income = 4035
const global upper_middle_income = 12475

#######################attenuation rates (sensitivity)##################################

#high
#const global saltmarshes_attenuation = 0.26  #0.26m/km
#const global tidalflats_attenuation = 0.2  #0.2m/km
#const global mangroves_attenuation = 0.7  #0.7m/km

#medium
#const global saltmarshes_attenuation = 0.2  #0.2m/km
#const global tidalflats_attenuation = 0.1  #0.1m/km
#const global mangroves_attenuation = 0.5   #0.5m/km

#low
#const global saltmarshes_attenuation = 0.1  #0.1m/km
#const global tidalflats_attenuation = 0.02  #0.02m/km
#const global mangroves_attenuation = 0.25   #0.25m/km


function first_n_entries(dict :: Dict{KT,VT}, n :: Int) where {KT,VT}
  c = 0
  ret = Dict{KT,VT}()
  for (k,v) in dict
#    println(k," - ",v)
    ret[k] = v
    c = c + 1
    if c >= n 
      break
    end
  end
  return ret
end

println("Constructing model: ")
print("reading floodplain data ... ")
@info "reading floodplain data"
hspfs_floodplains = load_hsps_nc(Int32, Float32, "$(ENV["DIVA_DATA"])/project_data/ACCREU/nc/Global_hspfs_floodplains.nc")
@info "reading segment data"
###hspfs_segments    = Dict{Int32, HypsometricProfile{Float32}}()
hspfs_segments = load_hsps_nc(Int32, Float32, "$(ENV["DIVA_DATA"])/project_data/ACCREU/nc/Global_hspfs_segments.nc")

##@info "compress data"
#foreach(x -> compress!(x), values(hspfs_floodplains))
#foreach(x -> compress!(x), values(hspfs_segments))

# read data floodplains and segments (need especially lon,lat of both)
@info "read floodplain metadata"
df_floodplain_data = DataFrame(CSV.File("$(ENV["DIVA_DATA"])/project_data/ACCREU/csv/floodplain_H100+2m_GADM1_partitioned_including_wetland_area.csv"))
df_segment_data    = DataFrame(CSV.File("$(ENV["DIVA_DATA"])/project_data/ACCREU/csv/cls/Global_cls.csv"))
rename!(df_segment_data,:length => :coast_length)


# technical stuff - Can be skipped later?
# First filter out "NA" values
df_floodplain_data = filter(:longitude => x -> !(x == "NA"), df_floodplain_data)

# Convert to Float64 only if the columns aren't already Float64
if eltype(df_floodplain_data.longitude) != Float64
    df_floodplain_data[!, :longitude] = parse.(Float64, df_floodplain_data[!, :longitude])
end

if eltype(df_floodplain_data.latitude) != Float64
    df_floodplain_data[!, :latitude] = parse.(Float64, df_floodplain_data[!, :latitude])
end

# Create matrices
fp_data = Matrix(transpose(Matrix(df_floodplain_data[:, [:longitude, :latitude]])))
seg_data = Matrix(transpose(Matrix(df_segment_data[:, [:longitude, :latitude]])))

println("done")


# This is not working for me
#=
df_floodplain_data = filter(:longitude => x -> !(x == "NA"), df_floodplain_data)
df_floodplain_data[!, :longitude] = parse.(Float64, df_floodplain_data[!, :longitude])
df_floodplain_data[!, :latitude] = parse.(Float64, df_floodplain_data[!, :latitude])
fp_data = Matrix(transpose(Matrix(df_floodplain_data[:, [:longitude, :latitude]])))
seg_data = Matrix(transpose(Matrix(df_segment_data[:, [:longitude, :latitude]])))
println("done")
=#

######################10,20,30% scenarios################################ If nothig ==> actual wetlands

# wetlands reduction 10%
#df_floodplain_data[:, :saltmarshes_area] = df_floodplain_data.saltmarshes_area .* 0.9
#df_floodplain_data[:, :tidalflats_area] = df_floodplain_data.tidalflats_area .* 0.9  
#df_floodplain_data[:, :mangroves_area] = df_floodplain_data.mangroves_area .* 0.9


# wetlands reduction 20%
#df_floodplain_data[:, :saltmarshes_area] = df_floodplain_data.saltmarshes_area .* 0.8
#df_floodplain_data[:, :tidalflats_area] = df_floodplain_data.tidalflats_area .* 0.8
#df_floodplain_data[:, :mangroves_area] = df_floodplain_data.mangroves_area .* 0.8


# wetlands reduction 30%
#df_floodplain_data[:, :saltmarshes_area] = df_floodplain_data.saltmarshes_area .* 0.7
#df_floodplain_data[:, :tidalflats_area] = df_floodplain_data.tidalflats_area .* 0.7
#df_floodplain_data[:, :mangroves_area] = df_floodplain_data.mangroves_area .* 0.7



function calculate_saltmarsh_width!(df)
    # Use broadcasting with dot operator for element-wise operations
    # Mask for when either value is zero
    mask = (df.saltmarshes_area .== 0) .| (df.coast_length .== 0)
    
    # Initialize saltmarshes_width column
    if !hasproperty(df, :saltmarshes_width)
        df.saltmarshes_width = zeros(nrow(df))
    end
    
    # Set width to 0 where either value is zero
    df[mask, :saltmarshes_width] .= 0
    
    # Calculate width only for cases where both values are non-zero
    df[.!mask, :saltmarshes_width] .= 
        df[.!mask, :saltmarshes_area] ./ df[.!mask, :coast_length]
    
    return df
end

function calculate_tidalflat_width!(df)

    mask = (df.tidalflats_area .== 0) .| (df.coast_length .== 0)

    if !hasproperty(df, :tidalflats_width)
        df.tidalflats_width = zeros(nrow(df))
    end
    
    df[mask, :tidalflats_width] .= 0
    
    df[.!mask, :tidalflats_width] .= 
        df[.!mask, :tidalflats_area] ./ df[.!mask, :coast_length]
    
    return df
end

function calculate_mangrove_width!(df)
 
    mask = (df.mangroves_area .== 0) .| (df.coast_length .== 0)
    
    if !hasproperty(df, :mangroves_width)
        df.mangroves_width = zeros(nrow(df))
    end
    
    df[mask, :mangroves_width] .= 0
    
    df[.!mask, :mangroves_width] .= 
        df[.!mask, :mangroves_area] ./ df[.!mask, :coast_length]
    
    return df
end

calculate_saltmarsh_width!(df_floodplain_data)
calculate_tidalflat_width!(df_floodplain_data)
calculate_mangrove_width!(df_floodplain_data)
first(df_floodplain_data, 5)

print("Attaching surge data ... ")
@info "reading surge data"
df_surges = DataFrame(CSV.File("$(ENV["DIVA_DATA"])/surges/COAST-RP/csv/COAST-RP.csv"))
    
# technicl stuff
surge_data = Matrix(transpose(Matrix(df_surges[:, [:lon, :lat]])))

# and do a sophisticated Nearest Neighbour matching
@info "build surge data NN matching tree"
surge_balltree = BallTree(surge_data, Haversine(6371.0))
@info "do surge data NN matching (floodplains)"
mapping_floodplains = knn(surge_balltree, fp_data, 1)
mapping_segments    = knn(surge_balltree, seg_data, 1)
    
# fit an GEV distribution
y_data_rp = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000]
y_data = map(x -> 1 - 1 / x, y_data_rp)

@info "fit surge distributions"
surge_dists = Dict{Int32,Distribution}()
for (i, row) in enumerate(eachrow(df_surges))
  x_data = [row.s0001, row.s0002, row.s0005, row.s0010, row.s0025, row.s0050, row.s0100, row.s0250, row.s0500, row.s1000]
  surge_dists[i] = estimate_gumbel_distribution(x_data, y_data)
  if surge_dists[i].µ < 0
    surge_dists[i] = estimate_gev_distribution(x_data, y_data)
    if surge_dists[i].µ < 0
      surge_dists[i] = GeneralizedExtremeValue(mean(x_data), var(x_data), 0)
    end
  end
end
println("done")

# construct gadm1 model(s)
mutable struct DECIPHERLocalData
  coast_length :: Float32
  lon :: Float32
  lat :: Float32
  type :: String
  area_below_01p0 :: Float32
  area_below_02p0 :: Float32
  area_below_10p0 :: Float32
  area_below_h100 :: Float32
  assets_below_01p0 :: Float32
  assets_below_02p0 :: Float32
  assets_below_10p0 :: Float32
  assets_below_h100 :: Float32
  expected_people_flooded :: Float32
  expected_annual_damages :: Float32
  local_gdpc :: Float32
  rslr           :: Float32
  population_below_01p0 :: Float32
  population_below_02p0 :: Float32
  population_below_10p0 :: Float32
  population_below_20p0 :: Float32
  population_below_h100 :: Float32
  protection_level_initial :: Float32
  protection_level :: Float32
  sea_dike_cost_investment :: Float32
  sea_dike_cost_investment_initial :: Float32
  sea_dike_cost_maintenance :: Float32
  sea_dike_heigth_initial :: Float32
  sea_dike_heigth :: Float32
  population_migration :: Float32
  migration_cost :: Float32
  land_loss :: Float32
  saltmarshes_width :: Float32
  tidalflats_width :: Float32
  mangroves_width :: Float32
  saltmarshes_area :: Float32
  tidalflats_area :: Float32
  mangroves_area :: Float32
  #avoided damages
  expected_annual_damages_attenuated :: Float32
  expected_people_flooded_attenuated :: Float32
  expected_people_flooded_avoided :: Float32
  expected_annual_damages_avoided :: Float32
end

mutable struct DECIPHERData
  area_below_01p0 :: Float32
  area_below_02p0 :: Float32
  area_below_10p0 :: Float32
  area_below_h100 :: Float32
  assets_below_01p0 :: Float32
  assets_below_02p0 :: Float32
  assets_below_10p0 :: Float32
  assets_below_h100 :: Float32
  coast_length :: Float32
  rslr           :: Float32
  population_below_01p0 :: Float32
  population_below_02p0 :: Float32
  population_below_10p0 :: Float32
  population_below_20p0 :: Float32
  population_below_h100 :: Float32
  expected_people_flooded :: Float32
  expected_annual_damages :: Float32
  length_protected :: Float32
  protection_level :: Float32
  sea_dike_cost_investment :: Float32
  sea_dike_cost_investment_initial :: Float32
  sea_dike_cost_maintenance :: Float32
  sea_dike_heigth :: Float32
  population_migration :: Float32
  migration_cost :: Float32
  land_loss :: Float32
  ## Wetlands
  #saltmarshes_width :: Float32
  #tidalflats_width :: Float32
  #mangroves_width :: Float32
  saltmarshes_area :: Float32
  tidalflats_area :: Float32
  mangroves_area :: Float32
  #avoided damages
  expected_annual_damages_attenuated :: Float32
  expected_people_flooded_attenuated :: Float32
  expected_people_flooded_avoided :: Float32
  expected_annual_damages_avoided :: Float32
end

DECIPHERLocalData() = DECIPHERLocalData(0.0,0.0,0.0,"",0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0)
DECIPHERData() = DECIPHERData(0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0)


print("Constructing level layers ... ")
@info "construct gadm1/nuts2 layer"
#collecting also the wetlands areas     
fp_gadm1 = Dict(df_floodplain_data.fpid .=> collect(zip(df_floodplain_data.id_gadm1,df_floodplain_data.longitude,df_floodplain_data.latitude,df_floodplain_data.coast_length,df_floodplain_data.saltmarshes_area, df_floodplain_data.tidalflats_area, df_floodplain_data.mangroves_area,df_floodplain_data.saltmarshes_width, df_floodplain_data.tidalflats_width, df_floodplain_data.mangroves_width))) 


###cls_gadm1 = Dict()   
cls_gadm1 = Dict(df_segment_data.clsid .=> collect(zip(df_segment_data.id_gadm1,df_segment_data.longitude,df_segment_data.latitude,df_segment_data.coast_length)))

fp_local_gdpc_df = DataFrame(CSV.File("C:/Users/sebas/DIVA/diva_projects/ACCREU/data/floodplain_localgdpc.csv"))
fp_local_gdpc = Dict(fp_local_gdpc_df.fpid .=> fp_local_gdpc_df.local_gdpc)

cls_local_gdpc_df = DataFrame(CSV.File("C:/Users/sebas/DIVA/diva_projects/ACCREU/data/segment_localgdpc.csv"))
cls_local_gdpc = Dict(cls_local_gdpc_df.clsid .=> cls_local_gdpc_df.local_gdpc)

gadm1_fp_model = Dict{Int32,ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}}()
for fpid in keys(hspfs_floodplains)
  if haskey(fp_gadm1, fpid)
    fpid_data = fp_gadm1[fpid]

    gadm1id = fpid_data[1]
    if !(haskey(gadm1_fp_model, gadm1id))
      ccm = ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}("FLOODPLAINS", gadm1id, DECIPHERData(), Dict{Int32,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}())
      gadm1_fp_model[gadm1id] = ccm
    end

    index = findfirst(==(fpid), df_floodplain_data.fpid)
    if (index !== nothing)
      gadm1_fp_model[gadm1id].children[fpid] = ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}("FLOODPLAIN", fpid, DECIPHERData(), Dict{Int32,LocalCoastalImpactModel}())
      gadm1_fp_model[gadm1id].children[fpid].children[fpid] = LocalCoastalImpactModel(fpid,surge_dists[mapping_floodplains[1][index][1]], hspfs_floodplains[fpid], 0.0, DECIPHERLocalData())
      gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.lon = fpid_data[2]
      gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.lat = fpid_data[3]
      gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.coast_length = fpid_data[4]
      gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.type = "FP"
      gadm1_fp_model[gadm1id].children[fpid].data.coast_length = fpid_data[4]
     #wetlands widths and areas
     gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.saltmarshes_area = fpid_data[5]
     gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.tidalflats_area = fpid_data[6]
     gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.mangroves_area = fpid_data[7]
     gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.saltmarshes_width = fpid_data[8]
     gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.tidalflats_width = fpid_data[9]
     gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.mangroves_width = fpid_data[10]
     #local GDP per capita
      gadm1_fp_model[gadm1id].children[fpid].children[fpid].data.local_gdpc = if haskey(fp_local_gdpc, fpid) fp_local_gdpc[fpid] else 0.0 end
    end
  end
end

gadm1_cls_model = Dict{Int32,ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}}()
for (clsid, clsid_data) in cls_gadm1
  gadm1id = clsid_data[1]
  if (haskey(hspfs_segments,clsid))
    if !(haskey(gadm1_cls_model, gadm1id))
      ccm = ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}("SEGMENTS", gadm1id, DECIPHERData(), Dict{Int32,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}())
      gadm1_cls_model[gadm1id] = ccm
    end

    index = findfirst(==(clsid), df_segment_data.clsid)
    if (index !== nothing)
      gadm1_cls_model[gadm1id].children[clsid] = ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}("SEGMENT", clsid, DECIPHERData(), Dict{Int32,LocalCoastalImpactModel}())
      gadm1_cls_model[gadm1id].children[clsid].children[clsid] = LocalCoastalImpactModel(clsid, surge_dists[mapping_segments[1][index][1]], hspfs_segments[clsid], 0.0, DECIPHERLocalData())
      gadm1_cls_model[gadm1id].children[clsid].children[clsid].data.lon = clsid_data[2]
      gadm1_cls_model[gadm1id].children[clsid].children[clsid].data.lat = clsid_data[3]
      gadm1_cls_model[gadm1id].children[clsid].children[clsid].data.coast_length = clsid_data[4]
      gadm1_cls_model[gadm1id].children[clsid].children[clsid].data.type = "CLS"
      gadm1_cls_model[gadm1id].children[clsid].data.coast_length = clsid_data[4]
      gadm1_cls_model[gadm1id].children[clsid].children[clsid].data.local_gdpc = if haskey(cls_local_gdpc, clsid) cls_local_gdpc[clsid] else 0.0 end
    end
  end
end


gadm1_model = Dict{Int32,ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}}()
#gadm1_model = Dict{Int32,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}()
for (gadm1id, gadm1_cls) in gadm1_cls_model
  ccm = ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}("GADM1", gadm1id, DECIPHERData(), Dict{Int32,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}())
  gadm1_model[gadm1id] = ccm
  merge!(gadm1_model[gadm1id].children, gadm1_cls.children)
end

for (gadm1id, gadm1_fp) in gadm1_fp_model
  if !(haskey(gadm1_model, gadm1id))
  ccm = ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}("GADM1", gadm1id, DECIPHERData(), Dict{Int32,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}())
    gadm1_model[gadm1id] = ccm
  end
  merge!(gadm1_model[gadm1id].children, gadm1_fp.children)
end

# construct country model

@info "construct country layer"

gadm1_country = Dict(df_floodplain_data.id_gadm1 .=> df_floodplain_data.countryid)
country_model = Dict{String,ComposedImpactModel{String,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}}}()
for (gadm1id, countryid) in gadm1_country

  if (haskey(gadm1_model,gadm1id)) 
    if !(haskey(country_model, countryid)) 
      ccm = ComposedImpactModel{String,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}}("COUNTRY", countryid, DECIPHERData(), Dict{Int32,ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}}())
      country_model[countryid] = ccm
    end
    country_model[countryid].children[gadm1id] = gadm1_model[gadm1id]
  end
end

#construct global model

@info "construct global layer"
global_model = ComposedImpactModel{String, String, DECIPHERData, ComposedImpactModel{String,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,ComposedImpactModel{Int32,Int32,DECIPHERData,LocalCoastalImpactModel}}}}("GLOBAL", "world", DECIPHERData(), country_model)

# coastlengths
@inline coastlength(lcm::LocalCoastalImpactModel) = lcm.data.coast_length

@inline function constlength_store(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.coast_length = res
end

@info "compute coastlengths"
apply_accumulate_store(global_model, coastlength, +, constlength_store)
println("done")

##accumulate wetland areas

@inline saltmarsh_area(lcm::LocalCoastalImpactModel) = lcm.data.saltmarshes_area
@inline tidalflat_area(lcm::LocalCoastalImpactModel) = lcm.data.tidalflats_area
@inline mangrove_area(lcm::LocalCoastalImpactModel) = lcm.data.mangroves_area

#storing the results
@inline function saltmarsh_store(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.saltmarshes_area = res
end

@inline function tidalflat_store(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.tidalflats_area = res
end

@inline function mangrove_store(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.mangroves_area = res
end

#@info "compute wetland areas"
apply_accumulate_store(global_model, saltmarsh_area, +, saltmarsh_store)
apply_accumulate_store(global_model, tidalflat_area, +, tidalflat_store)
apply_accumulate_store(global_model, mangrove_area, +, mangrove_store)
println("done")

println("Total areas computed and stored successfully")

########## Assessment fuctions ###################
## exposure
my_exposure(e::Real) = function (lcm::LocalCoastalImpactModel)
  return exposure(lcm, e + lcm.data.rslr)
end

my_exposure_below_h(rp::Real) = function (lcm::LocalCoastalImpactModel)
  return exposure(lcm, quantile(lcm.surge_model,1-(1/rp)))
end

function my_exposure_store_1p0(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.area_below_01p0 = res[1]
  model.data.population_below_01p0 = res[2][1]
  model.data.assets_below_01p0 = res[2][2]/1000000
end

function my_exposure_store_2p0(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.area_below_02p0 = res[1]
  model.data.population_below_02p0 = res[2][1]
  model.data.assets_below_02p0 = res[2][2]/1000000
end

function my_exposure_store_10p0(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.area_below_10p0 = res[1]
  model.data.population_below_10p0 = res[2][1]
  model.data.assets_below_10p0 = res[2][2]/1000000
end

function my_exposure_store_20p0(res, model::CIU) where {CIU<:CoastalImpactUnit}
#  model.data.area_below_20p0 = res[1]
  model.data.population_below_20p0 = res[2][1]
#  model.data.assets_below_20p0 = res[2][2]/1000000
end

function my_exposure_store_h100(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.area_below_h100 = res[1]
  model.data.population_below_h100 = res[2][1]
  model.data.assets_below_h100 = res[2][2]/1000000
end

function compute_exposure(global_model)
  apply_accumulate_store_multithread(global_model, my_exposure(1.0f0), .+, my_exposure_store_1p0, "GADM1")
  apply_accumulate_store_multithread(global_model, my_exposure(2.0f0), .+, my_exposure_store_2p0, "GADM1")
  apply_accumulate_store_multithread(global_model, my_exposure(10.0f0), .+, my_exposure_store_10p0, "GADM1")
  apply_accumulate_store_multithread(global_model, my_exposure(20.0f0), .+, my_exposure_store_20p0, "GADM1")
  apply_accumulate_store_multithread(global_model, my_exposure_below_h(100.0), .+, my_exposure_store_h100, "GADM1")
end


## damages 
my_expected_damage_bathtub = function (lcm::LocalCoastalImpactModel)
    
  local_exposure = exposure(lcm, quantile(lcm.surge_model,0.99))

  if (local_exposure[2][1]<1)
    return (0.0f0, [0.0f0, 0.0f0])
  else
    return expected_damage_bathtub_standard_ddf(lcm, 0.0f0, [0.0f0, 1.0f0])
  end
end

function my_expected_damage_bathtub_store(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.expected_people_flooded = res[2][1]
  model.data.expected_annual_damages = res[2][2]/1000000
end

function compute_damages(global_model)
  apply_accumulate_store_multithread(global_model, my_expected_damage_bathtub, .+, my_expected_damage_bathtub_store, "GADM1")
end


# attenuated damages  (max(0.0, lcm_attenuated.surge_model.µ .- attenuation_heigth))
my_expected_damage_bathtub_attenuated = function (lcm::LocalCoastalImpactModel)

  lcm_attenuated = deepcopy(lcm)

  attenuation_heigth = ((lcm_attenuated.data.saltmarshes_width .* saltmarshes_attenuation) .+ (lcm_attenuated.data.tidalflats_width .* tidalflats_attenuation) .+ (lcm_attenuated.data.mangroves_width .* mangroves_attenuation))
  attenuated_mu = max(0.0f0, lcm_attenuated.surge_model.µ .- attenuation_heigth)
  simga = lcm_attenuated.surge_model.σ
  xi = lcm_attenuated.surge_model.ξ

  lcm_attenuated.surge_model = GeneralizedExtremeValue(attenuated_mu, simga, xi)

  #lcm_attenuated.surge_model = GeneralizedExtremeValue((lcm_attenuated.surge_model.µ .- attenuation_heigth), lcm_attenuated.surge_model.σ, lcm_attenuated.surge_model.ξ)
  
  # Keep the same protection level as the original model
  #lcm_attenuated.protection_level = lcm.protection_level

  local_exposure_attenuated = exposure(lcm_attenuated, quantile(lcm_attenuated.surge_model, 0.99))
  if (local_exposure_attenuated[2][1]<1)
    return (0.0f0, [0.0f0, 0.0f0])
  else
      return expected_damage_bathtub_standard_ddf(lcm_attenuated, 0.0f0, [0.0f0, 1.0f0])
  end
end

function my_expected_damage_bathtub_store_attenuated(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.expected_people_flooded_attenuated = res[2][1]
  model.data.expected_annual_damages_attenuated = res[2][2]/1000000
end

function attenuated_damages(global_model)
  apply_accumulate_store_multithread(global_model, my_expected_damage_bathtub_attenuated, .+, my_expected_damage_bathtub_store_attenuated, "GADM1")
end


## avoided_damages
function my_expected_damage_avoided(lcm::LocalCoastalImpactModel)
  # Get regular and attenuated damage values
  regular_damage = my_expected_damage_bathtub(lcm)
  attenuated_damage = my_expected_damage_bathtub_attenuated(lcm)

  # Calculate difference in scalar
  diff_float = regular_damage[1] - attenuated_damage[1]

  # Calculate difference in array
  if length(regular_damage[2]) == 0 || length(attenuated_damage[2]) == 0
      diff_array = Array{Float32}(undef, 0)
  else
      diff_array = regular_damage[2] - attenuated_damage[2]
  end

  return (diff_float, diff_array)
end

#=
function my_expected_damage_avoided(lcm::LocalCoastalImpactModel)
  # Get regular damage values
  regular_damage = my_expected_damage_bathtub(lcm)
  
  # Get attenuated damage values
  attenuated_damage = my_expected_damage_bathtub_attenuated(lcm)
  
  # Calculate differences while maintaining the same structure
  # For the first float value
  diff_float = regular_damage[1] - attenuated_damage[1]
  
  # For the array (if it exists)
  if length(regular_damage[2]) == 0 || length(attenuated_damage[2]) == 0
      diff_array = Array{Float32}(undef, 0)
  else
      diff_array = regular_damage[2] - attenuated_damage[2]
  end
  
  # For the final vector of two values [people_flooded, annual_damages]
  diff_vector = regular_damage[3] - attenuated_damage[3]
  
  return (diff_float, diff_array, diff_vector)
end
=#


#Store the avoided damages results in the model data structure
function my_expected_damage_avoided_store(res, model::CIU) where {CIU<:CoastalImpactUnit}
  model.data.expected_people_flooded_avoided = res[2][1]
  model.data.expected_annual_damages_avoided = res[2][2]/1000000
end

#Calculate and store the avoided damages (difference between regular and attenuated damages)
function avoided_damages(global_model)
    apply_accumulate_store_multithread(global_model, my_expected_damage_avoided, .+, my_expected_damage_avoided_store, "GADM1")
end

## Socio-economic development
function adjust_initial_population(pops::Dict, sw_pop::SSPScenarioReader{T1}, year1::Int, year2::Int) where {T1<:SSPType}
  for c in keys(pops) 
    if (c != "XXZ")
      pop_gf = ssp_get_growth_factor(sw_pop, "Population", String(c), "SSP2", year1, year2)
      pops[c] = pops[c] * pop_gf
    end
  end
end

#
#  Protection levels
#

# inital protection levels - the table rule
@inline my_initial_protection_table(dike_unitcost :: Tuple{Float64, Float64}) = function (lcm::LocalCoastalImpactModel)
  local_exposure = exposure(lcm, quantile(lcm.surge_model,0.99))
  local_popdens = if (local_exposure[1]>0) local_exposure[2][1]/local_exposure[1] else 0.0 end

#  println("Hello! I'm ", lcm.id, ". My popdens is ",local_popdens," and my local gdpc is ",lcm.data.local_gdpc)

  if local_popdens<=30 
    lcm.protection_level = 0
  elseif local_popdens<=1500
    if lcm.data.local_gdpc<lower_middle_income
      lcm.protection_level = 0
    elseif lcm.data.local_gdpc<upper_middle_income
      lcm.protection_level = 20
    else
      lcm.protection_level = 50
    end
  else
    if lcm.data.local_gdpc<low_income
      lcm.protection_level = 10
    elseif lcm.data.local_gdpc<lower_middle_income
      lcm.protection_level = 25
    elseif lcm.data.local_gdpc<upper_middle_income
      lcm.protection_level = 100
    else
      lcm.protection_level = 200
    end
  end 

  if lcm.protection_level > 0
    lcm.data.sea_dike_heigth=quantile(lcm.surge_model,1-1/lcm.protection_level)
#=    
    if lcm.data.sea_dike_heigth<0
      println("Hello! I'm ", lcm.id, ". My type is ", lcm.data.type, ". My lcm.protection_level is ",lcm.protection_level," GEV is ",lcm.surge_model,". Thus, my sea_dike_heigth is ",lcm.data.sea_dike_heigth)
    end 
=#
  end

  lcm.data.sea_dike_cost_investment = lcm.data.sea_dike_heigth * lcm.data.coast_length * dike_unitcost[1]
  lcm.data.sea_dike_cost_maintenance = lcm.data.sea_dike_cost_investment * 0.01
end

@inline
function initial_protection_store(lcm::LocalCoastalImpactModel)
  lcm.data.protection_level = lcm.protection_level
  lcm.data.protection_level_initial = lcm.data.protection_level
  lcm.data.sea_dike_heigth_initial = lcm.data.sea_dike_heigth
  lcm.data.sea_dike_cost_investment_initial = lcm.data.sea_dike_cost_investment
end

function initial_protection_store(ccm::CIU) where {CIU<:CoastalImpactUnit}
  adaptation_store(ccm)
  ccm.data.sea_dike_cost_investment_initial = ccm.data.sea_dike_cost_investment
end

my_initial_protection(dike_unitcost :: Dict) = function(ccm::ComposedImpactModel{IT1,IT2,DATA,CM}) where {IT1,IT2,DATA,CM}
  if (ccm.level == "COUNTRY")
    country_dike_unitcost = 
    if haskey(dike_unitcost, ccm.id)
      dike_unitcost[ccm.id]
    else
      @warn "no seadike unit cost found for $(ccm.id)"
      reduce(.+,collect(values(dike_cost))) ./ size(collect(values(dike_cost)),1)
    end
      apply_store_multithread(ccm, my_initial_protection_table(country_dike_unitcost), initial_protection_store, "GADM1")
    return true
  else
    return false
  end
end

function initial_protection(global_model, dike_unitcost :: Dict)
  apply_break_store(global_model, my_initial_protection(dike_unitcost), initial_protection_store)
end

@inline
function adaptation_store(lcm::LocalCoastalImpactModel)
lcm.data.protection_level = lcm.protection_level
end

function adaptation_store(ccm::CIU) where {CIU<:CoastalImpactUnit}
  pl_sum = 0.0
  dh_sum = 0.0
  protected_length = 0.0
  ccm.data.sea_dike_cost_investment = 0.0
  ccm.data.sea_dike_cost_maintenance = 0.0
  ccm.data.protection_level = 0
  ccm.data.sea_dike_heigth  = 0
  ccm.data.length_protected = 0
  ccm.data.population_migration = 0
  ccm.data.migration_cost = 0
  ccm.data.land_loss = 0

  for (id, child) in ccm.children
      if (ccm.level=="SEGMENT") || (ccm.level=="FLOODPLAIN")
        pl_sum += child.data.protection_level * child.data.coast_length
        dh_sum += child.data.sea_dike_heigth * child.data.coast_length
        if (child.data.protection_level > 0)
          protected_length += child.data.coast_length
        end
      else
        pl_sum += child.data.protection_level * child.data.length_protected
        dh_sum += child.data.sea_dike_heigth * child.data.length_protected
        protected_length += child.data.length_protected
      end
      ccm.data.sea_dike_cost_investment += child.data.sea_dike_cost_investment
      ccm.data.sea_dike_cost_maintenance += child.data.sea_dike_cost_maintenance
      ccm.data.population_migration += child.data.population_migration
      ccm.data.land_loss += child.data.land_loss
      ccm.data.migration_cost += child.data.migration_cost
  end
  if (protected_length > 0)
    ccm.data.protection_level = pl_sum / protected_length
    ccm.data.sea_dike_heigth  = dh_sum / protected_length
    ccm.data.length_protected = protected_length
  end
end

adjust_initial_population(country_pop, population_scenario, 2010, 2015)

output = Dict{String,DataFrame}("GLOBAL" => DataFrame(), "COUNTRY" => DataFrame())
#output = Dict{String,DataFrame}("GLOBAL" => DataFrame(), "COUNTRY" => DataFrame(), "GADM1" => DataFrame(), "FLOODPLAIN" => DataFrame())
#output = Dict{String,DataFrame}("GLOBAL" => DataFrame(), "COUNTRY" => DataFrame(), "GADM1" => DataFrame())

# empty Dictionary for vertical land movement - we do not include any (in the moment)
#vlm = Dict()

country_data = (CSV.read("$(ENV["DIVA_DATA"])/databases/country_seadike_unitcost_USD2011.csv", DataFrame))
dike_cost = Dict(country_data.locationid .=> collect(zip(country_data.seadike_unit_cost_rural,  country_data.seadike_unit_cost_urban)))

local_compress(mtlock) = function(lcm::LocalCoastalImpactModel)
  compress_multithread!(lcm.coastal_plain_model,mtlock)
end

@info "compress data"
mtlock = ReentrantLock()
apply_multithread(global_model, local_compress(mtlock), "GADM1")

run_number = 0

#global run_number += 1

global run_number += 1

@info "copy of the global model for the run"
global_model_for_run = deepcopy(global_model)

#run of avoided damage scenarios in case of NO initial protection 
for times in partition([2015, 2015], 2, 1)

  time = times[2]
  prev_time = times[1]
  #@info "timestep: $time"
  println("timestep: $time")
  #initial_protection(global_model_for_run, dike_cost)
  compute_exposure(global_model_for_run)
  compute_damages(global_model_for_run)
  attenuated_damages(global_model_for_run)
  avoided_damages(global_model_for_run)
  collect_data(global_model_for_run, output, [time, "NA", "NA", "NA", "NA"], ["locationid", "time", "ssp", "rcp", "quant", "adaptation"])
  standardize_output!(output, [:locationid, :ssp, :rcp, :quant, :adaptation, :time])
  for (level, data) in output
    
#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_high_actual" * level * ".csv", data)
#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_medium_actual" * level * ".csv", data)
#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_low_actual" * level * ".csv", data)


#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_high_10" * level * ".csv", data)
#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_medium_10" * level * ".csv", data)
#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_low_10" * level * ".csv", data)

#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_high_20" * level * ".csv", data)
#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_medium_20" * level * ".csv", data)
#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_low_20" * level * ".csv", data)

#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_high_30" * level * ".csv", data)
#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_medium_30" * level * ".csv", data)
#CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/no_protection/avoided_damages_low_30" * level * ".csv", data)    


   empty!(data)
  end
end
#@info "finished computations"



###################################################################################
#=
#run of avoided damage scenarios in case of initial protection (seadikes)
for times in partition([2015, 2015], 2, 1)

    time = times[2]
    prev_time = times[1]
    #@info "timestep: $time"
    println("timestep: $time")
    initial_protection(global_model_for_run, dike_cost)
    compute_exposure(global_model_for_run)
    compute_damages(global_model_for_run)
    attenuated_damages(global_model_for_run)
    avoided_damages(global_model_for_run)
    collect_data(global_model_for_run, output, [time, "NA", "NA", "NA", "NA"], ["locationid", "time", "ssp", "rcp", "quant", "adaptation"])
    standardize_output!(output, [:locationid, :ssp, :rcp, :quant, :adaptation, :time])
    for (level, data) in output
     CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_high_actual" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_medium_actual" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_low_actual" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_high_10" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_medium_10" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_low_10" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_high_20" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_medium_20" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_low_20" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_high_30" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_medium_30" * level * ".csv", data)
     #CSV.write("$(ENV["DIVA_DATA"])/dataset_global/outputs/paper_wetlands_value/initial_protection/avoided_damages_low_30" * level * ".csv", data)

     empty!(data)
    end
end
#@info "finished computations"
=#


