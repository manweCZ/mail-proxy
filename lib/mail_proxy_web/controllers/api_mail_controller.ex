defmodule MailProxyWeb.ApiMailController do
  use MailProxyWeb, :controller

  def queue(%{assigns: %{account: %MailProxy.Accounts.Account{} = account}} = conn, args) do
    client_settings = %MailProxy.ClientSettings{} = MailProxy.ClientSettings.new(account)

    case MailProxy.ProxyServer.ensure_started(client_settings) do
      {:ok, _pid} ->
        from = args["from"] || client_settings.smtp_user
        resp =
          %MailProxy.Mail.Job{from: from, account_id: client_settings.account_id, status: "pending"}
          |> MailProxy.Mail.Job.changeset(args)
          |> MailProxy.Repo.insert()

        case resp do
          {:ok, job} ->
            MailProxy.ProxyServer.job_enqueued(client_settings.account_id)

            conn
            |> put_status(:accepted)
            |> json(%{job_id: job.id})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: MailProxyWeb.Helpers.format_errors(changeset)})
        end

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{status: :error, reason: inspect(reason)})
    end
  end

  def queue(conn, _args) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "unauthorized"})
  end
end
