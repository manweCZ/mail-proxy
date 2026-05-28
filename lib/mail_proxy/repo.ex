defmodule MailProxy.Repo do
  use Ecto.Repo,
    otp_app: :mail_proxy,
    adapter: Ecto.Adapters.Postgres
end
