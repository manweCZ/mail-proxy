defmodule MailProxy.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MailProxyWeb.Telemetry,
      MailProxy.Repo,
      {DNSCluster, query: Application.get_env(:mail_proxy, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MailProxy.PubSub},
      # Start a worker by calling: MailProxy.Worker.start_link(arg)
      # {MailProxy.Worker, arg},
      # Start to serve requests, typically the last entry
      MailProxyWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MailProxy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MailProxyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
