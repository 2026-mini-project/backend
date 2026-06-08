defmodule MinesweeperBackendWeb.SessionJSON do
  alias MinesweeperBackend.Accounts.User

  @doc """
  Renders APIUser:

      type APIUser = { "id": string, "name": string };
  """
  def show(%{user: %User{id: id, name: name}}) do
    %{id: id, name: name}
  end
end
