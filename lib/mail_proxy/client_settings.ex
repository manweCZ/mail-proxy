defmodule MailProxy.ClientSettings do
  @moduledoc """
  Represents the runtime configuration for a proxy client, derived from an Account.
  """

  alias MailProxy.Accounts.Account

  @type t :: %__MODULE__{
          account_id: integer(),
          name: String.t(),
          bearer_token: String.t(),
          smtp_host: String.t(),
          smtp_port: integer(),
          smtp_user: String.t(),
          smtp_password: String.t(),
          rate_limit_per_second: Decimal.t(),
          webhook_url: String.t() | nil
        }

  defstruct [
    :account_id,
    :name,
    :bearer_token,
    :smtp_host,
    :smtp_user,
    :smtp_password,
    :webhook_url,
    smtp_port: 587,
    rate_limit_per_second: 1
  ]

  @spec new(Account.t() | map()) :: t()
  def new(%Account{} = account) do
    %__MODULE__{
      account_id: account.id,
      name: account.name,
      bearer_token: account.bearer_token,
      smtp_host: account.smtp_host,
      smtp_port: account.smtp_port,
      smtp_user: account.smtp_user,
      smtp_password: account.smtp_password,
      rate_limit_per_second: account.rate_limit_per_second,
      webhook_url: account.webhook_url
    }
  end

  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      account_id: attrs[:account_id] || attrs["account_id"],
      name: attrs[:name] || attrs["name"],
      bearer_token: attrs[:bearer_token] || attrs["bearer_token"],
      smtp_host: attrs[:smtp_host] || attrs["smtp_host"],
      smtp_port: attrs[:smtp_port] || attrs["smtp_port"] || 587,
      smtp_user: attrs[:smtp_user] || attrs["smtp_user"],
      smtp_password: attrs[:smtp_password] || attrs["smtp_password"],
      rate_limit_per_second: attrs[:rate_limit_per_second] || attrs["rate_limit_per_second"] || 1,
      webhook_url: attrs[:webhook_url] || attrs["webhook_url"]
    }
  end
end
