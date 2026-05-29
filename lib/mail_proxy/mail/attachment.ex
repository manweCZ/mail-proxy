defmodule MailProxy.Mail.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mail_attachments" do
    field :desired_filename, :string
    field :content_type, :string
    field :url, :string
    field :data, :binary

    belongs_to :job, MailProxy.Mail.Job

    timestamps()
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:job_id, :desired_filename, :content_type, :url, :data])
    |> validate_required([:job_id, :desired_filename, :content_type])
    |> validate_url_or_data()
    |> assoc_constraint(:job)
  end

  defp validate_url_or_data(changeset) do
    url = get_field(changeset, :url)
    data = get_field(changeset, :data)

    if is_nil(url) and is_nil(data) do
      add_error(changeset, :base, "attachment must have either url or data")
    else
      changeset
    end
  end
end
