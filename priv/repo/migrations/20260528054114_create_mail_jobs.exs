defmodule MailProxy.Repo.Migrations.CreateMailJobs do
  use Ecto.Migration

  def change do
    create table(:mail_jobs) do
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :from, :string, null: false
      add :to, {:array, :string}, null: false, default: []
      add :cc, {:array, :string}, null: false, default: []
      add :bcc, {:array, :string}, null: false, default: []
      add :subject, :string, null: false
      add :body, :text, null: false
      add :status, :string, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :last_error, :text
      add :scheduled_at, :utc_datetime
      add :sent_at, :utc_datetime

      timestamps()
    end

    create index(:mail_jobs, [:account_id])
    create index(:mail_jobs, [:status])
    create index(:mail_jobs, [:scheduled_at])
  end
end
