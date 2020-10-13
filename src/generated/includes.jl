include("DeterministicMetadata.jl")
include("Deterministic.jl")
include("ProbabilisticMetadata.jl")
include("Probabilistic.jl")
include("ScenariosMetadata.jl")
include("Scenarios.jl")
include("SingleTimeSeriesMetadata.jl")
include("SingleTimeSeries.jl")
include("DeterministicSingleTimeSeries.jl")

export get_count
export get_data
export get_horizon
export get_initial_timestamp
export get_interval
export get_length
export get_name
export get_percentiles
export get_resolution
export get_scaling_factor_multiplier
export get_scenario_count
export get_single_time_series
export get_time_series_uuid
export set_count!
export set_data!
export set_horizon!
export set_initial_timestamp!
export set_interval!
export set_length!
export set_name!
export set_percentiles!
export set_resolution!
export set_scaling_factor_multiplier!
export set_scenario_count!
export set_single_time_series!
export set_time_series_uuid!
