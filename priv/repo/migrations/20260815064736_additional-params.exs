defmodule :"Elixir.MailProxy.Repo.Migrations.Additional-params" do
  use Ecto.Migration

  def change do
    alter table(:mail_jobs) do
      add :additional_headers, :map, null: true
    end
  end
end
