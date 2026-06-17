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
    |> render(:error, message: "unauthorized")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: "not found")
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: "bad request")
  end

  def call(conn, {:error, :service_unavailable}) do
    conn
    |> put_status(:service_unavailable)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: "service unavailable")
  end

  def call(conn, {:error, message}) when is_binary(message) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ErrorJSON)
    |> render(:error, message: message)
  end

  defp format_changeset(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
    |> Enum.map(fn {field, errs} -> "#{field}: #{Enum.join(errs, ", ")}" end)
    |> Enum.join("; ")
  end
end
