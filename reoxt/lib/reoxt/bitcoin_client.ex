defmodule Reoxt.BitcoinClient do
  use GenServer
  require Logger
  alias Reoxt.Transactions

  @doc """
  Starts the Bitcoin client GenServer
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Fetches and stores a transaction by TXID
  """
  def fetch_transaction(txid) do
    GenServer.cast(__MODULE__, {:fetch_transaction, txid})
  end

  @doc """
  Fetches and stores all transactions from a block
  """
  def fetch_block_transactions(block_height_or_hash) do
    GenServer.cast(__MODULE__, {:fetch_block_transactions, block_height_or_hash})
  end

  @doc """
  Starts fetching recent blocks
  """
  def start_fetching_recent_blocks(count \\ 10) do
    GenServer.cast(__MODULE__, {:fetch_recent_blocks, count})
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    case Gold.new(:localnode) do
      {:ok, client} -> {:ok, %{client: client}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_cast({:fetch_transaction, txid}, state) do
    Task.start(fn -> do_fetch_transaction(state.client, txid) end)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:fetch_block_transactions, block_identifier}, state) do
    Task.start(fn -> do_fetch_block_transactions(state.client, block_identifier) end)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:fetch_recent_blocks, count}, state) do
    Task.start(fn -> do_fetch_recent_blocks(state.client, count) end)
    {:noreply, state}
  end

  ## Private Functions

  defp do_fetch_transaction(client, txid) do
    case Transactions.get_transaction_by_txid(txid) do
      nil ->
        case Gold.getrawtransaction(client, txid, verbose: true) do
          {:ok, tx_data} ->
            store_transaction(tx_data)
            Logger.info("Fetched and stored transaction: #{txid}")

          {:error, reason} ->
            Logger.error("Failed to fetch transaction #{txid}: #{inspect(reason)}")
        end

      _existing ->
        Logger.debug("Transaction #{txid} already exists in database")
    end
  end

  defp do_fetch_block_transactions(client, block_identifier) do
    case Gold.getblock(client, block_identifier) do
      {:ok, block_data} ->
        block_height = block_data["height"]
        transactions = block_data["tx"] || []

        Logger.info("Fetching #{length(transactions)} transactions from block #{block_height}")

        Enum.each(transactions, fn tx_data ->
          store_transaction(tx_data, block_height)
        end)

        Logger.info("Completed fetching transactions from block #{block_height}")

      {:error, reason} ->
        Logger.error("Failed to fetch block #{block_identifier}: #{inspect(reason)}")
    end
  end

  defp do_fetch_recent_blocks(client, count) do
    case Gold.getblockchaininfo(client) do
      {:ok, info} ->
        current_height = info["blocks"]
        start_height = max(0, current_height - count + 1)

        Logger.info("Fetching blocks from #{start_height} to #{current_height}")

        start_height..current_height
        |> Enum.each(fn height ->
          do_fetch_block_transactions(client, height)
          # Small delay to avoid overwhelming the Bitcoin node
          Process.sleep(100)
        end)

      {:error, reason} ->
        Logger.error("Failed to get blockchain info: #{inspect(reason)}")
    end
  end

  defp store_transaction(tx_data, block_height \\ nil) do
    txid = tx_data["txid"]

    # Check if transaction already exists
    case Transactions.get_transaction_by_txid(txid) do
      nil ->
        # Parse transaction data
        transaction_attrs = parse_transaction_data(tx_data, block_height)
        inputs_data = parse_inputs_data(tx_data["vin"] || [])
        outputs_data = parse_outputs_data(tx_data["vout"] || [])

        # Store in database
        case Transactions.create_transaction_with_details(
               transaction_attrs,
               inputs_data,
               outputs_data
             ) do
          {:ok, _transaction} ->
            Logger.debug("Successfully stored transaction: #{txid}")

          {:error, reason} ->
            Logger.error("Failed to store transaction #{txid}: #{inspect(reason)}")
        end

      _existing ->
        Logger.debug("Transaction #{txid} already exists")
    end
  end

  defp parse_transaction_data(tx_data, block_height) do
    %{
      txid: tx_data["txid"],
      block_height: block_height || tx_data["blockheight"] || 0,
      timestamp: parse_timestamp(tx_data["blocktime"] || tx_data["time"]),
      fee: calculate_fee(tx_data),
      size: tx_data["size"] || 0,
      version: tx_data["version"] || 1,
      locktime: tx_data["locktime"] || 0
    }
  end

  defp parse_inputs_data(vin_data) do
    Enum.with_index(vin_data)
    |> Enum.map(fn {input, _index} ->
      %{
        txid: input["txid"] || "0000000000000000000000000000000000000000000000000000000000000000",
        vout: input["vout"] || 0,
        script_sig: input["scriptSig"]["hex"] || "",
        sequence: input["sequence"] || 0,
        value: get_input_value(input)
      }
    end)
  end

  defp parse_outputs_data(vout_data) do
    Enum.map(vout_data, fn output ->
      %{
        # Convert BTC to satoshis
        value: round((output["value"] || 0) * 100_000_000),
        n: output["n"] || 0,
        script_pub_key: output["scriptPubKey"]["hex"] || "",
        address: get_address_from_script(output["scriptPubKey"]),
        type: output["scriptPubKey"]["type"] || "unknown"
      }
    end)
  end

  defp parse_timestamp(nil), do: NaiveDateTime.utc_now()

  defp parse_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp) |> DateTime.to_naive()
  end

  defp calculate_fee(_tx_data) do
    # This is a simplified fee calculation
    # In a real implementation, you'd need to fetch input values from their source transactions
    0
  end

  defp get_input_value(_input) do
    # This would require fetching the referenced output transaction
    # For now, we'll return 0 and implement proper value fetching later
    0
  end

  defp get_address_from_script(script_pub_key) do
    case script_pub_key["addresses"] do
      [address | _] -> address
      _ -> script_pub_key["address"] || ""
    end
  end
end
