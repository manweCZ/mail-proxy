defmodule MailProxy.Mail.Job do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending sending sent failed)

  schema "mail_jobs" do
    field :from, :string
    field :to, {:array, :string}, default: []
    field :cc, {:array, :string}, default: []
    field :bcc, {:array, :string}, default: []
    field :subject, :string
    field :body, :string
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :last_error, :string
    field :scheduled_at, :utc_datetime
    field :sent_at, :utc_datetime

    belongs_to :account, MailProxy.Accounts.Account
    has_many :attachments, MailProxy.Mail.Attachment

    timestamps()
  end

  @required ~w(account_id to subject body)a
  @optional ~w(from cc bcc status attempts last_error scheduled_at sent_at)a

  def changeset(job, attrs) do
    job
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:to, min: 1)
    |> assoc_constraint(:account)
  end

  def status_transition_changeset(job, new_status, extra \\ %{}) do
    job
    |> cast(Map.put(extra, :status, new_status), [:status, :last_error, :sent_at, :attempts])
    |> validate_inclusion(:status, @statuses)
  end
end
