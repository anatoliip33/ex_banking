defmodule ExBanking.User do
  @moduledoc """
  User module for ExBanking application.
  This module is responsible for managing user accounts and their balances.
  """

  use GenServer

  def start_link(user) do
    name = via_name(user)
    GenServer.start_link(__MODULE__, %{balance: []}, name: name)
  end

  # Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:get_balance, currency}, _from, %{balance: balance} = state) do
    case balance |> Enum.find(&(elem(&1, 0) == currency)) do
      {_currency, current_balance} ->
        {:reply, {:ok, current_balance}, state}

      _ ->
        {:reply, {:ok, 0.0}, state}
    end
  end

  @impl true
  def handle_call({:deposit, amount, currency}, _from, %{balance: balance} = state) do
    {new_amount, balance} =
      case balance |> Enum.split_with(&(elem(&1, 0) == currency)) do
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

      {:reply, {:ok, new_amount}, state |> Map.put(:balance, new_balance)}
  end

  @impl true
  def handle_call({:withdraw, amount, currency}, _from, %{balance: balance} = state) do
    case balance |> Enum.split_with(&(elem(&1, 0) == currency)) do
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

  defp via_name(user) do
    {:via, Registry, {Registry.Users, user}}
  end

  defp prepare_amount(amount), do: Float.round(amount * 1.0, 2)
end
