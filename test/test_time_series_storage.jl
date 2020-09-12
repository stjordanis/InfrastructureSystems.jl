
function test_add_remove(storage::IS.TimeSeriesStorage)
    name = "component1"
    label = "val"
    component = IS.TestComponent(name, 5)
    ts = create_time_array()
    IS.add_time_series!(storage, IS.get_uuid(component), label, ts)

    ts_data = IS.get_time_series(storage, IS.get_uuid(ts))

    @test TimeSeries.timestamp(ts_data) == TimeSeries.timestamp(ts.data)
    @test TimeSeries.values(ts_data) == TimeSeries.values(ts.data)

    component2 = IS.TestComponent("component2", 6)
    IS.add_time_series!(storage, IS.get_uuid(component2), label, ts)

    @test IS.get_num_time_series(storage) == 1

    IS.remove_time_series!(storage, IS.get_uuid(ts), IS.get_uuid(component2), label)

    # There should still be one reference to the data.
    ts_data2 = IS.get_time_series(storage, IS.get_uuid(ts))
    @test ts_data2 isa TimeSeries.TimeArray

    IS.remove_time_series!(storage, IS.get_uuid(ts), IS.get_uuid(component), label)
    @test_throws ArgumentError IS.get_time_series(storage, IS.get_uuid(ts))
    IS.get_num_time_series(storage) == 0
end

function test_add_references(storage::IS.TimeSeriesStorage)
    label = "val"
    component1 = IS.TestComponent("component1", 5)
    component2 = IS.TestComponent("component2", 6)
    ts = create_time_array()
    ts_uuid = IS.get_uuid(ts)
    IS.add_time_series!(storage, IS.get_uuid(component1), label, ts)
    IS.add_time_series_reference!(storage, IS.get_uuid(component2), label, ts_uuid)

    @test IS.get_num_time_series(storage) == 1

    IS.remove_time_series!(storage, ts_uuid, IS.get_uuid(component1), label)

    # There should still be one reference to the data.
    @test IS.get_time_series(storage, ts_uuid) isa TimeSeries.TimeArray

    IS.remove_time_series!(storage, ts_uuid, IS.get_uuid(component2), label)
    @test_throws ArgumentError IS.get_time_series(storage, IS.get_uuid(ts))
    IS.get_num_time_series(storage) == 0
end

function test_get_subset(storage::IS.TimeSeriesStorage)
    name = "component1"
    label = "val"
    component = IS.TestComponent(name, 1)
    ts = create_time_array()
    IS.add_time_series!(storage, IS.get_uuid(component), label, ts)
    ts_data = IS.get_time_series(storage, IS.get_uuid(ts))

    @test TimeSeries.timestamp(ts_data) == TimeSeries.timestamp(ts.data)
    index = 3
    len = 5
    ts_subset = IS.get_time_series(storage, IS.get_uuid(ts); index = index, len = len)
    @test ts_subset[1] == ts_data[index]
    @test length(ts_subset) == len
end

function test_clear(storage::IS.TimeSeriesStorage)
    name = "component1"
    label = "val"
    component = IS.TestComponent(name, 5)
    ts = create_time_array()
    IS.add_time_series!(storage, IS.get_uuid(component), label, ts)

    ts_data = IS.get_time_series(storage, IS.get_uuid(ts))

    @test TimeSeries.timestamp(ts_data) == TimeSeries.timestamp(ts.data)
    @test TimeSeries.values(ts_data) == TimeSeries.values(ts.data)

    IS.clear_time_series!(storage)
    @test_throws ArgumentError IS.get_time_series(storage, IS.get_uuid(ts))
end

@testset "Test time series storage implementations" begin
    for in_memory in (true, false)
        test_add_remove(IS.make_time_series_storage(; in_memory = in_memory))
        test_get_subset(IS.make_time_series_storage(; in_memory = in_memory))
        test_clear(IS.make_time_series_storage(; in_memory = in_memory))
    end

    test_add_remove(IS.make_time_series_storage(; in_memory = false, directory = "."))
    test_get_subset(IS.make_time_series_storage(; in_memory = false, directory = "."))
    test_clear(IS.make_time_series_storage(; in_memory = false, directory = "."))
end

@testset "Test copy time series references" begin
    for in_memory in (true, false)
        test_add_remove(IS.make_time_series_storage(; in_memory = in_memory))
        test_add_references(IS.make_time_series_storage(; in_memory = in_memory))
        test_get_subset(IS.make_time_series_storage(; in_memory = in_memory))
        test_clear(IS.make_time_series_storage(; in_memory = in_memory))
    end
end
