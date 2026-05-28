defmodule MailProxy.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :name, :string, null: false
      add :bearer_token, :string, null: false
      add :smtp_host, :string, null: false
      add :smtp_port, :integer, null: false, default: 587
      add :smtp_user, :string, null: false
      add :smtp_password, :string, null: false
      add :rate_limit_per_second, :decimal, null: false, default: 1
      add :webhook_url, :string

      timestamps()
    end

    create unique_index(:accounts, [:bearer_token])
  end
end
