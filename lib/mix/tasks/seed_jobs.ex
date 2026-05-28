defmodule Mix.Tasks.SeedJobs do
  use Mix.Task

  import Ecto.Query

  alias MailProxy.Accounts.Account
  alias MailProxy.Mail.Job
  alias MailProxy.Repo

  @shortdoc "Seeds the database with 3 test jobs for radek@biteit.cz"

  @words ~w(apple banana cherry delta echo foxtrot gamma hotel igloo jungle kilo lima mango)

  def run(_args) do
    Mix.Task.run("app.start")

    account = Repo.one(from a in Account, limit: 1)

    if is_nil(account) do
      Mix.shell().error("No accounts found. Create an account first.")
    else
      Enum.each(1..3, fn i ->
        attrs = %{
          account_id: account.id,
          from: account.smtp_user,
          to: ["radek@biteit.cz"],
          subject: "Test e-mail",
          body: random_body()
        }

        case Repo.insert(Job.changeset(%Job{}, attrs)) do
          {:ok, job} -> Mix.shell().info("Created job ##{i} id=#{job.id}")
          {:error, cs} -> Mix.shell().error("Failed job ##{i}: #{inspect(cs.errors)}")
        end
      end)
    end
  end

  defp random_body do
    @words
    |> Enum.shuffle()
    |> Enum.take(8)
    |> Enum.join(" ")
    |> String.capitalize()
    |> then(&"#{&1}.")
  end
end
