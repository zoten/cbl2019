defmodule Cbl2019.Configuration.Store do
@name __MODULE__
use Agent, restart: :transient

def start_link(_args) do
    Agent.start_link(
    fn ->
        %{
        :diameter_peers => [],
        }
    end,
    name: @name
    )
end

def get(key) do
    Agent.get(@name, &Map.get(&1, key))
end

def put(key, value) do
    Agent.update(@name, &Map.put(&1, key, value))
end

def merge(map) do
    Agent.update(@name, fn state -> Map.merge(state, map) end)
end
end
