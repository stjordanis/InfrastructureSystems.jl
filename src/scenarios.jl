"""
Construct Scenarios from a SortedDict of Arrays.

# Arguments
- `name::AbstractString`: user-defined name
- `input_data::AbstractDict{Dates.DateTime, Matrix{Float64}}`: time series data.
- `resolution::Dates.Period`: The resolution of the forecast in Dates.Period`
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
"""
function Scenarios(
    name::AbstractString,
    input_data::AbstractDict,
    resolution::Dates.Period;
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    scenario_count = size(first(values(input_data)))[2]
    data = handle_normalization_factor(convert_data(input_data), normalization_factor)

    return Scenarios(name, resolution, scenario_count, data, scaling_factor_multiplier)
end

"""
Construct Scenarios from a Dict of TimeArrays.

# Arguments
- `name::AbstractString`: user-defined name
- `input_data::AbstractDict{Dates.DateTime, TimeSeries.TimeArray}`: time series data.
- `normalization_factor::NormalizationFactor = 1.0`: optional normalization factor to apply
  to each data entry
- `scaling_factor_multiplier::Union{Nothing, Function} = nothing`: If the data are scaling
  factors then this function will be called on the component and applied to the data when
  [`get_time_series_array`](@ref) is called.
- `timestamp = :timestamp`: If the values are DataFrames is passed then this must be the column name that
  contains timestamps.
"""
function Scenarios(
    name::AbstractString,
    input_data::AbstractDict{Dates.DateTime, <:TimeSeries.TimeArray};
    normalization_factor::NormalizationFactor = 1.0,
    scaling_factor_multiplier::Union{Nothing, Function} = nothing,
)
    data = SortedDict{Dates.DateTime, Matrix{Float64}}()
    resolution =
        TimeSeries.timestamp(first(values(input_data)))[2] -
        TimeSeries.timestamp(first(values(input_data)))[1]
    for (k, v) in input_data
        data[k] = TimeSeries.values(v)
    end

    return Scenarios(
        name,
        data,
        resolution;
        normalization_factor = normalization_factor,
        scaling_factor_multiplier = scaling_factor_multiplier,
    )
end

function Scenarios(ts_metadata::ScenariosMetadata, data::SortedDict)
    return Scenarios(
        name = get_name(ts_metadata),
        scenario_count = get_scenario_count(ts_metadata),
        resolution = get_resolution(ts_metadata),
        data = data,
        scaling_factor_multiplier = get_scaling_factor_multiplier(ts_metadata),
        internal = InfrastructureSystemsInternal(get_time_series_uuid(ts_metadata)),
    )
end

function Scenarios(info::TimeSeriesParsedInfo)
    return Scenarios(
        info.name,
        info.data,
        info.resolution;
        normalization_factor = info.normalization_factor,
        scaling_factor_multiplier = info.scaling_factor_multiplier,
    )
end

function ScenariosMetadata(time_series::Scenarios)
    return ScenariosMetadata(
        get_name(time_series),
        get_resolution(time_series),
        get_initial_timestamp(time_series),
        get_interval(time_series),
        get_scenario_count(time_series),
        get_count(time_series),
        get_uuid(time_series),
        get_horizon(time_series),
        get_scaling_factor_multiplier(time_series),
    )
end

function get_array_for_hdf(forecast::Scenarios)
    interval_count = get_count(forecast)
    scenario_count = get_scenario_count(forecast)
    horizon = get_horizon(forecast)
    data = get_data(forecast)

    data_for_hdf = Array{Float64, 3}(undef, scenario_count, horizon, interval_count)
    for (ix, f) in enumerate(values(data))
        data_for_hdf[:, :, ix] = transpose(f)
    end
    return data_for_hdf
end

function get_horizon(forecast::Scenarios)
    return size(first(values(get_data(forecast))))[1]
end

eltype_data(forecast::Scenarios) = eltype_data_common(forecast)
get_count(forecast::Scenarios) = get_count_common(forecast)
get_initial_times(forecast::Scenarios) = get_initial_times_common(forecast)
get_initial_timestamp(forecast::Scenarios) = get_initial_timestamp_common(forecast)
get_interval(forecast::Scenarios) = get_interval_common(forecast)
get_window(f::Scenarios, initial_time; len = nothing) =
    get_window_common(f, initial_time; len = len)
iterate_windows(forecast::Scenarios) = iterate_windows_common(forecast)
