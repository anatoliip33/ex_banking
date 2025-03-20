defmodule ExBanking do
  @moduledoc """
  API for interact with User bank account.
  """
  alias ExBanking.User

  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_binary(user) do
    with {:error, :user_does_not_exist} <- User.find_user_pid(user),
         {:ok, _pid} <- DynamicSupervisor.start_child(ExBanking.UserSupervisor, {User, user})
    do
      :ok
    else
      _ -> {:error, :user_already_exists}
    end
  end

  def create_user(_user), do: {:error, :wrong_arguments}

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) when is_binary(user) and is_binary(currency) do
    with {:ok, user_pid} <- User.find_user_pid(user),
         {:ok, _} = response <- GenServer.call(user_pid, {:get_balance, currency}) do

      GenServer.cast(user_pid, {:decrement_operations_count})

      response
    end
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  @spec deposit(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency) when is_binary(user) and is_number(amount) and amount > 0 and is_binary(currency) do
    with {:ok, user_pid} <- User.find_user_pid(user),
         {:ok, _} = response <- GenServer.call(user_pid, {:deposit, amount, currency}) do

      GenServer.cast(user_pid, {:decrement_operations_count})

      response
    end
  end

  def deposit(_, _, _), do: {:error, :wrong_arguments}

  @spec withdraw(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :not_enough_money | :too_many_requests_to_user}
  def withdraw(user, amount, currency) when is_binary(user) and is_number(amount) and amount > 0 and is_binary(currency) do
    with {:ok, user_pid} <- User.find_user_pid(user),
         {:ok, _} = response <- GenServer.call(user_pid, {:withdraw, amount, currency}) do

      GenServer.cast(user_pid, {:decrement_operations_count})

      response
    end
  end

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number(),
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number(), to_user_balance :: number()}
          | {
              :error,
              :wrong_arguments
              | :not_enough_money
              | :sender_does_not_exist
              | :receiver_does_not_exist
              | :too_many_requests_to_sender
              | :too_many_requests_to_receiver
            }
  def send(from_user, to_user, amount, currency)
        when is_binary(from_user) and is_binary(to_user) and is_number(amount) and amount > 0 and is_binary(currency) do
    with {:sender, {:ok, from_user_pid}} <- {:sender, User.find_user_pid(from_user)},
         {:receiver, {:ok, to_user_pid}} <- {:receiver, User.find_user_pid(to_user)},
         {:sender_withdraw, {:ok, from_user_balance}} <- {:sender_withdraw, GenServer.call(from_user_pid, {:withdraw, amount, currency})},
         {:receiver_deposit, {:ok, to_user_balance}} <- {:receiver_deposit, GenServer.call(to_user_pid, {:deposit, amount, currency})}
    do
      GenServer.cast(from_user_pid, {:decrement_operations_count})
      GenServer.cast(to_user_pid, {:decrement_operations_count})

      {:ok, from_user_balance, to_user_balance}
    else
      {:sender, {:error, _message}} ->
        {:error, :sender_does_not_exist}

      {:sender_withdraw, {:error, :too_many_requests_to_user}} ->
        {:error, :too_many_requests_to_sender}

      {:receiver, {:error, _message}} ->
        {:error, :receiver_does_not_exist}

      {:receiver_deposit, {:error, :too_many_requests_to_user}} ->
        {:error, :too_many_requests_to_receiver}

      _ ->
        {:error, :not_enough_money}
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}
end
