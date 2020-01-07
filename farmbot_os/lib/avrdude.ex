defmodule Avrdude do
  @moduledoc """
  It's AVR, my dudes.
  """

  defmodule MuonTrapAdapter do
    @type exe :: String.t()
    @type args :: [String.t()
    @type io_stream :: Enumerable.t()
    @type option :: {:into, io_stream()} | {:stderr_to_stdout, boolean()}

    @callback cmd(exe, args, list(option))

    @doc false
    def adapter do
      Application.fetch_env!(:farmbot, :muon_trap_adapter, MuonTrapDefaultAdapter)
    end

    def cmd(exe, args, options) do
      adapter().cmd(exe, args, options)
    end
  end

  defmodule MuonTrapDefaultAdapter do
    @behaviour AvrdudeAdapter

    @impl AvrdudeAdapter
    defdelegate cmd(exe, args, options), to: MuonTrap, :cmd
  end


  @uart_speed 115_200
  require FarmbotCore.Logger

  @spec flash(Path.t(), Path.t(), (() -> :ok)) :: {number, any()}
  def flash(hex_path, tty_path, reset_fun) do
    tty_path =
      if String.contains?(tty_path, "/dev") do
        tty_path
      else
        "/dev/#{tty_path}"
      end

    _ = File.stat!(hex_path)

    # STEP 1: Is the UART in use?
    args = [
      "-patmega2560",
      "-cwiring",
      "-P#{tty_path}",
      "-b#{@uart_speed}",
      "-D",
      "-V",
      "-Uflash:w:#{hex_path}:i"
    ]

    # call the function for resetting the line before executing avrdude.
    call_reset_fun(reset_fun)
    MuonTrapAdapter.cmd("avrdude", args, into: IO.stream(:stdio, :line), stderr_to_stdout: true)
  end

  def call_reset_fun(reset_fun) do
    try do
      reset_fun.()
    catch
      error_type, error ->
        FarmbotCore.Logger.error(1, """
        Error calling reset function: #{inspect(reset_fun)}
        error type: #{error_type}
        error: #{inspect(error)}
        """)
    end
  end

  :ok
end
