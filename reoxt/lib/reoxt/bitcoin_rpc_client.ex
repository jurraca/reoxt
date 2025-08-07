
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

  @doc """
  Gets the latest block height
  """
  def get_best_block do
    GenServer.call(__MODULE__, :get_best_block)
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

  @impl true
  def handle_call(:get_best_block, _from, state) do
    result = rpc_call("getblockcount", [], state.config)
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
    
    auth = [username: config.username, password: config.password]
    
    body = %{
      "jsonrpc" => "1.0",
      "id" => "reoxt",
      "method" => method,
      "params" => params
    }

    case Req.post(url, 
                  json: body, 
                  auth: auth,
                  receive_timeout: 30_000) do
      {:ok, %{status: 200, body: response_body}} ->
        case response_body do
          %{"error" => nil, "result" => result} ->
            {:ok, result}
          %{"error" => error} ->
            {:error, error}
          _ ->
            {:error, {:invalid_response, response_body}}
        end

      {:ok, %{status: status_code, body: body}} ->
        {:error, {:http_error, status_code, body}}

      {:error, reason} ->
        {:error, {:connection_error, reason}}
    end
  end
end
