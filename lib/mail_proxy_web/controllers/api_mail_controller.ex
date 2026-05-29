defmodule MailProxyWeb.ApiMailController do
  use MailProxyWeb, :controller

  alias MailProxy.Accounts.Account
  alias MailProxy.ClientSettings
  alias MailProxy.Mail.Attachment
  alias MailProxy.Mail.Job
  alias MailProxy.ProxyServer
  alias MailProxy.Repo
  alias MailProxyWeb.Helpers

  def queue(%{assigns: %{account: %Account{} = account}} = conn, args) do
    client_settings = %ClientSettings{} = ClientSettings.new(account)

    case ProxyServer.ensure_started(client_settings) do
      {:ok, _pid} ->
        from = args["from"] || client_settings.smtp_user
        attachment_params = args["attachments"] || []

        result =
          Repo.transaction(fn ->
            job_cs =
              %Job{from: from, account_id: client_settings.account_id, status: "pending"}
              |> Job.changeset(args)

            case Repo.insert(job_cs) do
              {:ok, job} ->
                case insert_attachments(job.id, attachment_params) do
                  :ok -> job
                  {:error, reason} -> Repo.rollback(reason)
                end

              {:error, changeset} ->
                Repo.rollback(changeset)
            end
          end)

        case result do
          {:ok, job} ->
            ProxyServer.job_enqueued(client_settings.account_id)
            conn |> put_status(:accepted) |> json(%{job_id: job.id})

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: Helpers.format_errors(changeset)})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: inspect(reason)})
        end

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{status: :error, reason: inspect(reason)})
    end
  end

  def queue(conn, _args) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "unauthorized"})
  end

  defp insert_attachments(_job_id, []), do: :ok

  defp insert_attachments(job_id, params) do
    Enum.reduce_while(params, :ok, fn param, _acc ->
      case build_attachment_attrs(job_id, param) do
        {:ok, attrs} ->
          cs = Attachment.changeset(%Attachment{}, attrs)

          case Repo.insert(cs) do
            {:ok, _} -> {:cont, :ok}
            {:error, cs} -> {:halt, {:error, cs}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp build_attachment_attrs(job_id, param) do
    filename = param["filename"]
    content_type = param["content_type"] || MIME.from_path(filename || "")

    if is_nil(filename) do
      {:error, "attachment missing filename"}
    else
      base = %{job_id: job_id, desired_filename: filename, content_type: content_type}

      cond do
        raw = param["data"] ->
          case Base.decode64(String.replace(raw, "\n", "")) do
            {:ok, binary} -> {:ok, Map.put(base, :data, binary)}
            :error -> {:error, "invalid base64 data for attachment #{filename}"}
          end

        url = param["url"] ->
          {:ok, Map.put(base, :url, url)}

        true ->
          {:error, "attachment #{filename} must have either data or url"}
      end
    end
  end
end
