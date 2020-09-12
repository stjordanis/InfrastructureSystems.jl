@testset "Test read_time_series_file_metadata" begin
    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    time_series = IS.read_time_series_file_metadata(file)
    @test length(time_series) == 1

    for time_series in time_series
        @test isfile(time_series.data_file)
    end
end

@testset "Test add_time_series from file" begin
    data = IS.SystemData()

    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(data, component)
    @test !IS.has_time_series(component)

    file = joinpath(FORECASTS_DIR, "ComponentsAsColumnsNoTime.json")
    IS.add_time_series!(IS.InfrastructureSystemsComponent, data, file)
    @test IS.has_time_series(component)

    all_time_series = get_all_time_series(data)
    @test length(all_time_series) == 1
    time_series = all_time_series[1]
    @test time_series isa IS.Deterministic

    time_series2 = IS.get_time_series(
        typeof(time_series),
        component,
        IS.get_initial_time(time_series),
        IS.get_label(time_series),
    )
    @test IS.get_horizon(time_series) == IS.get_horizon(time_series2)
    @test IS.get_initial_time(time_series) == IS.get_initial_time(time_series2)

    it = IS.get_initial_time(time_series)

    all_time_series = get_all_time_series(data)
    @test length(collect(all_time_series)) == 1

    @test IS.get_time_series_initial_times(data) == [it]
    unique_its = Set{Dates.DateTime}()
    IS.get_time_series_initial_times!(unique_its, component) == [it]
    @test collect(unique_its) == [it]
    @test IS.get_time_series_initial_time(data) == it
    @test IS.get_time_series_interval(data) == IS.UNINITIALIZED_PERIOD
    @test IS.get_time_series_horizon(data) == IS.get_horizon(time_series)
    @test IS.get_time_series_resolution(data) == IS.get_resolution(time_series)
end

@testset "Test add_time_series" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)

    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    time_series =
        IS.Deterministic(label = "val", data = ta, scaling_factor_multiplier = IS.get_val)
    IS.add_time_series!(sys, component, time_series)
    time_series = IS.get_time_series(IS.Deterministic, component, dates[1], "val")
    @test time_series isa IS.Deterministic

    name = "Component2"
    component2 = IS.TestComponent(name, component_val)
    @test_throws ArgumentError IS.add_time_series!(sys, component2, time_series)

    # The component name will exist but not the component.
    component3 = IS.TestComponent(name, component_val)
    @test_throws ArgumentError IS.add_time_series!(sys, component3, time_series)
end

@testset "Test get_time_series_multiple" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)
    initial_time1 = Dates.DateTime("2020-01-01T00:00:00")
    initial_time2 = Dates.DateTime("2020-01-02T00:00:00")

    dates1 = collect(initial_time1:Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"))
    dates2 = collect(initial_time2:Dates.Hour(1):Dates.DateTime("2020-01-02T23:00:00"))
    data1 = collect(1:24)
    data2 = collect(25:48)
    ta1 = TimeSeries.TimeArray(dates1, data1, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data2, [IS.get_name(component)])
    time_series1 =
        IS.Deterministic(label = "val", data = ta1, scaling_factor_multiplier = IS.get_val)
    time_series2 =
        IS.Deterministic(label = "val", data = ta2, scaling_factor_multiplier = IS.get_val)
    IS.add_time_series!(sys, component, time_series1)
    IS.add_time_series!(sys, component, time_series2)

    @test length(collect(IS.get_time_series_multiple(sys))) == 2
    @test length(collect(IS.get_time_series_multiple(component))) == 2
    @test length(collect(IS.get_time_series_multiple(sys))) == 2

    @test length(collect(IS.get_time_series_multiple(sys; type = IS.Deterministic))) == 2
    @test length(collect(IS.get_time_series_multiple(sys; type = IS.Probabilistic))) == 0

    time_series = collect(IS.get_time_series_multiple(sys; initial_time = initial_time1))
    @test length(time_series) == 1
    @test IS.get_initial_time(time_series[1]) == initial_time1
    @test TimeSeries.values(IS.get_data(time_series[1]))[1] == 1

    @test length(collect(IS.get_time_series_multiple(sys; label = "val"))) == 2
    @test length(collect(IS.get_time_series_multiple(sys; label = "bad_label"))) == 0

    filter_func = x -> TimeSeries.values(IS.get_data(x))[12] == 12
    @test length(collect(IS.get_time_series_multiple(
        sys,
        filter_func;
        initial_time = initial_time2,
    ))) == 0
end

# TODO: this is disabled because PowerSystems currently does not set labels correctly.
#@testset "Test add_time_series bad label" begin
#    sys = IS.SystemData()
#    name = "Component1"
#    component_val = 5
#    component = IS.TestComponent(name, component_val)
#    IS.add_component!(sys, component)
#
#    dates = collect(Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1) :
#                    Dates.DateTime("2020-01-01T23:00:00"))
#    data = collect(1:24)
#    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
#    time_series = IS.Deterministic("bad-label", ta)
#    @test_throws ArgumentError IS.add_time_series!(sys, component, time_series)
#end

@testset "Test add_time_series from TimeArray" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)

    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_time_series!(sys, ta, component, "val"; scaling_factor_multiplier = IS.get_val)
    time_series = IS.get_time_series(IS.Deterministic, component, dates[1], "val")
    @test time_series isa IS.Deterministic
