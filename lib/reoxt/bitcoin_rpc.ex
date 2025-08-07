
defmodule Reoxt.BitcoinRPC do
  @moduledoc """
  GenServer for communicating with Bitcoin Core via RPC.
  """
  use GenServer
  require Logger

  @default_host "127.0.0.1"
  @default_port 8332
  @default_timeout 30_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def call_rpc(method, params \\ []) do
    GenServer.call(__MODULE__, {:rpc_call, method, params}, @default_timeout)
  end

  def get_transaction(txid) do
    call_rpc("getrawtransaction", [txid, true])
  end

  def get_block(block_hash) do
    call_rpc("getblock", [block_hash, 2])
  end

  def get_blockchain_info do
    call_rpc("getblockchaininfo")
  end

  @impl true
  def init(opts) do
    config = %{
      host: Keyword.get(opts, :host, @default_host),
      port: Keyword.get(opts, :port, @default_port),
      username: Keyword.get(opts, :username, Application.get_env(:reoxt, :bitcoin_rpc_user)),
      password: Keyword.get(opts, :password, Application.get_env(:reoxt, :bitcoin_rpc_password))
    }

    Logger.info("Starting Bitcoin RPC client: #{config.host}:#{config.port}")
    {:ok, config}
  end

  @impl true
  def handle_call({:rpc_call, method, params}, _from, config) do
    case make_rpc_request(config, method, params) do
      {:ok, result} ->
        {:reply, {:ok, result}, config}

      {:error, reason} ->
        Logger.error("RPC call failed: #{inspect(reason)}")
        {:reply, {:error, reason}, config}
    end
  end

  defp make_rpc_request(config, method, params) do
    url = "http://#{config.host}:#{config.port}/"
    
    payload = %{
      jsonrpc: "1.0",
      id: "reoxt",
      method: method,
      params: params
    }

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Basic #{Base.encode64("#{config.username}:#{config.password}")}"}
    ]

    case HTTPoison.post(url, Jason.encode!(payload), headers, timeout: @default_timeout) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"result" => result, "error" => nil}} ->
            {:ok, result}

          {:ok, %{"error" => error}} ->
            {:error, error}

          {:error, decode_error} ->
            {:error, "JSON decode error: #{inspect(decode_error)}"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "HTTP #{status_code}: #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end
end
