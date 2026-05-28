defmodule MailProxy.ProxyServer do
  use GenServer

  alias MailProxy.ClientSettings
  alias MailProxy.Mail.Jobs

  @tick_rate 1000

  @moduledoc """

  """

  defstruct [
    :client_settings,
    :current_tokens,
    :max_tokens,
    :refill_rate
  ]

  ## Types

  @type state :: %__MODULE__{}

  ## Client API

  @spec start_link(ClientSettings.t()) :: GenServer.on_start()
  def start_link(%ClientSettings{} = client_settings) do
    GenServer.start_link(__MODULE__, client_settings, name: __MODULE__)
  end

  @spec get_state() :: state()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  ## Server Callbacks

  @impl true
  def init(%ClientSettings{} = client_settings) do
    rate = Decimal.to_float(client_settings.rate_limit_per_second)
    refill_rate = Float.round(rate * 1000 / @tick_rate, 2)
    max_tokens = rate

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
  def handle_info(:tick, state) do
    state =
      state
      |> refill_tokens()
      |> drain_queue()

    schedule_tick()
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private

  defp refill_tokens(state) do
    %{state | current_tokens: min(state.current_tokens + state.refill_rate, state.max_tokens)}
  end

  defp drain_queue(state) do
    slots = floor(state.current_tokens)

    if slots >= 1 do
      jobs = Jobs.fetch_pending(state.client_settings.account_id, slots)

      Enum.each(jobs, fn job ->
        Task.start(fn -> IO.puts("Sending email job_id=#{job.id} to=#{Enum.join(job.to, ",")}") end)
      end)

      %{state | current_tokens: state.current_tokens - length(jobs)}
    else
      state
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_rate)
  end
end