end

@testset "Test time_series initial times" begin
    sys = IS.SystemData()

    @test_throws ArgumentError IS.get_time_series_initial_time(sys)
    @test_throws ArgumentError IS.get_time_series_last_initial_time(sys)

    dates1 = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    dates2 = collect(
        Dates.DateTime("2020-01-02T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-02T23:00:00"),
    )
    data = collect(1:24)
    components = []

    for i in 1:2
        name = "Component" * string(i)
        component = IS.TestComponent(name, i)
        IS.add_component!(sys, component)
        push!(components, component)
        if i == 1
            dates1_ = dates1
            dates2_ = dates2
        else
            dates1_ = dates1 .+ Dates.Hour(1)
            dates2_ = dates2 .+ Dates.Hour(1)
        end
        ta1 = TimeSeries.TimeArray(dates1_, data, [IS.get_name(component)])
        ta2 = TimeSeries.TimeArray(dates2_, data, [IS.get_name(component)])
        IS.add_time_series!(sys, ta1, component, "val")
        IS.add_time_series!(sys, ta2, component, "val")
    end

    initial_times = IS.get_time_series_initial_times(sys)
    @test length(initial_times) == 4

    first_initial_time = dates1[1]
    last_initial_time = dates2[1] + Dates.Hour(1)
    @test IS.get_time_series_initial_time(sys) == first_initial_time
    @test IS.get_time_series_last_initial_time(sys) == last_initial_time

    @test_logs(
        (:error, r"initial times don't match"),
        @test !IS.validate_time_series_consistency(sys)
    )
    @test_logs(
        (:error, r"initial times don't match"),
        @test_throws IS.DataFormatError !IS.check_time_series_consistency(sys)
    )

    @test IS.get_time_series_counts(sys) == (2, 4)

    IS.clear_time_series!(sys)
    for component in components
        ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
        ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
        IS.add_time_series!(sys, ta1, component, "val")
        IS.add_time_series!(sys, ta2, component, "val")
    end

    expected = [dates1[1], dates2[1]]
    for component in components
        @test IS.get_time_series_initial_times(IS.Deterministic, component) == expected
    end

    @test IS.validate_time_series_consistency(sys)
    IS.get_time_series_interval(sys) == dates2[1] - dates1[1]
end

@testset "Test remove_time_series" begin
    data = create_system_data(; with_time_series = true)
    components = collect(IS.iterate_components(data))
    @test length(components) == 1
    component = components[1]
    time_series = get_all_time_series(data)
    @test length(get_all_time_series(data)) == 1

    time_series = time_series[1]
    IS.remove_time_series!(
        typeof(time_series),
        data,
        component,
        IS.get_initial_time(time_series),
        IS.get_label(time_series),
    )

    @test length(get_all_time_series(data)) == 0
    @test IS.get_num_time_series(data.time_series_storage) == 0
end

@testset "Test clear_time_series" begin
    data = create_system_data(; with_time_series = true)
    IS.clear_time_series!(data)
    @test length(get_all_time_series(data)) == 0
end

@testset "Test that remove_component removes time_series" begin
    data = create_system_data(; with_time_series = true)

    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, data))
    @test length(components) == 1
    component = components[1]

    all_time_series = collect(IS.get_time_series_multiple(data))
    @test length(all_time_series) == 1
    time_series = all_time_series[1]
    @test IS.get_num_time_series(data.time_series_storage) == 1

    IS.remove_component!(data, component)
    @test length(collect(IS.get_time_series_multiple(component))) == 0
    @test length(collect(IS.get_components(IS.InfrastructureSystemsComponent, data))) == 0
    @test length(get_all_time_series(data)) == 0
    @test IS.get_num_time_series(data.time_series_storage) == 0
