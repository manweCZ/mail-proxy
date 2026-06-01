defmodule MailProxyWeb.Router do
  use MailProxyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MailProxyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug MailProxyWeb.Plugs.Authorize
  end

  scope "/", MailProxyWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :dashboard do
      live "/dashboard", DashboardLive
    end
  end

  # Other scopes may use custom stacks.
  scope "/api/v1", MailProxyWeb do
    pipe_through :api

    post "/email", ApiMailController, :queue
  end

  import Phoenix.LiveDashboard.Router

  pipeline :admins_only do
    plug :basic_auth
  end

  defp basic_auth(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn,
      username: System.fetch_env!("BASIC_AUTH_USER"),
      password: System.fetch_env!("BASIC_AUTH_PASS")
    )
  end

  scope "/admin" do
    pipe_through [:browser, :admins_only]

    live_dashboard "/dashboard", metrics: MailProxyWeb.Telemetry
  end

  if Application.compile_env(:mail_proxy, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
