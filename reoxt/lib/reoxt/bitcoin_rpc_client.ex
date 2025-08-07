
defmodule Reoxt.BitcoinRpcClient do
  use GenServer
  require Logger
  alias Reoxt.Analyzer

  @doc """
  Starts the Bitcoin RPC client GenServer
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Fetches a transaction by TXID
  """
  def get_transaction(txid) do
    GenServer.call(__MODULE__, {:get_transaction, txid})
  end

  @doc """
  Fetches a block by height
  """
  def get_block(height) when is_integer(height) do
    GenServer.call(__MODULE__, {:get_block_by_height, height})
  end

  @doc """
  Fetches a block by hash
  """
  def get_block(hash) when is_binary(hash) do
    GenServer.call(__MODULE__, {:get_block_by_hash, hash})
  end

  @doc """
  Gets the current blockchain info
  """
  def get_blockchain_info do
    GenServer.call(__MODULE__, :get_blockchain_info)
  end

  @doc """
  Gets the best block hash
  """
  def get_best_block_hash do
    GenServer.call(__MODULE__, :get_best_block_hash)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{config: get_rpc_config()}}
  end

  @impl true
  def handle_call({:get_transaction, txid}, _from, state) do
    result = rpc_call("getrawtransaction", [txid, true], state.config)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_block_by_height, height}, _from, state) do
    with {:ok, hash} <- rpc_call("getblockhash", [height], state.config),
         {:ok, block} <- rpc_call("getblock", [hash, 2], state.config) do
      {:reply, {:ok, block}, state}
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_block_by_hash, hash}, _from, state) do
    result = rpc_call("getblock", [hash, 2], state.config)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_blockchain_info, _from, state) do
    result = rpc_call("getblockchaininfo", [], state.config)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_best_block_hash, _from, state) do
    result = rpc_call("getbestblockhash", [], state.config)
    {:reply, result, state}
  end

  ## Private Functions

  defp get_rpc_config do
    case Analyzer.list_bitcoin_rpc_configs() |> List.first() do
      nil ->
        Logger.warn("No Bitcoin RPC configuration found. Please add one.")
        %{host: "localhost", port: 8332, username: "", password: ""}
      
      config ->
        %{
          host: config.host,
          port: config.port,
          username: config.username,
          password: config.password
        }
    end
  end

  defp rpc_call(method, params, config) do
    url = "http://#{config.host}:#{config.port}/"
    
    auth_header = "Basic " <> Base.encode64("#{config.username}:#{config.password}")
    
    body = Jason.encode!(%{
      "jsonrpc" => "1.0",
      "id" => "reoxt",
      "method" => method,
      "params" => params
    })

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", auth_header}
    ]

    case HTTPoison.post(url, body, headers, recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"error" => nil, "result" => result}} ->
            {:ok, result}
          {:ok, %{"error" => error}} ->
            {:error, error}
          {:error, decode_error} ->
            {:error, {:json_decode_error, decode_error}}
        end

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, {:http_error, status_code, body}}

      {:error, %{reason: reason}} ->
        {:error, {:connection_error, reason}}
    end
  end
end
