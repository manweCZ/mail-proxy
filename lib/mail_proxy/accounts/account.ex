defmodule MailProxy.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :name, :string
    field :bearer_token, :string
    field :smtp_host, :string
    field :smtp_port, :integer, default: 587
    field :smtp_user, :string
    field :smtp_password, :string
    field :rate_limit_per_second, :decimal, default: 1
    field :webhook_url, :string

    has_many :mail_jobs, MailProxy.Mail.Job

    timestamps()
  end

  @required ~w(name bearer_token smtp_host smtp_port smtp_user smtp_password rate_limit_per_second)a
  @optional ~w(webhook_url)a

  def changeset(account, attrs) do
    account
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:smtp_port, greater_than: 0, less_than_or_equal_to: 65535)
    |> validate_number(:rate_limit_per_second, greater_than: 0)
    |> unique_constraint(:bearer_token)
  end
end
