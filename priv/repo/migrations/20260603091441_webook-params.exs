defmodule Elixir.MailProxy.Repo.Migrations.WebookParams do
  use Ecto.Migration

  def change do
    alter table(:mail_jobs) do
      add :webhook_params, :map, null: true
    end
  end

end
