defmodule <%= base %>Web.PasswordResetController do
  use <%= base %>Web, :controller<%= if not api do %>

  import <%= base %>Web.Authorize<% end %>
  alias <%= base %>.{Accounts, Message}
<%= if not api do %>
  def new(conn, _params) do
    render(conn, "new.html")
  end<% end %>

  def create(conn, %{"password_reset" => %{"email" => email}}) do
    key = Accounts.create_password_reset(<%= base %>Web.Endpoint, %{"email" => email})
    Message.reset_request(email, key)
    message = "Check your inbox for instructions on how to reset your password"<%= if api do %>
    conn
    |> put_status(:created)
    |> render(<%= base %>Web.PasswordResetView, "info.json", %{info: message})
  end<% else %>
    success(conn, message, page_path(conn, :index))
  end

  def edit(conn, %{"key" => key}) do
    render(conn, "edit.html", key: key)
  end
  def edit(conn, _params) do
    render(conn, <%= base %>.ErrorView, "404.html")
  end<% end %>

  def update(conn, %{"password_reset" => params}) do
    case Phauxth.Confirm.verify(params, Accounts, mode: :pass_reset) do
      {:ok, user} ->
        Accounts.update_password(user, params) |> update_password(conn, params)
      {:error, message} -><%= if api do %>
        put_status(conn, :unprocessable_entity)
        |> render(<%= base %>Web.PasswordResetView, "error.json", error: message)<% else %>
        put_flash(conn, :error, message)
        |> render("edit.html", key: params["key"])<% end %>
    end
  end

  defp update_password({:ok, user}, conn, _params) do
    Message.reset_success(user.email)
    message = "Your password has been reset"<%= if api do %>
    render(conn, <%= base %>Web.PasswordResetView, "info.json", %{info: message})<% else %>
    configure_session(conn, drop: true)
    |> success(message, session_path(conn, :new))<% end %>
  end
  defp update_password({:error, %Ecto.Changeset{} = changeset}, conn, <%= if api do %>_<% end %>params) do
    message = with p <- changeset.errors[:password], do: elem(p, 0)<%= if api do %>
    put_status(conn, :unprocessable_entity)
    |> render(<%= base %>Web.PasswordResetView, "error.json", error: message || "Invalid input")<% else %>
    put_flash(conn, :error, message || "Invalid input")
    |> render("edit.html", key: params["key"])<% end %>
  end
end
