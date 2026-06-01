defmodule MailProxy.Release do
  def migrate do
    {:ok, _} = Application.ensure_all_started(:mail_proxy)
    path = Application.app_dir(:mail_proxy, "priv/repo/migrations")
    Ecto.Migrator.run(MailProxy.Repo, path, :up, all: true)
  end
end
