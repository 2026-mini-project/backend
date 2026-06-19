defmodule MinesweeperBackendWeb.FallbackController do
  use MinesweeperBackendWeb, :controller

  alias MinesweeperBackendWeb.ErrorJSON

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: format_changeset(changeset))
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: "인증이 필요합니다")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: "요청한 리소스를 찾을 수 없습니다")
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: "잘못된 요청입니다")
  end

  def call(conn, {:error, :service_unavailable}) do
    conn
    |> put_status(:service_unavailable)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: "서비스를 일시적으로 사용할 수 없습니다")
  end

  def call(conn, {:error, message}) when is_binary(message) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: message)
  end

  defp format_changeset(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&translate_changeset_error/1)
    |> Enum.map(fn {field, errs} -> "#{translate_field(field)}: #{Enum.join(errs, ", ")}" end)
    |> Enum.join("; ")
  end

  defp translate_changeset_error({"can't be blank", _opts}), do: "필수 입력값입니다"
  defp translate_changeset_error({"has already been taken", _opts}), do: "이미 사용 중입니다"
  defp translate_changeset_error({"is invalid", _opts}), do: "올바르지 않습니다"
  defp translate_changeset_error({"does not exist", _opts}), do: "존재하지 않습니다"

  defp translate_changeset_error({"should be at least %{count} character(s)", opts}),
    do: "#{Keyword.fetch!(opts, :count)}자 이상이어야 합니다"

  defp translate_changeset_error({"should be at most %{count} character(s)", opts}),
    do: "#{Keyword.fetch!(opts, :count)}자 이하여야 합니다"

  defp translate_changeset_error({"must be greater than %{number}", opts}),
    do: "#{Keyword.fetch!(opts, :number)}보다 커야 합니다"

  defp translate_changeset_error({"must be less than or equal to %{number}", opts}),
    do: "#{Keyword.fetch!(opts, :number)} 이하여야 합니다"

  defp translate_changeset_error({"must be less than %{number}", opts}),
    do: "#{Keyword.fetch!(opts, :number)}보다 작아야 합니다"

  defp translate_changeset_error({"must be greater than or equal to %{number}", opts}),
    do: "#{Keyword.fetch!(opts, :number)} 이상이어야 합니다"

  defp translate_changeset_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {k, v}, acc ->
      String.replace(acc, "%{#{k}}", to_string(v))
    end)
  end

  defp translate_field(:name), do: "이름"
  defp translate_field(:owner_id), do: "방장"
  defp translate_field(:max_players), do: "최대 인원"
  defp translate_field(field), do: to_string(field)
end
