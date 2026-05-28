defmodule MailProxyWeb.PageController do
  use MailProxyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
