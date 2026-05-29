defmodule MailProxy.ProxyServer do
  use GenServer

  alias MailProxy.ClientSettings
  alias MailProxy.Mail.Jobs
  alias MailProxy.Mail.Sender

  @tick_rate 1000

  @moduledoc """

  """

  defstruct [
    :client_settings,
    :current_tokens,
    :max_tokens,
    :refill_rate,
    tasks: %{}
  ]

  ## Types

  @type state :: %__MODULE__{}

  ## Client API

  @spec start_link(ClientSettings.t()) :: GenServer.on_start()
  def start_link(%ClientSettings{} = client_settings) do
    GenServer.start_link(__MODULE__, client_settings, name: via(client_settings.account_id))
  end

  @spec ensure_started(ClientSettings.t()) :: {:ok, pid()} | {:error, term()}
  def ensure_started(%ClientSettings{} = client_settings) do
    case DynamicSupervisor.start_child(MailProxy.ProxySupervisor, {__MODULE__, client_settings}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec get_state(integer()) :: state()
  def get_state(account_id) do
    GenServer.call(via(account_id), :get_state)
  end

  @spec job_enqueued(integer()) :: :ok
  def job_enqueued(account_id) do
    GenServer.cast(via(account_id), :job_enqueued)
  end

  @spec job_done(integer(), integer()) :: :ok
  def job_done(account_id, job_id) do
    GenServer.cast(via(account_id), {:job_done, job_id})
  end

  defp via(account_id) do
    {:via, Registry, {MailProxy.ProxyRegistry, {__MODULE__, account_id}}}
  end

  defp me(), do: self() |> :erlang.pid_to_list() |> to_string()
  ## Server Callbacks

  @impl true
  def init(%ClientSettings{} = client_settings) do
    rate = Decimal.to_float(client_settings.rate_limit_per_second)
    refill_rate = Float.round(rate * 1000 / @tick_rate, 2)
    max_tokens = 1

    schedule_tick()

    {:ok, %__MODULE__{
      client_settings: client_settings,
      max_tokens: max_tokens,
      current_tokens: max_tokens,
      refill_rate: refill_rate
    }}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:job_enqueued, state) do
    {:noreply, drain_queue(state)}
  end

  def handle_cast({:job_done, _job_id}, state) do
    {:noreply, drain_queue(state)}
  end

  @impl true
  def handle_info(:tick, state) do
    state =
      state
      |> refill_tokens()
      |> drain_queue()

    schedule_tick()
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    {job_id, tasks} = Map.pop(state.tasks, ref)

    if job_id && reason != :normal do
      Jobs.reset_to_pending(job_id)
    end

    {:noreply, %{state | tasks: tasks}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private

  defp refill_tokens(state) do
    %{state | current_tokens: min(state.current_tokens + state.refill_rate, state.max_tokens)}
  end

  defp drain_queue(%__MODULE__{} = state) do
    Jobs.reset_stuck_sending(state.client_settings.account_id)
    slots = floor(state.current_tokens)
    IO.puts("#{me()}: #{state.current_tokens} / #{state.max_tokens} / #{state.refill_rate}")
    if slots >= 1 do
      jobs = Jobs.fetch_pending(state.client_settings.account_id, slots)

      new_tasks =
        Enum.reduce(jobs, state.tasks, fn job, tasks ->
          {:ok, pid} = Task.Supervisor.start_child(MailProxy.WorkerSupervisor, fn ->
            Sender.send(job)
          end)
          ref = Process.monitor(pid)
          Map.put(tasks, ref, job.id)
        end)

      %{state | current_tokens: state.current_tokens - length(jobs), tasks: new_tasks}
    else
      state
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_rate)
  end
end
