
import JSON
import YAML

struct ValidationInfo
    field_descriptor::Dict
    struct_name::AbstractString
    ist_struct::InfrastructureSystemsType
    field_type::Any
    limits::Union{NamedTuple{(:min, :max)}, NamedTuple{(:min, :max, :zero)}}
end

function read_validation_descriptor(filename::AbstractString)
    if occursin(r"(\.yaml)|(\.yml)"i, filename)
        data = open(filename) do file
            YAML.load(file)
        end
    elseif occursin(r"(\.json)"i, filename)
        data = open(filename) do file
            # JSON2.read produces NamedTuples recursively. We want dicts. Use JSON instead.
            JSON.parse(file)
        end
    else
        error("Filename is not a YAML or JSON file.")
    end

    if !isa(data, Array)
        throw(DataFormatError("{filename} has invalid format"))
    end

    return data
end

# Get validation info for one struct.
function get_config_descriptor(config::Vector, name::AbstractString)
    for item in config
        if item["struct_name"] == name
            return item
        end
    end

    @warn("struct $name does not exist in validation configuration file, validation skipped")
    return nothing
end

# Get validation info for one field of one struct.
function get_field_descriptor(struct_descriptor::Dict, fieldname::AbstractString)
    for field in struct_descriptor["fields"]
        if field["name"] == fieldname
            return field
        end
    end

    throw(DataFormatError("field $fieldname does not exist in $(struct_descriptor["struct_name"]) validation config"))
end

function validate_fields(
    components::Components,
    ist_struct::T,
) where {T <: InfrastructureSystemsType}
    type_name = strip_parametric_type(strip_module_name(repr(T)))
    struct_descriptor = get_config_descriptor(components.validation_descriptors, type_name)
    isnothing(struct_descriptor) && return true
    is_valid = true

    for (field_name, fieldtype) in zip(fieldnames(T), fieldtypes(T))
        field_value = getfield(ist_struct, field_name)
        if isnothing(field_value)  # Many structs are of type Union{Nothing, xxx}.

        elseif fieldtype <: Union{Nothing, InfrastructureSystemsType} &&
               !(fieldtype <: InfrastructureSystemsType)
            # Recurse. Components are validated separately and do not need to
            # be validated twice.
            if !validate_fields(components, getfield(ist_struct, field_name))
                is_valid = false
            end
        else
            field_descriptor = get_field_descriptor(struct_descriptor, string(field_name))
            if !haskey(field_descriptor, "valid_range")
                continue
            end
            valid_range = field_descriptor["valid_range"]
            limits = get_limits(valid_range, ist_struct)
            valid_info = ValidationInfo(
                field_descriptor,
                struct_descriptor["struct_name"],
                ist_struct,
                fieldtype,
                limits,
            )
            if !validate_range(valid_range, valid_info, field_value)
                is_valid = false
            end
        end
    end
    return is_valid
end

function get_limits(valid_range::String, ist_struct::InfrastructureSystemsType)
    # Gets min and max values from activepowerlimits for activepower, etc.
    function recur(d, a, i = 1)
        if i <= length(a)
            d = getfield(d, Symbol(a[i]))
            recur(d, a, i + 1)
        else
            return d
        end
    end

    valid_range, ist_struct
    vr = recur(ist_struct, split(valid_range, "."))

    if isnothing(vr)
        limits = (min = nothing, max = nothing)
    else
        limits = get_limits(vr, ist_struct)
    end

    return limits
end

function get_limits(valid_range::Dict, unused::InfrastructureSystemsType)
    # Gets min and max value defined for a field,
    # e.g. "valid_range": {"min":-1.571, "max":1.571}.
    return (min = valid_range["min"], max = valid_range["max"])
end

function get_limits(
    valid_range::Union{NamedTuple{(:min, :max)}, NamedTuple{(:max, :min)}},
    unused::InfrastructureSystemsType,
)
    # Gets min and max value defined for a field,
    # e.g. "valid_range": {"min":-1.571, "max":1.571}.
    return (min = valid_range.min, max = valid_range.max)
end

function validate_range(::String, valid_info::ValidationInfo, field_value)
    # Validates activepower against activepowerlimits, etc.
    is_valid = true
    if !isnothing(valid_info.limits)
        is_valid = check_limits_impl(valid_info, field_value)
    end

    return is_valid
end

function validate_range(
    ::Union{
        Dict,
        NamedTuple{(:min, :max)},
        NamedTuple{(:max, :min)},
        NamedTuple{(:min, :max, :zero)},
    },
    valid_info::ValidationInfo,
    field_value,
)
    return check_limits(valid_info.field_type, valid_info, field_value)
end

function check_limits(
    ::Type{T},
    valid_info::ValidationInfo,
    field_value,
) where {T <: Union{Nothing, Float64}}
    # Validates numbers.
    return check_limits_impl(valid_info, field_value)
end

function check_limits(
    ::Type{T},
    valid_info::ValidationInfo,
    field_value,
) where {T <: Union{Nothing, NamedTuple}}
    # Validates up/down, min/max, from/to named tuples.
    @assert length(field_value) == 2
    result1 = check_limits_impl(valid_info, field_value[1])
    result2 = check_limits_impl(valid_info, field_value[2])
    return result1 && result2
end

function check_limits_impl(valid_info::ValidationInfo, field_value::Real)
    is_valid = true
    action_function = get_validation_action(valid_info.field_descriptor)
    if (
        (!isnothing(valid_info.limits.min) && field_value < valid_info.limits.min) ||
        (!isnothing(valid_info.limits.max) && field_value > valid_info.limits.max)
    ) && !(haskey(valid_info.limits, :zero) && field_value == 0.0)

        is_valid = action_function(valid_info, field_value)
    end
    return is_valid
end

function get_validation_action(field_descriptor::Dict)
    action = get(field_descriptor, "validation_action", "error")
    if action == "warn"
        action_function = validation_warning
    elseif action == "error"
        action_function = validation_error
    else
        error("Invalid validation action $action")
    end
    return action_function
end

function validation_warning(valid_info::ValidationInfo, field_value)
    valid_range = valid_info.field_descriptor["valid_range"]
    field_name = valid_info.field_descriptor["name"]
    @warn "Invalid range" valid_info.struct_name field_name field_value valid_range valid_info.ist_struct
    return true
end

function validation_error(valid_info::ValidationInfo, field_value)
    valid_range = valid_info.field_descriptor["valid_range"]
    field_name = valid_info.field_descriptor["name"]
    @error "Invalid range" valid_info.struct_name field_name field_value valid_range valid_info.ist_struct
    return false
end

"""
    validate_components(components::Components)

Iterates over all components and throws InvalidRange if any of the component's field values
are outside of defined valid range.
"""
function validate_components(components::Components)
    error_detected = false
    for component in iterate_components(components)
        if validate_fields(components, component)
            error_detected = true
        end
    end

    if error_detected
        throw(InvalidRange("Invalid range detected"))
    end
end

"""
Validates a struct.
"""
function validate_struct(ist::InfrastructureSystemsType)
    return true
end