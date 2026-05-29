defmodule MailProxy.Mail.Sender do
  import Swoosh.Email

  alias MailProxy.Accounts.Account
  alias MailProxy.Mail.Job
  alias MailProxy.Mail.Jobs
  alias MailProxy.Mailer
  alias MailProxy.ProxyServer
  alias MailProxy.Repo

  @spec send(Job.t()) :: :ok | {:error, term()}
  def send(%Job{} = job) do
    %{account: account} = Repo.preload(job, :account)

    try do
      do_send(job, account)
    rescue
      e ->
        handle_failure(job, account, Exception.message(e))
        {:error, e}
    end
  end

  defp do_send(job, account) do
    email =
      new()
      |> from(job.from)
      |> to(job.to)
      |> cc(job.cc)
      |> bcc(job.bcc)
      |> subject(job.subject)
      |> html_body(job.body)

    case Mailer.deliver(email, smtp_config(account)) do
      {:ok, _} ->
        Jobs.mark_sent(job)
        fire_webhook(account, job, "sent", job.attempts)
        ProxyServer.job_done(account.id, job.id)
        :ok

      {:error, reason} ->
        handle_failure(job, account, inspect(reason))
        {:error, reason}
    end
  end

  defp handle_failure(job, account, reason) do
    new_attempts = job.attempts + 1

    if new_attempts < Jobs.max_attempts() do
      Jobs.reschedule(job, reason, new_attempts)
    else
      Jobs.mark_failed(job, reason, new_attempts)
      fire_webhook(account, job, "failed", new_attempts)
    end
  end

  defp fire_webhook(%Account{webhook_url: nil}, _job, _status, _attempts), do: :ok
  defp fire_webhook(%Account{webhook_url: url}, job, status, attempts) do
    Task.start(fn ->
      Req.post(url, json: %{
        job_id: job.id,
        status: status,
        to: job.to,
        attempts: attempts
      })
    end)
  end

  defp smtp_config(account) do
    tls_opts = tls_for_port(account.smtp_port)

    [
      adapter: Swoosh.Adapters.SMTP,
      relay: account.smtp_host,
      port: account.smtp_port,
      username: account.smtp_user,
      password: account.smtp_password,
      auth: :always
    ] ++ tls_opts
  end

  defp tls_for_port(465), do: [ssl: true, tls_options: [verify: :verify_none]]
  defp tls_for_port(587), do: [tls: :always, tls_options: [verify: :verify_none]]
  defp tls_for_port(_),   do: [tls: :if_available, tls_options: [verify: :verify_none]]
end
