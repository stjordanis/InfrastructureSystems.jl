const _TS_DATA_TO_METADATA_MAP = Dict(
    Deterministic => DeterministicMetadata,
    DeterministicSingleTimeSeries => DeterministicMetadata,
    AbstractDeterministic => DeterministicMetadata,
    Probabilistic => ProbabilisticMetadata,
    Scenarios => ScenariosMetadata,
    SingleTimeSeries => SingleTimeSeriesMetadata,
)

const _TS_METADATA_TO_DATA_MAP = Dict(
    DeterministicMetadata => Deterministic,
    # DeterministicSingleTimeSeries is not necessary. deserialize_time_series will do the
    # right thing if that type is stored.
    ProbabilisticMetadata => Probabilistic,
    ScenariosMetadata => Scenarios,
    SingleTimeSeriesMetadata => SingleTimeSeries,
)

function time_series_data_to_metadata(::Type{T}) where {T <: TimeSeriesData}
    return _TS_DATA_TO_METADATA_MAP[T]
end

function time_series_metadata_to_data(::Type{T}) where {T <: TimeSeriesMetadata}
    return _TS_METADATA_TO_DATA_MAP[T]
end
