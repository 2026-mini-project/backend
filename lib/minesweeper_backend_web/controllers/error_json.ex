defmodule MinesweeperBackendWeb.ErrorJSON do
  @moduledoc """
  Renders the APIError type from the README:

      type APIError = { "message": string };
  """

  def render("404.json", _assigns), do: %{message: "요청한 리소스를 찾을 수 없습니다"}
  def render("400.json", _assigns), do: %{message: "잘못된 요청입니다"}
  def render("401.json", _assigns), do: %{message: "인증이 필요합니다"}
  def render("500.json", _assigns), do: %{message: "서버 내부 오류가 발생했습니다"}
  def render("503.json", _assigns), do: %{message: "서비스를 일시적으로 사용할 수 없습니다"}

  def render(template, _assigns) do
    %{message: status_message_from_template(template)}
  end

  def error(%{message: message}) when is_binary(message), do: %{message: message}
  def error(_), do: %{message: "오류가 발생했습니다"}

  defp status_message_from_template(template) do
    case Phoenix.Controller.status_message_from_template(template) do
      "Bad Request" -> "잘못된 요청입니다"
      "Unauthorized" -> "인증이 필요합니다"
      "Forbidden" -> "접근 권한이 없습니다"
      "Not Found" -> "요청한 리소스를 찾을 수 없습니다"
      "Unprocessable Entity" -> "요청을 처리할 수 없습니다"
      "Internal Server Error" -> "서버 내부 오류가 발생했습니다"
      "Service Unavailable" -> "서비스를 일시적으로 사용할 수 없습니다"
      _ -> "오류가 발생했습니다"
    end
  end
end
