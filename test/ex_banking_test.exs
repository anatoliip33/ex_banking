defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking

  import ExBanking

  setup do
    on_exit(fn ->
      :ok = Application.stop(:ex_banking)
      :ok = Application.start(:ex_banking)
    end)
  end

  test "creating a user" do
    assert create_user("alice") == :ok
    assert create_user("alice") == {:error, :user_already_exists}
    assert create_user(4) == {:error, :wrong_arguments}
  end

  test "depositing money" do
    assert create_user("alice") == :ok
    assert deposit("alice", 100.05, "USD") == {:ok, 100.05}
    assert get_balance("alice", "USD") == {:ok, 100.05}
    assert deposit("alice", 0.0599999, "USD") == {:ok, 100.11}
    assert deposit("alice", 70, "EUR") == {:ok, 70}
    assert get_balance("alice", "USD") == {:ok, 100.11}
    assert get_balance("alice", "EUR") == {:ok, 70.00}
    assert deposit("another_alice", 100, "USD") == {:error, :user_does_not_exist}
    assert deposit(4, 100, "USD") == {:error, :wrong_arguments}
    assert deposit("alice", 100, 4) == {:error, :wrong_arguments}
    assert deposit("alice", "4", "USD") == {:error, :wrong_arguments}
    assert deposit("alice", -4, "USD") == {:error, :wrong_arguments}
    assert deposit("alice", 0, "USD") == {:error, :wrong_arguments}
  end

  test "withdrawing money" do
    assert create_user("alice") == :ok
    assert deposit("alice", 100, "USD") == {:ok, 100}
    assert deposit("alice", 70, "EUR") == {:ok, 70}
    assert withdraw("alice", 50, "USD") == {:ok, 50}
    assert withdraw("alice", 60, "USD") == {:error, :not_enough_money}
    assert withdraw("another_alice", 50, "USD") == {:error, :user_does_not_exist}
    assert withdraw(4, 50, "USD") == {:error, :wrong_arguments}
    assert withdraw("alice", 50, 4) == {:error, :wrong_arguments}
    assert withdraw("alice", "50", "USD") == {:error, :wrong_arguments}
    assert withdraw("alice", -50, "USD") == {:error, :wrong_arguments}
    assert withdraw("alice", 0, "USD") == {:error, :wrong_arguments}
    assert get_balance("alice", "USD") == {:ok, 50}
    assert get_balance("alice", "EUR") == {:ok, 70}
  end

  test "sending money between users" do
    assert create_user("alice") == :ok
    assert create_user("bob") == :ok
    assert deposit("alice", 100, "USD") == {:ok, 100}
    assert send("alice", "bob", 40, "USD") == {:ok, 60, 40}
    assert get_balance("alice", "USD") == {:ok, 60}
    assert get_balance("bob", "USD") == {:ok, 40}
    assert send("alice", "bob", 100, "USD") == {:error, :not_enough_money}
    assert get_balance("alice", "USD") == {:ok, 60}
    assert get_balance("bob", "USD") == {:ok, 40}
    assert send("alice", "bob", 100, "EUR") == {:error, :not_enough_money}
    assert get_balance("alice", "EUR") == {:ok, 0}
    assert get_balance("bob", "EUR") == {:ok, 0}
    assert send(4, "bob", 40, "USD") == {:error, :wrong_arguments}
    assert send("alice", 4, "40", "USD") == {:error, :wrong_arguments}
    assert send("alice", "bob", 40, 4) == {:error, :wrong_arguments}
    assert send("alice", "bob", -40, "USD") == {:error, :wrong_arguments}
    assert send("alice", "bob", 0, "USD") == {:error, :wrong_arguments}
    assert send("another_alice", "bob", 40, "USD") == {:error, :sender_does_not_exist}
    assert send("alice", "another_bob", 40, "USD") == {:error, :receiver_does_not_exist}
  end

  test "checking balance" do
    assert create_user("alice") == :ok
    assert deposit("alice", 100, "USD") == {:ok, 100}
    assert deposit("alice", 70, "EUR") == {:ok, 70}
    assert get_balance("alice", "USD") == {:ok, 100}
    assert get_balance("alice", "EUR") == {:ok, 70}
    assert get_balance("alice", "HRN") == {:ok, 0}
    assert get_balance("alice", 4) == {:error, :wrong_arguments}
    assert get_balance(4, "USD") == {:error, :wrong_arguments}
    assert get_balance("another_alice", "USD") == {:error, :user_does_not_exist}
  end

  test "concurrent requests for a user" do
    # assert create_user("alice") == :ok
    assert create_user("bob") == :ok
    attempted_requests = 50

    tasks =
      Enum.map(1..attempted_requests, fn _ ->
        Task.async(fn ->
          deposit("bob", 10, "USD")
        end)
      end)

    results = Enum.map(tasks, &Task.await(&1, :infinity))

    assert Enum.count(results, &(elem(&1, 0) == :ok)) >= 10
    assert Enum.count(results, &(elem(&1, 0) == :ok)) <= 20

    # 60 percent of the time it works every time)
    assert Enum.count(results, &(elem(&1, 0) == :ok)) == 10
    # assert get_balance("alice", "USD") == {:ok, 100}
    assert get_balance("bob", "USD") == {:ok, 100}

    # {:ok, alice_amount} = get_balance("alice", "USD")
    {:ok, bob_amount} = get_balance("bob", "USD")
    # assert alice_amount >= 100 and alice_amount <= 200
    assert bob_amount >= 100 and bob_amount <= 200
  end

  test "concurrent requests for multiple users" do
    assert create_user("alice") == :ok
    assert create_user("bob") == :ok

    tasks =
      Enum.flat_map(1..10, fn _ ->
        [
          Task.async(fn -> deposit("alice", 10, "USD") end),
          Task.async(fn -> deposit("bob", 20, "USD") end)
        ]
      end)

    results = Enum.map(tasks, &Task.await(&1))

    alice_bob_deposits =
      Enum.count(results, fn
        {:ok, _balance} -> true
        {:error, :too_many_requests_to_user} -> false
        _ -> false
      end)

    assert alice_bob_deposits == 20

    {:ok, alice_balance} = get_balance("alice", "USD")
    {:ok, bob_balance} = get_balance("bob", "USD")

    assert alice_balance == 100
    assert bob_balance == 200
  end
end
