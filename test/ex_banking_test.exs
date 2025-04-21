defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking

  import ExBanking

  setup do
    Application.start(:ex_banking)
    :ok = create_user("Max")
    on_exit(fn -> Application.stop(:ex_banking) end)
  end

  describe "create_user/1" do
    test "creating user successfully" do
      assert create_user("Alice") == :ok
    end

    test "return error when user already exists" do
      assert create_user("Max") == {:error, :user_already_exists}
    end

    test "return error when using wrong arguments" do
      assert create_user("") == {:error, :wrong_arguments}
      assert create_user(4) == {:error, :wrong_arguments}
      assert create_user(nil) == {:error, :wrong_arguments}
    end
  end

  describe "get_balance/2" do
    test "getting balance successfully" do
      assert get_balance("Max", "USD") == {:ok, 0}
    end

    test "return error when user does not exist" do
      assert get_balance("Bob", "USD") == {:error, :user_does_not_exist}
    end

    test "return error when using wrong arguments" do
      assert get_balance("", "USD") == {:error, :user_does_not_exist}
      assert get_balance(4, "USD") == {:error, :wrong_arguments}
      assert get_balance("Max", 4) == {:error, :wrong_arguments}
      assert get_balance("Max", nil) == {:error, :wrong_arguments}
    end

    test "return balance in provided currency after deposit" do
      assert deposit("Max", 100, "USD") == {:ok, 100}
      assert deposit("Max", 100, "EUR") == {:ok, 100}
      assert get_balance("Max", "EUR") == {:ok, 100}
      assert get_balance("Max", "USD") == {:ok, 100}
    end

    test "performance test get_balance/2" do
      generate_user_operation_limit("Max")

      assert get_balance("Max", "USD") == {:error, :too_many_requests_to_user}
    end
  end

  describe "deposit/3" do
    test "depositing money successfully" do
      assert deposit("Max", 100, "USD") == {:ok, 100}
      assert deposit("Max", 50.056, "EUR") == {:ok, 50.06}

      assert deposit("Max", 150, "USD") == {:ok, 250}
      assert deposit("Max", 50, "EUR") == {:ok, 100.06}
    end

    test "user doesn't exist" do
      assert deposit("no-one", 100, "USD") == {:error, :user_does_not_exist}
    end

    test "deposit with wrong arguments" do
      assert deposit(4, 100, "USD") == {:error, :wrong_arguments}
      assert deposit("alice", 100, 4) == {:error, :wrong_arguments}
      assert deposit("alice", "4", "USD") == {:error, :wrong_arguments}
      assert deposit("alice", -4, "USD") == {:error, :wrong_arguments}
      assert deposit("alice", 0, "USD") == {:error, :wrong_arguments}
    end

    test "performance test deposit/3" do
      generate_user_operation_limit("Max")

      assert deposit("Max", 100, "USD") == {:error, :too_many_requests_to_user}
    end
  end

  describe "withdraw/3" do
    test "withdrawing money successfully" do
      assert deposit("Max", 100, "USD") == {:ok, 100}
      assert deposit("Max", 50.056, "EUR") == {:ok, 50.06}

      assert withdraw("Max", 50, "USD") == {:ok, 50}
      assert withdraw("Max", 50.056, "EUR") == {:ok, 0.00}
    end

    test "user doesn't exist" do
      assert withdraw("no-one", 100, "USD") == {:error, :user_does_not_exist}
    end

    test "not enough money" do
      assert deposit("Max", 100, "USD") == {:ok, 100}
      assert withdraw("Max", 200, "USD") == {:error, :not_enough_money}
    end

    test "withdraw with wrong arguments" do
      assert withdraw(4, 100, "USD") == {:error, :wrong_arguments}
      assert withdraw("alice", 100, 4) == {:error, :wrong_arguments}
      assert withdraw("alice", "4", "USD") == {:error, :wrong_arguments}
      assert withdraw("alice", -4, "USD") == {:error, :wrong_arguments}
      assert withdraw("alice", 0, "USD") == {:error, :wrong_arguments}
    end

    test "performance test withdraw/3" do
      generate_user_operation_limit("Max")

      assert withdraw("Max", 100, "USD") == {:error, :too_many_requests_to_user}
    end
  end

  describe "send/4" do
    test "sending money successfully" do
      assert create_user("Alice") == :ok
      assert create_user("Bob") == :ok
      assert deposit("Alice", 100, "USD") == {:ok, 100}
      assert deposit("Bob", 50, "USD") == {:ok, 50}

      assert send("Alice", "Bob", 40, "USD") == {:ok, 60, 90}
      assert get_balance("Alice", "USD") == {:ok, 60}
      assert get_balance("Bob", "USD") == {:ok, 90}
    end

    test "user doesn't exist" do
      assert create_user("Alice") == :ok
      assert send("no-one", "Bob", 100, "USD") == {:error, :sender_does_not_exist}
      assert send("Alice", "no-one", 100, "USD") == {:error, :receiver_does_not_exist}
    end

    test "not enough money" do
      assert create_user("Alice") == :ok
      assert create_user("Bob") == :ok
      assert deposit("Alice", 100, "USD") == {:ok, 100}

      assert send("Alice", "Bob", 200, "USD") == {:error, :not_enough_money}
    end

    test "send with wrong arguments" do
      assert send(4, "Bob", 100, "USD") == {:error, :wrong_arguments}
      assert send("Alice", 4, 40, "USD") == {:error, :wrong_arguments}
      assert send("Alice", "Bob", -40, "USD") == {:error, :wrong_arguments}
      assert send("Alice", "Bob", 0, "USD") == {:error, :wrong_arguments}
    end

    test "performance test for sender send/4" do
      generate_user_operation_limit("Max")

      assert send("Max", "Max2", 100, "USD") == {:error, :too_many_requests_to_sender}
    end

    test "performance test for receiver send/4" do
      assert create_user("Max2") == :ok
      generate_user_operation_limit("Max2")

      assert send("Max", "Max2", 100, "USD") == {:error, :too_many_requests_to_receiver}
    end
  end

  defp generate_user_operation_limit(user) do
    {:ok, pid} = ExBanking.Users.find_user_pid(user)
    true = :erlang.suspend_process(pid)
    Enum.each(1..11, fn _ -> send(pid, :create_limit) end)
  end
end
