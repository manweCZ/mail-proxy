defmodule MailProxy.Mail.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mail_attachments" do
    field :desired_filename, :string
    field :url, :string

    belongs_to :job, MailProxy.Mail.Job

    timestamps()
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:job_id, :desired_filename, :url])
    |> validate_required([:job_id, :desired_filename, :url])
    |> assoc_constraint(:job)
  end
end
