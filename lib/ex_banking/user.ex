defmodule ExBanking.User do
  use GenServer

  def start_link(user) do
    name = via_name(user)
    GenServer.start_link(__MODULE__, %{count_operations: 0, balance: []}, name: name)
  end

  # Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:get_balance, currency}, _from, %{count_operations: count_operations} = state) when count_operations < 10 do
    state = %{state | count_operations: increment_count(count_operations)}

    case state.balance |> Enum.find(&(elem(&1, 0) == currency)) do
      {_currency, current_balance} ->
        {:reply, {:ok, current_balance}, state}

      _ ->
        {:reply, {:ok, 0.0}, state}
    end
  end

  @impl true
  def handle_call({:deposit, amount, currency}, _from, %{count_operations: count_operations} = state) when count_operations < 10 do
    state = %{state | count_operations: increment_count(count_operations)}

    {new_amount, balance} =
      case state.balance |> Enum.split_with(&(elem(&1, 0) == currency)) do
        {[{_currency, current_amount}], balance} ->
          {
            prepare_amount(current_amount + amount),
            balance
          }

        {[], balance} ->
          {
            prepare_amount(amount),
            balance
          }
      end

      new_balance = [{currency, new_amount} | balance]

      # {:reply, {:ok, new_amount}, state |> Map.put(:balance, new_balance), {:continue, :decrement_operations_count}}
      {:reply, {:ok, new_amount}, state |> Map.put(:balance, new_balance)}
  end

  @impl true
  def handle_call({:withdraw, amount, currency}, _from, %{count_operations: count_operations} = state) when count_operations < 10 do
    state = %{state | count_operations: increment_count(count_operations)}

    case state.balance |> Enum.split_with(&(elem(&1, 0) == currency)) do
      {[{currency, current_amount}], balance} ->
        if current_amount >= amount do
          new_amount = prepare_amount(current_amount - amount)
          {:reply, {:ok, new_amount}, state |> Map.put(:balance, [{currency, new_amount} | balance])}
        else
          {:reply, {:error, :not_enough_money}, state}
        end

      {[], _balance} ->
        {:reply, {:error, :not_enough_money}, state}
    end
  end

  @impl true
  def handle_call(_args, _from, state) do
    {:reply, {:error, :too_many_requests_to_user}, state}
  end

  @impl true
  def handle_cast({:decrement_operations_count}, %{count_operations: count_operations} = state) do
    new_state = %{state | count_operations: count_operations - 1}
    {:noreply, new_state}
  end

  def find_user_pid(user) do
    case Registry.lookup(Registry.Users, user) do
      [{user_pid, _}] ->
        {:ok, user_pid}

      _ ->
        {:error, :user_does_not_exist}
    end
  end

  defp via_name(user) do
    {:via, Registry, {Registry.Users, user}}
  end

  defp prepare_amount(amount), do: Float.round(amount * 1.0, 2)

  defp increment_count(count_operations), do: count_operations + 1
end
