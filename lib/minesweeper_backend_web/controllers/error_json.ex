defmodule MinesweeperBackendWeb.ErrorJSON do
  @moduledoc """
  Renders the APIError type from the README:

      type APIError = { "message": string };
  """

  def render("404.json", _assigns), do: %{message: "not found"}
  def render("400.json", _assigns), do: %{message: "bad request"}
  def render("401.json", _assigns), do: %{message: "unauthorized"}
  def render("500.json", _assigns), do: %{message: "internal server error"}

  def render(template, _assigns) do
    %{message: Phoenix.Controller.status_message_from_template(template)}
  end

  def error(%{message: message}) when is_binary(message), do: %{message: message}
  def error(_), do: %{message: "error"}
end
