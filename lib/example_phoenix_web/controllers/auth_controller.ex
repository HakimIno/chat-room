defmodule ExamplePhoenixWeb.AuthController do
  use ExamplePhoenixWeb, :controller
  alias ExamplePhoenix.Accounts.User

  def index(conn, _params) do
    if get_session(conn, :user_name) do
      redirect(conn, to: ~p"/chat")
    else
      conn
      |> assign(:current_user, nil)
      |> render(:index)
    end
  end

  def create(conn, %{"user" => user_params}) do
    case User.get_user_by_name(user_params["name"]) do
      %User{} = existing_user ->
        {:ok, updated_user} = User.update_user(existing_user, %{avatar: user_params["avatar"]})
        IO.inspect(updated_user, label: "Updated User")
        conn
        |> put_session(:user_name, updated_user.name)
        |> put_session(:user_avatar, updated_user.avatar)
        |> configure_session(renew: true)
        |> redirect(to: ~p"/chat")

      nil ->
        case User.create_user(user_params) do
          {:ok, user} ->
            conn
            |> put_session(:user_name, user.name)
            |> put_session(:user_avatar, user.avatar)
            |> configure_session(renew: true)
            |> redirect(to: ~p"/chat")

          {:error, changeset} ->
            conn
            |> put_flash(:error, error_message(changeset))
            |> redirect(to: ~p"/auth")
        end
    end
  end

  defp error_message(changeset) do
    case changeset.errors do
      [{:name, {_, [constraint: :unique, constraint_name: _]}} | _] ->
        "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว"
      [{:name, {msg, _}} | _] ->
        "ชื่อผู้ใช้ไม่ถูกต้อง: #{msg}"
      _ ->
        "เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง"
    end
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/auth")
  end
end