end

@testset "Test get_time_series_array" begin
    sys = IS.SystemData()
    name = "Component1"
    component_val = 5
    component = IS.TestComponent(name, component_val)
    IS.add_component!(sys, component)

    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_time_series!(
        sys,
        ta,
        component,
        "val";
        scaling_factor = 1.0,
        scaling_factor_multiplier = IS.get_val,
    )
    time_series = IS.get_time_series(IS.Deterministic, component, dates[1], "val")

    # Test both versions of the function.
    vals = IS.get_time_series_array(component, time_series)
    @test TimeSeries.timestamp(vals) == dates
    @test TimeSeries.values(vals) == data .* component_val

    vals2 = IS.get_time_series_array(IS.Deterministic, component, dates[1], "val")
    @test TimeSeries.timestamp(vals2) == dates
    @test TimeSeries.values(vals2) == data .* component_val
end

@testset "Test get subset of time_series" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_time_series!(sys, ta, component, "val")

    time_series = IS.get_time_series(IS.Deterministic, component, dates[1], "val")
    @test TimeSeries.timestamp(IS.get_data(time_series))[1] == dates[1]

    time_series = IS.get_time_series(IS.Deterministic, component, dates[3], "val", 3)
    @test TimeSeries.timestamp(IS.get_data(time_series))[1] == dates[3]
    @test length(time_series) == 3
end

@testset "Test copy time_series no label mapping" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    initial_time = Dates.DateTime("2020-01-01T00:00:00")
    dates = collect(initial_time:Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    label = "val"
    IS.add_time_series!(sys, ta, component, label)

    component2 = IS.TestComponent("component2", 6)
    IS.add_component!(sys, component2)
    IS.copy_time_series!(component2, component)
    time_series = IS.get_time_series(IS.Deterministic, component2, initial_time, label)
    @test time_series isa IS.Deterministic
    @test IS.get_initial_time(time_series) == initial_time
    @test IS.get_label(time_series) == label
end

@testset "Test copy time_series label mapping" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    initial_time = Dates.DateTime("2020-01-01T00:00:00")
    dates = collect(initial_time:Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"))
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    label1 = "val1"
    IS.add_time_series!(sys, ta, component, label1)

    component2 = IS.TestComponent("component2", 6)
    IS.add_component!(sys, component2)
    label2 = "val2"
    label_mapping = Dict(label1 => label2)
    IS.copy_time_series!(component2, component; label_mapping = label_mapping)
    time_series = IS.get_time_series(IS.Deterministic, component2, initial_time, label2)
    @test time_series isa IS.Deterministic
    @test IS.get_initial_time(time_series) == initial_time
    @test IS.get_label(time_series) == label2
end

@testset "Test copy time_series label mapping, missing label" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    initial_time1 = Dates.DateTime("2020-01-01T00:00:00")
    end_time1 = Dates.DateTime("2020-01-01T23:00:00")
    dates1 = collect(initial_time1:Dates.Hour(1):end_time1)
    initial_time2 = Dates.DateTime("2020-01-02T00:00:00")
    end_time2 = Dates.DateTime("2020-01-02T23:00:00")
    dates2 = collect(initial_time2:Dates.Hour(1):end_time2)
    data = collect(1:24)

    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    label1 = "val1"
    label2a = "val2a"
    IS.add_time_series!(sys, ta1, component, label1)
    IS.add_time_series!(sys, ta2, component, label2a)

    component2 = IS.TestComponent("component2", 6)
    IS.add_component!(sys, component2)
    label2b = "val2b"
    label_mapping = Dict(label2a => label2b)
    IS.copy_time_series!(component2, component; label_mapping = label_mapping)
    time_series = IS.get_time_series(IS.Deterministic, component2, initial_time2, label2b)
    @test time_series isa IS.Deterministic
    @test IS.get_initial_time(time_series) == initial_time2
    @test IS.get_label(time_series) == label2b
    @test_throws ArgumentError IS.get_time_series(
        IS.Deterministic,
        component2,
        initial_time2,
        label2a,
    )
end

function validate_generated_initial_times(
    time_series_type::Type{<:IS.TimeSeriesData},
    component::IS.InfrastructureSystemsComponent,
    label::AbstractString,
    horizon::Int,
    initial_times::Vector{Dates.DateTime},
    initial_time::Dates.DateTime,
    interval::Dates.Period,
    exp_length::Int,
)
    @test length(initial_times) == exp_length
    for it in initial_times
        @test it == initial_time
        # Verify all possible time_series ranges.
        for i in 2:horizon
            time_series = IS.get_time_series(time_series_type, component, it, label, i)
            @test IS.get_horizon(time_series) == i
            @test IS.get_initial_time(time_series) == it
            # This will throw if the resolution isn't consistent throughout.
            IS.get_resolution(IS.get_data(time_series))
        end
        initial_time += interval
    end
end

@testset "Test subset from contiguous time_series" begin
    sys = create_system_data()

    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    dates1 = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    dates2 = collect(
        Dates.DateTime("2020-01-02T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-02T23:00:00"),
    )
    dates3 = collect(
        Dates.DateTime("2020-01-03T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-03T23:00:00"),
    )
    data = collect(1:24)

    label = "val"
    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    ta3 = TimeSeries.TimeArray(dates3, data, [IS.get_name(component)])
    IS.add_time_series!(sys, ta1, component, label)
    IS.add_time_series!(sys, ta2, component, label)
    IS.add_time_series!(sys, ta3, component, label)
    initial_times = IS.get_time_series_initial_times(component)
    @test length(initial_times) == 3
    @test IS.are_time_series_contiguous(component)
    @test IS.are_time_series_contiguous(sys)

    interval = Dates.Hour(1)
    horizon = 55
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates1[1],
        interval,
        18,
    )

    invalid_it = Dates.DateTime("2020-01-20T00:00:00")
    @test_throws ArgumentError IS.get_time_series(
        IS.Deterministic,
        component,
        invalid_it,
        label,
        horizon,
    )
end

@testset "Test generate_initial_times" begin
    sys = create_system_data()
    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    label = "val"
    IS.add_time_series!(sys, ta, component, label)
    initial_times = IS.get_time_series_initial_times(component)
    @test length(initial_times) == 1

    horizon = 24
    interval = Dates.Hour(1)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates[1],
        interval,
        1,
    )

    horizon = 12
    interval = Dates.Hour(1)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates[1],
        interval,
        13,
    )

    horizon = 6
    interval = Dates.Hour(3)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates[1],
        interval,
        7,
    )

    horizon = 6
    interval = Dates.Hour(4)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates[1],
        interval,
        5,
    )

    # Test through the system.
    horizon = 6
    initial_times = IS.generate_initial_times(sys, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates[1],
        interval,
        5,
    )
    IS.clear_time_series!(sys)
    @test_throws ArgumentError IS.generate_initial_times(sys, interval, 6)
