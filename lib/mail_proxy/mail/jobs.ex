defmodule MailProxy.Mail.Jobs do
  import Ecto.Query

  alias MailProxy.Mail.Attachment
  alias MailProxy.Mail.Job
  alias MailProxy.Repo

  @max_attempts 3

  @doc """
  Fetches up to `limit` pending jobs for the given account that are ready to run
  (no scheduled_at, or scheduled_at is in the past), atomically marking them as
  `sending` to prevent double-processing across ticks or restarts.
  """
  @spec fetch_pending(integer(), integer()) :: [Job.t()]
  def fetch_pending(account_id, limit) do
    now = DateTime.utc_now()

    {:ok, jobs} =
      Repo.transaction(fn ->
        jobs =
          from(j in Job,
            where:
              j.account_id == ^account_id and
              j.status == "pending" and
              (is_nil(j.scheduled_at) or j.scheduled_at <= ^now),
            order_by: [asc: j.inserted_at],
            limit: ^limit,
            lock: "FOR UPDATE SKIP LOCKED"
          )
          |> Repo.all()

        ids = Enum.map(jobs, & &1.id)

        from(j in Job, where: j.id in ^ids)
        |> Repo.update_all(set: [status: "sending"])

        jobs
      end)

    jobs
  end

  @spec mark_sent(Job.t()) :: Job.t()
  def mark_sent(%Job{} = job) do
    updated = job
      |> Job.status_transition_changeset("sent", %{sent_at: DateTime.utc_now()})
      |> Repo.update!()
    clear_attachment_data(job.id)
    updated
  end

  @spec mark_failed(Job.t(), String.t(), integer()) :: Job.t()
  def mark_failed(%Job{} = job, reason, attempts) do
    updated = job
      |> Job.status_transition_changeset("failed", %{last_error: reason, attempts: attempts})
      |> Repo.update!()
    clear_attachment_data(job.id)
    updated
  end

  @spec reschedule(Job.t(), String.t(), integer()) :: Job.t()
  def reschedule(%Job{} = job, reason, attempts) do
    backoff_secs = trunc(:math.pow(2, attempts)) * 60
    scheduled_at = DateTime.add(DateTime.utc_now(), backoff_secs, :second)

    job
    |> Job.status_transition_changeset("pending", %{
      last_error: reason,
      attempts: attempts,
      scheduled_at: scheduled_at
    })
    |> Repo.update!()
  end

  @spec max_attempts() :: integer()
  def max_attempts, do: @max_attempts

  @spec reset_to_pending(integer()) :: :ok
  def reset_to_pending(job_id) do
    from(j in Job, where: j.id == ^job_id and j.status == "sending")
    |> Repo.update_all(set: [status: "pending"])

    :ok
  end

  defp clear_attachment_data(job_id) do
    from(a in Attachment, where: a.job_id == ^job_id)
    |> Repo.update_all(set: [data: nil])
  end

  @spec reset_stuck_sending(integer(), integer()) :: non_neg_integer()
  def reset_stuck_sending(account_id, older_than_secs \\ 300) do
    cutoff = DateTime.add(DateTime.utc_now(), -older_than_secs, :second)

    {count, _} =
      from(j in Job,
        where:
          j.account_id == ^account_id and
          j.status == "sending" and
          j.updated_at < ^cutoff
      )
      |> Repo.update_all(set: [status: "pending"])

    count
  end
end
