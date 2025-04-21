defmodule ExBanking.Users do
  @moduledoc """
  Users context.
  """

  def find_user_pid(user) do
    case Registry.lookup(Registry.Users, user) do
      [{user_pid, _}] ->
        {:ok, user_pid}

      _ ->
        {:error, :user_does_not_exist}
    end
  end


  def user_operation_allowness(pid) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, count} when count < 10 ->
        :ok

      _ ->
        {:error, :too_many_requests_to_user}
    end
  end
end