end

@testset "Test generate_initial_times contiguous" begin
    sys = create_system_data()

    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    @test_throws ArgumentError IS.are_time_series_contiguous(component)
    @test_throws ArgumentError IS.are_time_series_contiguous(sys)

    dates1 = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    dates2 = collect(
        Dates.DateTime("2020-01-02T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-02T23:00:00"),
    )
    data = collect(1:24)

    label = "val"
    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    IS.add_time_series!(sys, ta1, component, label)
    IS.add_time_series!(sys, ta2, component, label)
    initial_times = IS.get_time_series_initial_times(component)
    @test length(initial_times) == 2
    @test IS.are_time_series_contiguous(component)
    @test IS.are_time_series_contiguous(sys)

    interval = Dates.Hour(1)
    horizon = 48
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates1[1],
        interval,
        1,
    )

    horizon = 24
    interval = Dates.Hour(1)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates1[1],
        interval,
        25,
    )

    horizon = 12
    interval = Dates.Hour(1)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates1[1],
        interval,
        37,
    )

    horizon = 6
    interval = Dates.Hour(3)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates1[1],
        interval,
        15,
    )

    horizon = 6
    interval = Dates.Hour(4)
    initial_times = IS.generate_initial_times(component, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates1[1],
        interval,
        11,
    )

    # Run once on the system.
    horizon = 6
    initial_times = IS.generate_initial_times(sys, interval, horizon)
    validate_generated_initial_times(
        IS.Deterministic,
        component,
        label,
        horizon,
        initial_times,
        dates1[1],
        interval,
        11,
    )
end

