defmodule ExamplePhoenix.Chat.RoomRateLimit do
  use GenServer
  require Logger

  @max_rooms_per_user 5
  @cooldown_period 3600  # 1 hour in seconds
  @timeout 5000  # 5 seconds timeout
  @unlimited_ips ["localhost", "127.0.0.1"]

  # Client API
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def can_create_room?(user_name) do
    case GenServer.call(__MODULE__, {:check_limit, user_name}, @timeout) do
      {:ok, can_create} -> can_create
      _ -> false
    end
  end

  def record_room_creation(user_name) do
    GenServer.cast(__MODULE__, {:record_creation, user_name})
  end

  def get_user_stats(user_name) do
    case GenServer.call(__MODULE__, {:get_stats, user_name}, @timeout) do
      {:ok, stats} -> stats
      _ -> %{rooms_created: 0, remaining_limit: @max_rooms_per_user}
    end
  end

  # Server Callbacks
  @impl true
  def init(_) do
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:check_limit, user_ip}, _from, state) do
    if user_ip in @unlimited_ips do
      {:reply, {:ok, true}, state}
    else
      user_rooms = Map.get(state, user_ip, [])
      current_time = System.system_time(:second)

      active_rooms = Enum.filter(user_rooms, fn timestamp ->
        current_time - timestamp < @cooldown_period
      end)

      can_create = length(active_rooms) < @max_rooms_per_user
      {:reply, {:ok, can_create}, state}
    end
  end

  @impl true
  def handle_call({:get_stats, user_name}, _from, state) do
    user_rooms = Map.get(state, user_name, [])
    current_time = System.system_time(:second)

    active_rooms = Enum.filter(user_rooms, fn timestamp ->
      current_time - timestamp < @cooldown_period
    end)

    stats = %{
      rooms_created: length(active_rooms),
      remaining_limit: @max_rooms_per_user - length(active_rooms)
    }

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_cast({:record_creation, user_ip}, state) do
    current_time = System.system_time(:second)
    user_rooms = Map.get(state, user_ip, [])
    updated_rooms = [current_time | user_rooms]
    {:noreply, Map.put(state, user_ip, updated_rooms)}
  end

  @impl true
  def handle_info(:cleanup, state) do
    current_time = System.system_time(:second)

    cleaned_state = Map.new(state, fn {user, timestamps} ->
      active_timestamps = Enum.filter(timestamps, fn ts ->
        current_time - ts < @cooldown_period
      end)
      {user, active_timestamps}
    end)
    |> Enum.reject(fn {_, timestamps} -> Enum.empty?(timestamps) end)
    |> Map.new()

    schedule_cleanup()
    {:noreply, cleaned_state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cooldown_period * 1000)
  end
end
