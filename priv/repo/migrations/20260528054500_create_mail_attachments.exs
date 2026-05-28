defmodule MailProxy.Repo.Migrations.CreateMailAttachments do
  use Ecto.Migration

  def change do
    create table(:mail_attachments) do
      add :job_id, references(:mail_jobs, on_delete: :delete_all), null: false
      add :desired_filename, :string, null: false
      add :url, :string, null: false

      timestamps()
    end

    create index(:mail_attachments, [:job_id])
  end
end