@testset "Test generate_initial_times overlapping" begin
    sys = create_system_data()

    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Hour(3), 6)

    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    dates1 = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    dates2 = collect(
        Dates.DateTime("2020-01-01T01:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-02T00:00:00"),
    )
    data = collect(1:24)

    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    IS.add_time_series!(sys, ta1, component, "val")
    @test_throws IS.ConflictingInputsError IS.generate_initial_times(
        sys,
        Dates.Minute(30),
        6,
    )

    IS.add_time_series!(sys, ta2, component, "val")
    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Hour(3), 6)

    @test !IS.are_time_series_contiguous(component)
    @test !IS.are_time_series_contiguous(sys)
end

@testset "Test generate_initial_times non-contiguous" begin
    sys = create_system_data()

    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Hour(3), 6)

    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    dates1 = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    # Skip 1 hour.
    dates2 = collect(
        Dates.DateTime("2020-01-02T01:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-03T00:00:00"),
    )
    data = collect(1:24)

    ta1 = TimeSeries.TimeArray(dates1, data, [IS.get_name(component)])
    ta2 = TimeSeries.TimeArray(dates2, data, [IS.get_name(component)])
    IS.add_time_series!(sys, ta1, component, "val")
    @test_throws IS.ConflictingInputsError IS.generate_initial_times(
        sys,
        Dates.Minute(30),
        6,
    )

    IS.add_time_series!(sys, ta2, component, "val")
    @test_throws ArgumentError IS.generate_initial_times(sys, Dates.Hour(3), 6)

    @test !IS.are_time_series_contiguous(component)
    @test !IS.are_time_series_contiguous(sys)
end

@testset "Test generate_initial_times offset from first initial_time" begin
    sys = create_system_data()

    components = collect(IS.get_components(IS.InfrastructureSystemsComponent, sys))
    @test length(components) == 1
    component = components[1]

    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)

    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_time_series!(sys, ta, component, "val")
    resolution = IS.get_time_series_resolution(sys)
    initial_times = IS.get_time_series_initial_times(component)
    @test length(initial_times) == 1

    horizon = 6
    offset = 1
    interval = resolution * 2
    initial_time = initial_times[1] + offset * resolution

    expected = collect(
        Dates.DateTime("2020-01-01T01:00:00"):interval:Dates.DateTime("2020-01-01T17:00:00"),
    )

    actual =
        IS.generate_initial_times(component, interval, horizon; initial_time = initial_time)
    @test actual == expected

    # Repeat on the system.
    actual = IS.generate_initial_times(sys, interval, horizon; initial_time = initial_time)
    @test actual == expected
end

@testset "Test component-time_series being added to multiple systems" begin
    sys1 = IS.SystemData()
    sys2 = IS.SystemData()
    name = "Component1"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys1, component)

    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    IS.add_time_series!(sys1, ta, component, "val")

    @test_throws ArgumentError IS.add_component!(sys1, component)
end

@testset "Summarize time_series" begin
    data = create_system_data(; with_time_series = true)
    summary(devnull, data.time_series_params)
end

@testset "Test time_series forwarding methods" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]

    # Iteration
    size = 24
    @test length(time_series) == size
    i = 0
    for x in time_series
        i += 1
    end
    @test i == size

    # Indexing
    @test length(time_series[1:16]) == 16

    # when
    fcast = IS.when(time_series, TimeSeries.hour, 3)
    @test length(fcast) == 1
end

@testset "Test time_series head" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]
    fcast = IS.head(time_series)
    # head returns a length of 6 by default, but don't hard-code that.
    @test length(fcast) < length(time_series)

    fcast = IS.head(time_series, 10)
    @test length(fcast) == 10
end

@testset "Test time_series tail" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]
    fcast = IS.tail(time_series)
    # tail returns a length of 6 by default, but don't hard-code that.
    @test length(fcast) < length(time_series)

    fcast = IS.head(time_series, 10)
    @test length(fcast) == 10
end

@testset "Test time_series from" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]
    start_time = Dates.DateTime(Dates.today()) + Dates.Hour(3)
    fcast = IS.from(time_series, start_time)
    @test length(fcast) == 21
    @test TimeSeries.timestamp(IS.get_data(fcast))[1] == start_time
end

@testset "Test time_series from" begin
    data = create_system_data(; with_time_series = true)
    time_series = get_all_time_series(data)[1]
    for end_time in (
        Dates.DateTime(Dates.today()) + Dates.Hour(15),
        Dates.DateTime(Dates.today()) + Dates.Hour(15) + Dates.Minute(5),
    )
        fcast = IS.to(time_series, end_time)
        @test length(fcast) == 16
        @test TimeSeries.timestamp(IS.get_data(fcast))[end] <= end_time
    end
