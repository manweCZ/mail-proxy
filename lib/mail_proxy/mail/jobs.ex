defmodule MailProxy.Mail.Jobs do
  import Ecto.Query

  alias MailProxy.Mail.Job
  alias MailProxy.Repo

  @doc """
  Fetches up to `limit` pending jobs for the given account, atomically marking
  them as `sending` to prevent double-processing across ticks or restarts.
  """
  @spec fetch_pending(integer(), integer()) :: [Job.t()]
  def fetch_pending(account_id, limit) do
    {:ok, jobs} =
      Repo.transaction(fn ->
        jobs =
          from(j in Job,
            where: j.account_id == ^account_id and j.status == "pending",
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

  @spec reset_to_pending(integer()) :: :ok
  def reset_to_pending(job_id) do
    from(j in Job, where: j.id == ^job_id and j.status == "sending")
    |> Repo.update_all(set: [status: "pending"])

    :ok
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
