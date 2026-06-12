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
    field :webhook_params, :map

    belongs_to :account, MailProxy.Accounts.Account
    has_many :attachments, MailProxy.Mail.Attachment

    timestamps()
  end

  @required ~w(account_id to subject body)a
  @optional ~w(from cc bcc status attempts last_error scheduled_at sent_at webhook_params)a

  def changeset(job, attrs) do
    job
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
    |> validate_to_present()
    |> assoc_constraint(:account)
  end

  defp validate_to_present(changeset) do
    case get_field(changeset, :to) do
      [] -> add_error(changeset, :to, "can't be blank")
      _ -> changeset
    end
  end

  def status_transition_changeset(job, new_status, extra \\ %{}) do
    job
    |> cast(Map.put(extra, :status, new_status), [:status, :last_error, :sent_at, :attempts, :scheduled_at])
    |> validate_inclusion(:status, @statuses)
  end
end
