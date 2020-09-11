
const _ComponentLabelReferences = Set{Tuple{UUIDs.UUID, String}}

struct _TimeSeriesRecord
    component_labels::_ComponentLabelReferences
    ta::TimeArrayWrapper
end

function _TimeSeriesRecord(component_uuid, label, ta)
    record = _TimeSeriesRecord(_ComponentLabelReferences(), ta)
    push!(record.component_labels, (component_uuid, label))
    return record
end

"""
Stores all time series data in memory.
"""
struct InMemoryTimeSeriesStorage <: TimeSeriesStorage
    data::Dict{UUIDs.UUID, _TimeSeriesRecord}
end

function InMemoryTimeSeriesStorage()
    storage = InMemoryTimeSeriesStorage(Dict{UUIDs.UUID, _TimeSeriesRecord}())
    @info "Created InMemoryTimeSeriesStorage"
    return storage
end

"""
Constructs InMemoryTimeSeriesStorage from an instance of Hdf5TimeSeriesStorage.
"""
function InMemoryTimeSeriesStorage(hdf5_storage::Hdf5TimeSeriesStorage)
    storage = InMemoryTimeSeriesStorage()
    for (component, label, time_series) in iterate_time_series(hdf5_storage)
        add_time_series!(storage, component, label, time_series)
    end

    return storage
end

check_read_only(storage::InMemoryTimeSeriesStorage) = nothing

function add_time_series!(
    storage::InMemoryTimeSeriesStorage,
    component_uuid::UUIDs.UUID,
    label::AbstractString,
    ta::TimeArrayWrapper,
    unused = nothing,
)
    uuid = get_uuid(ta)
    if !haskey(storage.data, uuid)
        @debug "Create new time series entry." uuid component_uuid label
        storage.data[uuid] = _TimeSeriesRecord(component_uuid, label, ta)
    else
        add_time_series_reference!(storage, component_uuid, label, uuid)
    end
end

function add_time_series_reference!(
    storage::InMemoryTimeSeriesStorage,
    component_uuid::UUIDs.UUID,
    label::AbstractString,
    ts_uuid::UUIDs.UUID,
)
    @debug "Add reference to existing time series entry." ts_uuid component_uuid label
    record = storage.data[ts_uuid]
    push!(record.component_labels, (component_uuid, label))
end

function remove_time_series!(
    storage::InMemoryTimeSeriesStorage,
    uuid::UUIDs.UUID,
    component_uuid::UUIDs.UUID,
    label::AbstractString,
)
    if !haskey(storage.data, uuid)
        throw(ArgumentError("$uuid is not stored"))
    end

    record = storage.data[uuid]
    component_label = (component_uuid, label)
    if !(component_label in record.component_labels)
        throw(ArgumentError("$component_label wasn't stored for $uuid"))
    end

    pop!(record.component_labels, component_label)
    @debug "Removed $component_label from $uuid."

    if isempty(record.component_labels)
        @debug "$uuid has no more references; delete it."
        pop!(storage.data, uuid)
    end
end

function get_time_series(
    storage::InMemoryTimeSeriesStorage,
    uuid::UUIDs.UUID;
    index = 0,
    len = 0,
)::TimeSeries.TimeArray
    if !haskey(storage.data, uuid)
        throw(ArgumentError("$uuid is not stored"))
    end

    if index != 0
        @assert len != 0
        end_index = index + len - 1
        return storage.data[uuid].ta.data[index:end_index]
    end

    return storage.data[uuid].ta.data
end

function clear_time_series!(storage::InMemoryTimeSeriesStorage)
    empty!(storage.data)
    @info "Cleared all time series."
end

function get_num_time_series(storage::InMemoryTimeSeriesStorage)
    return length(storage.data)
end

function convert_to_hdf5(storage::InMemoryTimeSeriesStorage, filename::AbstractString)
    create_file = true
    hdf5_storage = Hdf5TimeSeriesStorage(create_file; filename = filename)
    for record in values(storage.data)
        for pair in record.component_labels
            columns = TimeSeries.colnames(record.ta.data)
            add_time_series!(hdf5_storage, pair[1], pair[2], record.ta, columns)
        end
    end
end

function compare_values(x::InMemoryTimeSeriesStorage, y::InMemoryTimeSeriesStorage)::Bool
    keys_x = sort!(collect(keys(x.data)))
    keys_y = sort!(collect(keys(y.data)))
    if keys_x != keys_y
        @error "keys don't match" keys_x keys_y
        return false
    end

    for key in keys_x
        record_x = x.data[key]
        record_y = y.data[key]
        if record_x.component_labels != record_y.component_labels
            @error "component_labels don't match" record_x.component_labels record_y.component_labels
            return false
        end
        if TimeSeries.timestamp(record_x.ta.data) != TimeSeries.timestamp(record_y.ta.data)
            @error "timestamps don't match" record_x record_y
            return false
        end
        if TimeSeries.values(record_x.ta.data) != TimeSeries.values(record_y.ta.data)
            @error "values don't match" record_x record_y
            return false
        end
    end

    return true
end
