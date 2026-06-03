defmodule MailProxy.Release do
  def migrate do
    Application.load(:mail_proxy)
    {:ok, _, _} = Ecto.Migrator.with_repo(MailProxy.Repo, &Ecto.Migrator.run(&1, :up, all: true))
  end
end
