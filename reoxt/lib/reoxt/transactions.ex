
defmodule Reoxt.Transactions do
  @moduledoc """
  The Transactions context for handling Bitcoin transaction data.
  """

  import Ecto.Query, warn: false
  alias Reoxt.Repo
  alias Reoxt.Transactions.{Transaction, TransactionInput, TransactionOutput}

  @doc """
  Gets a transaction by TXID.
  """
  def get_transaction_by_txid(txid) do
    Repo.get_by(Transaction, txid: txid)
  end

  @doc """
  Gets a transaction by TXID with inputs and outputs preloaded.
  """
  def get_transaction_with_details(txid) do
    from(t in Transaction,
      where: t.txid == ^txid,
      preload: [:inputs, :outputs]
    )
    |> Repo.one()
  end

  @doc """
  Creates a transaction with its inputs and outputs.
  """
  def create_transaction_with_details(transaction_data, inputs_data, outputs_data) do
    Repo.transaction(fn ->
      # Create the transaction
      {:ok, transaction} = create_transaction(transaction_data)

      # Create inputs
      inputs = Enum.map(inputs_data, fn input_data ->
        input_data = Map.put(input_data, :transaction_id, transaction.id)
        {:ok, input} = create_transaction_input(input_data)
        input
      end)

      # Create outputs
      outputs = Enum.map(outputs_data, fn output_data ->
        output_data = Map.put(output_data, :transaction_id, transaction.id)
        {:ok, output} = create_transaction_output(output_data)
        output
      end)

      %{transaction | inputs: inputs, outputs: outputs}
    end)
  end

  @doc """
  Creates a transaction.
  """
  def create_transaction(attrs \\ %{}) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a transaction input.
  """
  def create_transaction_input(attrs \\ %{}) do
    %TransactionInput{}
    |> TransactionInput.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a transaction output.
  """
  def create_transaction_output(attrs \\ %{}) do
    %TransactionOutput{}
    |> TransactionOutput.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Finds transaction chains by following input/output relationships.
  Returns a list of related transaction TXIDs.
  """
  def get_transaction_chain(starting_txid, max_depth \\ 5) do
    get_transaction_chain_recursive([starting_txid], MapSet.new([starting_txid]), max_depth)
  end

  defp get_transaction_chain_recursive(current_txids, visited, 0), do: MapSet.to_list(visited)

  defp get_transaction_chain_recursive(current_txids, visited, depth) do
    # Find transactions that spend outputs from current transactions
    spending_txids = 
      from(ti in TransactionInput,
        where: ti.txid in ^current_txids,
        join: t in Transaction, on: t.id == ti.transaction_id,
        select: t.txid
      )
      |> Repo.all()
      |> Enum.reject(&MapSet.member?(visited, &1))

    # Find transactions whose outputs are spent by current transactions
    spent_txids =
      from(t in Transaction,
        join: ti in TransactionInput, on: ti.transaction_id == t.id,
        join: source_t in Transaction, on: source_t.txid == ti.txid,
        where: t.txid in ^current_txids,
        select: source_t.txid
      )
      |> Repo.all()
      |> Enum.reject(&MapSet.member?(visited, &1))

    new_txids = spending_txids ++ spent_txids
    new_visited = Enum.reduce(new_txids, visited, &MapSet.put(&2, &1))

    if Enum.empty?(new_txids) do
      MapSet.to_list(new_visited)
    else
      get_transaction_chain_recursive(new_txids, new_visited, depth - 1)
    end
  end

  @doc """
  Gets inputs that spend from a specific transaction output.
  """
  def get_inputs_spending_output(txid, output_index) do
    from(ti in TransactionInput,
      where: ti.txid == ^txid and ti.vout == ^output_index,
      preload: [transaction: :transaction]
    )
    |> Repo.all()
  end

  @doc """
  Gets the source output for a transaction input.
  """
  def get_source_output_for_input(input) do
    from(to in TransactionOutput,
      join: t in Transaction, on: t.id == to.transaction_id,
      where: t.txid == ^input.txid and to.n == ^input.vout
    )
    |> Repo.one()
  end

  @doc """
  Lists recent transactions with pagination.
  """
  def list_recent_transactions(limit \\ 50, offset \\ 0) do
    from(t in Transaction,
      order_by: [desc: t.timestamp],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  @doc """
  Gets transactions by block height.
  """
  def get_transactions_by_block_height(height) do
    from(t in Transaction,
      where: t.block_height == ^height,
      order_by: t.timestamp
    )
    |> Repo.all()
  end
end
