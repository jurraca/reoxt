
defmodule Reoxt.BitcoinAnalyzer do
  @moduledoc """
  Context for Bitcoin transaction analysis.
  """

  alias Reoxt.BitcoinAnalyzer.{Transaction, TransactionInput, TransactionOutput}
  alias Reoxt.BitcoinRPC
  alias Reoxt.Repo
  import Ecto.Query

  def get_transaction(txid) do
    case Repo.get_by(Transaction, txid: txid) do
      nil ->
        fetch_and_store_transaction(txid)

      transaction ->
        transaction
        |> Repo.preload([:inputs, :outputs])
        |> then(&{:ok, &1})
    end
  end

  def analyze_transaction(txid) do
    with {:ok, transaction} <- get_transaction(txid) do
      metrics = calculate_transaction_metrics(transaction)
      {:ok, %{transaction: transaction, metrics: metrics}}
    end
  end

  def get_transaction_graph(txid) do
    with {:ok, transaction} <- get_transaction(txid) do
      graph_data = build_graph_data(transaction)
      {:ok, graph_data}
    end
  end

  defp fetch_and_store_transaction(txid) do
    case BitcoinRPC.get_transaction(txid) do
      {:ok, raw_tx} ->
        store_transaction(raw_tx)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp store_transaction(raw_tx) do
    Repo.transaction(fn ->
      transaction = %Transaction{
        txid: raw_tx["txid"],
        hash: raw_tx["hash"],
        version: raw_tx["version"],
        size: raw_tx["size"],
        vsize: raw_tx["vsize"],
        weight: raw_tx["weight"],
        locktime: raw_tx["locktime"],
        block_hash: raw_tx["blockhash"],
        block_height: raw_tx["blockheight"],
        confirmations: raw_tx["confirmations"],
        block_time: parse_block_time(raw_tx["blocktime"]),
        raw_data: raw_tx
      }
      |> Repo.insert!()

      # Store inputs
      for {input, index} <- Enum.with_index(raw_tx["vin"]) do
        %TransactionInput{
          transaction_id: transaction.id,
          input_index: index,
          previous_txid: input["txid"],
          previous_vout: input["vout"],
          script_sig: input["scriptSig"]["hex"],
          sequence: input["sequence"],
          raw_data: input
        }
        |> Repo.insert!()
      end

      # Store outputs
      for {output, index} <- Enum.with_index(raw_tx["vout"]) do
        %TransactionOutput{
          transaction_id: transaction.id,
          output_index: index,
          value: Decimal.new(output["value"]),
          script_pubkey: output["scriptPubKey"]["hex"],
          address: get_address_from_output(output),
          raw_data: output
        }
        |> Repo.insert!()
      end

      transaction
      |> Repo.preload([:inputs, :outputs])
    end)
    |> case do
      {:ok, transaction} -> {:ok, transaction}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_block_time(nil), do: nil
  defp parse_block_time(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
  end

  defp get_address_from_output(%{"scriptPubKey" => %{"address" => address}}), do: address
  defp get_address_from_output(_), do: nil

  defp calculate_transaction_metrics(transaction) do
    # Placeholder for entropy calculation
    # You'll implement the actual entropy calculation methodology here
    %{
      input_count: length(transaction.inputs),
      output_count: length(transaction.outputs),
      total_input_value: calculate_total_input_value(transaction.inputs),
      total_output_value: calculate_total_output_value(transaction.outputs),
      entropy: calculate_entropy_placeholder(transaction)
    }
  end

  defp calculate_total_input_value(inputs) do
    # This would require looking up the previous outputs
    # For now, return a placeholder
    Decimal.new(0)
  end

  defp calculate_total_output_value(outputs) do
    outputs
    |> Enum.map(& &1.value)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp calculate_entropy_placeholder(_transaction) do
    # Placeholder entropy calculation
    # You'll replace this with your actual methodology
    :rand.uniform() * 10
  end

  defp build_graph_data(transaction) do
    nodes = build_nodes(transaction)
    links = build_links(transaction)

    %{
      nodes: nodes,
      links: links,
      transaction: %{
        txid: transaction.txid,
        block_height: transaction.block_height
      }
    }
  end

  defp build_nodes(transaction) do
    input_nodes = 
      Enum.map(transaction.inputs, fn input ->
        %{
          id: "input_#{input.id}",
          type: "input",
          txid: input.previous_txid,
          vout: input.previous_vout,
          index: input.input_index
        }
      end)

    output_nodes =
      Enum.map(transaction.outputs, fn output ->
        %{
          id: "output_#{output.id}",
          type: "output",
          value: output.value,
          address: output.address,
          index: output.output_index
        }
      end)

    tx_node = %{
      id: "tx_#{transaction.id}",
      type: "transaction",
      txid: transaction.txid
    }

    [tx_node | input_nodes ++ output_nodes]
  end

  defp build_links(transaction) do
    input_links =
      Enum.map(transaction.inputs, fn input ->
        %{
          source: "input_#{input.id}",
          target: "tx_#{transaction.id}",
          type: "input"
        }
      end)

    output_links =
      Enum.map(transaction.outputs, fn output ->
        %{
          source: "tx_#{transaction.id}",
          target: "output_#{output.id}",
          type: "output"
        }
      end)

    input_links ++ output_links
  end
end
