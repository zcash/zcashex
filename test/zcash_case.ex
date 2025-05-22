defmodule ZcashexCase do
  @moduledoc """
  Test Case and helpers for testing Zcashex.
  """

  use ExUnit.CaseTemplate

  alias Zcashex

  setup_all do
    host = System.get_env("zcashd_hostname") || "localhost"
    port = System.get_env("rpc_port") || Application.get_env(:zcashex, :rpc_port, 18347) # More flexible port
    username = System.get_env("rpc_username") || Application.get_env(:zcashex, :rpc_username, "zcashrpc")
    password = System.get_env("rpc_password") || Application.get_env(:zcashex, :rpc_password, "notsecure")

    child_spec = %{
      id: Zcashex,
      start: {Zcashex, :start_link, [host, port, username, password]}
    }

    # Attempt to stop and remove the supervisor if it exists from a previous unclean run
    # This is a band-aid for local test runs; CI environments are usually clean.
    case Supervisor.whereis(Zcashex.Supervisor) do
      pid when is_pid(pid) ->
        Supervisor.stop(pid, :shutdown, 10_000) # 10 seconds timeout
        Process.sleep(100) # Give it a moment to release resources
      _ ->
        :ok
    end

    # Start the Zcashex client process
    # The test process will link to this client. If the client crashes, the test will fail.
    # If the test process crashes, the client will be terminated due to the link.
    with {:ok, client_pid} <- Zcashex.start_link(host, port, username, password) do
      # Generate a common set of blocks for tests
      # This assumes the zcashd node is in a fresh regtest state at the start of the test suite
      initial_block_generation_count = 20
      case Zcashex.generate(initial_block_generation_count) do
        {:ok, generated_hashes} ->
          # IO.puts("Successfully generated #{length(generated_hashes)} blocks in ZcashexCase setup_all.")
          {:ok, client: client_pid, initial_blocks_generated: initial_block_generation_count}
        {:error, reason} ->
          IO.puts(:stderr, "Failed to generate initial blocks in ZcashexCase setup_all: #{inspect(reason)}")
          # Fail setup_all if blocks can't be generated, as tests will likely fail.
          {:error, "Failed to generate initial blocks: #{inspect(reason)}"}
      end
    else
      error ->
         IO.puts(:stderr, "Failed to start Zcashex client in ZcashexCase setup_all: #{inspect(error)}")
        {:error, "Failed to start Zcashex client: #{inspect(error)}"}

    end
  end
end
