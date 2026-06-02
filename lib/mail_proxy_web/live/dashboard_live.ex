defmodule MailProxyWeb.DashboardLive do
  use MailProxyWeb, :live_view

  import Ecto.Query

  alias MailProxy.Accounts.Account
  alias MailProxy.Mail.Job
  alias MailProxy.Repo

  @refresh_interval 5_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()
    {:ok, assign(socket, :accounts, fetch_accounts())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()
    {:noreply, assign(socket, :accounts, fetch_accounts())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="page-heading">
        <h1>Mail Proxy</h1>
        <p>Auto-refreshes every 5 seconds</p>
      </div>

      <div class="account-grid">
        <%= for account <- @accounts do %>
          <div class="account-card">
            <div class="card-header">
              <h3>{account.name}</h3>
            </div>

            <div class="card-stats">
              <div class="stat-item">
                <p class="stat-number sent">{account.total_sent}</p>
                <p class="stat-label">Sent</p>
              </div>
              <div class="stat-item">
                <p class="stat-number failed">{account.total_failed}</p>
                <p class="stat-label">Failed</p>
              </div>
              <div class="stat-item">
                <p class="stat-number pending">{account.total_pending}</p>
                <p class="stat-label">Pending</p>
              </div>
            </div>

            <div class="card-jobs">
              <p class="jobs-title">Recent</p>
              <%= if account.recent_jobs == [] do %>
                <p class="jobs-empty">No jobs yet</p>
              <% else %>
                <ul class="jobs-list">
                  <%= for job <- account.recent_jobs do %>
                    <li class="job-item">
                      <span class={"job-dot #{job.status}"}></span>
                      <div class="job-info">
                        <span class="job-recipient">{Enum.at(job.to, 0)}</span>
                        <span class="job-subject">{String.slice(job.subject || "", 0, 50)}</span>
                      </div>
                      <span
                        class="job-time"
                        id={"time-#{job.id}"}
                        phx-hook=".LocalTime"
                        data-utc={NaiveDateTime.to_iso8601(job.inserted_at) <> "Z"}
                      >{Calendar.strftime(job.inserted_at, "%d %b %H:%M")} UTC</span>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".LocalTime">
      export default {
        mounted()  { this.format() },
        updated()  { this.format() },
        format() {
          const d = new Date(this.el.dataset.utc)
          this.el.textContent = d.toLocaleString([], {day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit"})
        }
      }
    </script>
    """
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp fetch_accounts do
    summaries = fetch_summaries()

    Enum.map(summaries, fn summary ->
      jobs =
        from(j in Job,
          where: j.account_id == ^summary.id,
          order_by: [desc: j.inserted_at],
          limit: 5
        )
        |> Repo.all()

      Map.put(summary, :recent_jobs, jobs)
    end)
  end

  defp fetch_summaries do
    from(a in Account,
      left_join: j in Job, on: j.account_id == a.id,
      group_by: [a.id, a.name],
      select: %{
        id: a.id,
        name: a.name,
        total_sent: count(fragment("CASE WHEN ? = 'sent' THEN 1 END", j.status)),
        total_failed: count(fragment("CASE WHEN ? = 'failed' THEN 1 END", j.status)),
        total_pending: count(fragment("CASE WHEN ? = 'pending' THEN 1 END", j.status))
      },
      order_by: a.name
    )
    |> Repo.all()
  end
end