end

@testset "Test ScenarioBased time_series" begin
    sys = IS.SystemData()
    name = "Component1"
    label = "val"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = ones(24, 2)
    ta = TimeSeries.TimeArray(dates, data)
    time_series = IS.ScenarioBased(label, ta)
    fdata = IS.get_data(time_series)
    @test length(TimeSeries.colnames(fdata)) == 2
    @test TimeSeries.timestamp(ta) == TimeSeries.timestamp(fdata)
    @test TimeSeries.values(ta) == TimeSeries.values(fdata)

    IS.add_time_series!(sys, component, time_series)
    time_series2 = IS.get_time_series(IS.ScenarioBased, component, dates[1], label)
    @test time_series2 isa IS.ScenarioBased
    fdata2 = IS.get_data(time_series2)
    @test length(TimeSeries.colnames(fdata2)) == 2
    @test TimeSeries.timestamp(ta) == TimeSeries.timestamp(fdata2)
    @test TimeSeries.values(ta) == TimeSeries.values(fdata2)

    no_time_series = 3
    time_series3 =
        IS.get_time_series(IS.ScenarioBased, component, dates[1], label, no_time_series)
    @test time_series3 isa IS.ScenarioBased
    fdata3 = IS.get_data(time_series3)
    @test length(TimeSeries.colnames(fdata3)) == 2
    @test TimeSeries.timestamp(ta)[1:no_time_series] == TimeSeries.timestamp(fdata3)
    @test TimeSeries.values(ta)[1:no_time_series, :] == TimeSeries.values(fdata3)
end

@testset "Test PiecewiseFunction time_series" begin
    sys = IS.SystemData()
    name = "Component1"
    label = "val"
    component = IS.TestComponent(name, 5)
    IS.add_component!(sys, component)

    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = ones(24, 4)
    name = collect(Iterators.flatten([
        (Symbol("cost_bp$(ix)"), Symbol("load_bp$ix")) for ix in 1:2
    ]))
    ta = TimeSeries.TimeArray(dates, data, name)
    time_series = IS.PiecewiseFunction(label, ta)
    fdata = IS.get_data(time_series)
    @test length(TimeSeries.colnames(fdata)) == 4
    @test TimeSeries.timestamp(ta) == TimeSeries.timestamp(fdata)
    @test TimeSeries.values(ta) == TimeSeries.values(fdata)

    IS.add_time_series!(sys, component, time_series)
    time_series2 = IS.get_time_series(IS.PiecewiseFunction, component, dates[1], label)
    @test time_series2 isa IS.PiecewiseFunction
    fdata2 = IS.get_data(time_series2)
    @test length(TimeSeries.colnames(fdata2)) == 4
    @test TimeSeries.timestamp(ta) == TimeSeries.timestamp(fdata2)
    @test TimeSeries.values(ta) == TimeSeries.values(fdata2)

    no_time_series = 4
    time_series3 =
        IS.get_time_series(IS.PiecewiseFunction, component, dates[1], label, no_time_series)
    @test time_series3 isa IS.PiecewiseFunction
    fdata3 = IS.get_data(time_series3)
    @test length(TimeSeries.colnames(fdata3)) == 4
    @test TimeSeries.timestamp(ta)[1:no_time_series] == TimeSeries.timestamp(fdata3)
    @test TimeSeries.values(ta)[1:no_time_series, :] == TimeSeries.values(fdata3)
end

@testset "Add time_series to unsupported struct" begin
    struct TestComponentNoTimeSeries <: IS.InfrastructureSystemsComponent
        name::AbstractString
        internal::IS.InfrastructureSystemsInternal
    end

    function TestComponentNoTimeSeries(name)
        return TestComponentNoTimeSeries(name, IS.InfrastructureSystemsInternal())
    end

    sys = IS.SystemData()
    name = "component"
    component = TestComponentNoTimeSeries(name)
    IS.add_component!(sys, component)
    dates = collect(
        Dates.DateTime("2020-01-01T00:00:00"):Dates.Hour(1):Dates.DateTime("2020-01-01T23:00:00"),
    )
    data = collect(1:24)
    ta = TimeSeries.TimeArray(dates, data, [IS.get_name(component)])
    time_series = IS.Deterministic(label = "val", data = ta)
    @test_throws ArgumentError IS.add_time_series!(sys, component, time_series)
end
