defmodule MailProxyWeb.ApiMailController do
  use MailProxyWeb, :controller

  def queue(%{assigns: %{account: %MailProxy.Accounts.Account{} = account}} = conn, args) do
    IO.puts("account #{account.name} sending an email")
    IO.inspect(args)

    json(conn, %{status: :ok})
  end

  def queue(conn, _args) do
    IO.puts("no account?")
    IO.inspect(conn)

    conn
    |> put_status(403)
    |> json(%{status: :error})
  end
end
