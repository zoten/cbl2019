defmodule Cbl2019.Provision.ImsiStore do
  use GenServer
  require Logger

  import Cbl2019.Misc.Math, only: [increment: 1]
  import Cbl2019.Misc.Time, only: [now: 0]

  alias Cbl2019.Misc.Math
  alias Cbl2019.Misc.Time
  alias Cbl2019.Provision.ImsiStore
  alias Cbl2019.Provision.Repo
  alias Cbl2019.Provision.Imsi
  alias Cbl2019.Provision.Imsis

  @name __MODULE__
  @cache_timer 6000

  defstruct calls: 0,
            status: :idle

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %ImsiStore{}, name: @name)
  end

  def init(state) do
    GenServer.cast(@name, :start)
    send(@name, :start_cache_timer)
    {:ok, state}
  end

  # Genserver callbacks
  def handle_cast(:start, state) do
    Logger.debug fn -> "Starting IMSI Store" end

    # Cache ETS table
    :ets.new(:imsis, [:set, :protected, :named_table])

    # Let's insert some fake data
    add_imsi("001010010100101", "012345678901231", :whitelisted)
    add_imsi("001010010100102", "012345678901232", :whitelisted)
    add_imsi("001010010100103", "012345678901233", :whitelisted)
    add_imsi("001010010100104", "012345678901234", :whitelisted)
    add_imsi("001010010100105", "012345678901235", :blacklisted)
    add_imsi("001010010100106", "012345678901236", :blacklisted)
    add_imsi("001010010100107", "012345678901237", :blacklisted)
    add_imsi("001010010100108", "012345678901238", :blacklisted)
    add_imsi("001010010100109", "012345678901239", :greylisted)

    Logger.debug fn -> "#{inspect self()}" end

    new_state = state
      |> Map.update!(:status, fn _ -> :started end)
    {:noreply, new_state}
  end

  def handle_info(:start_cache_timer, state) do
    Logger.debug "Cache timer"

    Logger.debug fn -> "#{inspect state}" end
    data = :ets.lookup(:imsis, get_ets_key("001010010100101", "012345678901231"))
    Logger.debug fn -> "#{inspect data}" end

    # Process.send_after(self(), :start_cache_timer, @cache_timer, [])
    {:noreply, state}
  end

  def handle_call({:get, imsi, imei}, _from, state) do
    Logger.debug fn -> "Handling call #{inspect imsi} #{inspect imei}" end
    new_state = state
      |> Map.update!(:calls, &Math.increment/1)

    case imsi_data = get_imsi(imsi, imei) do
      {:ok, data} ->
        {:reply, {:ok, data}, new_state}
      {:error, :not_found} ->
        {:reply, {:error, :not_found}, new_state}
      _ ->
        {:noreply, new_state}
    end
  end

  def handle_call({_timer_expiry, :cache_timer}, _from, state) do
    Logger.debug fn -> "Cache timer expired #{Time.now()}" end
    {:reply, :something, state}
  end

  # Privates
  defp get_ets_key(imsi, imei) do
    {imsi, imei}
  end

  defp add_imsi(imsi, imei, status) when status in [:blacklisted, :whitelisted, :greylisted] do
    Logger.debug fn -> "Adding IMSI #{imsi} #{imei} #{inspect status}" end
    key = get_ets_key(imsi, imei)
    Logger.debug fn -> "Key #{inspect key}" end

    imsi_data = %Imsi{imsi: imsi, imei: imei, status: status, loaded: now()}
    :ets.insert(:imsis, {key, imsi_data})
    {:ok, imsi_data}
  end

  defp del_imsi(imsi, _imei) do
    :ets.delete(:imsis, imsi)
  end

  # Return
  #   {:ok, %Imsi{}}
  #   {:ok, :unknown}
  #   {:error, err}
  defp get_imsi(imsi, imei) do
    Logger.debug "Get IMSI #{imsi} #{imei}"
    case imsi_data = get_imsi(:ets, imsi, imei) do
      [{key, %Imsi{} = data} | _tail] ->
        {:ok, data}
      something ->
        Logger.error "No ets data found: #{inspect something}"
        {:error, :not_found}
    end
  end

  defp get_imsi(:ets, imsi, imei) do
    Logger.debug "Get IMSI (ETS) #{imsi}"
    key = get_ets_key(imsi, imei)
    Logger.debug fn -> "Key #{inspect key}" end
    Logger.debug fn -> "#{inspect self()}" end
    :ets.lookup(:imsis, key)
  end

end