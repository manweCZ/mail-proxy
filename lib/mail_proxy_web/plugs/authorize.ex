defmodule MailProxyWeb.Plugs.Authorize do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def init(default), do: default

  def call(conn, _default) do
    IO.puts("authorizing")
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
      %MailProxy.Accounts.Account{} = account <- MailProxy.Repo.get_by(MailProxy.Accounts.Account, bearer_token: token) do

      assign(conn, :account, account)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})
        |> halt()
    end
  end
end
