defmodule Reoxt.Analyzer do
  @moduledoc """
  The Analyzer context.
  """

  import Ecto.Query, warn: false
  alias Reoxt.Repo

  alias Reoxt.Analyzer.BitcoinRpc

  @doc """
  Returns the list of bitcoin_rpc_configs.

  ## Examples

      iex> list_bitcoin_rpc_configs()
      [%BitcoinRpc{}, ...]

  """
  def list_bitcoin_rpc_configs do
    Repo.all(BitcoinRpc)
  end

  @doc """
  Gets a single bitcoin_rpc.

  Raises `Ecto.NoResultsError` if the Bitcoin rpc does not exist.

  ## Examples

      iex> get_bitcoin_rpc!(123)
      %BitcoinRpc{}

      iex> get_bitcoin_rpc!(456)
      ** (Ecto.NoResultsError)

  """
  def get_bitcoin_rpc!(id), do: Repo.get!(BitcoinRpc, id)

  @doc """
  Creates a bitcoin_rpc.

  ## Examples

      iex> create_bitcoin_rpc(%{field: value})
      {:ok, %BitcoinRpc{}}

      iex> create_bitcoin_rpc(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_bitcoin_rpc(attrs) do
    %BitcoinRpc{}
    |> BitcoinRpc.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a bitcoin_rpc.

  ## Examples

      iex> update_bitcoin_rpc(bitcoin_rpc, %{field: new_value})
      {:ok, %BitcoinRpc{}}

      iex> update_bitcoin_rpc(bitcoin_rpc, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_bitcoin_rpc(%BitcoinRpc{} = bitcoin_rpc, attrs) do
    bitcoin_rpc
    |> BitcoinRpc.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a bitcoin_rpc.

  ## Examples

      iex> delete_bitcoin_rpc(bitcoin_rpc)
      {:ok, %BitcoinRpc{}}

      iex> delete_bitcoin_rpc(bitcoin_rpc)
      {:error, %Ecto.Changeset{}}

  """
  def delete_bitcoin_rpc(%BitcoinRpc{} = bitcoin_rpc) do
    Repo.delete(bitcoin_rpc)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking bitcoin_rpc changes.

  ## Examples

      iex> change_bitcoin_rpc(bitcoin_rpc)
      %Ecto.Changeset{data: %BitcoinRpc{}}

  """
  def change_bitcoin_rpc(%BitcoinRpc{} = bitcoin_rpc, attrs \\ %{}) do
    BitcoinRpc.changeset(bitcoin_rpc, attrs)
  end

  alias Reoxt.Transactions

  @doc """
  Builds a transaction graph starting from a given transaction ID.
  Returns a map with nodes (transactions) and edges (connections).
  
  ## Examples

      iex> build_transaction_graph("abc123", 2)
      %{
        nodes: [%Transaction{}, ...],
        edges: [%{from: "abc123", to: "def456", type: :spends}, ...]
      }
  """
  def build_transaction_graph(txid, depth \\ 3) when is_binary(txid) and depth > 0 do
    case Transactions.get_transaction_by_txid(txid) do
      nil ->
        {:error, :transaction_not_found}
      
      root_transaction ->
        visited = MapSet.new()
        nodes = []
        edges = []
        
        {nodes, edges, _visited} = traverse_transaction_graph(
          root_transaction,
          depth,
          visited,
          nodes,
          edges
        )
        
        %{nodes: nodes, edges: edges}
    end
  end

  @doc """
  Finds all transactions connected to a given transaction through input/output relationships.
  Returns both incoming (transactions that this one spends from) and outgoing (transactions that spend from this one).
  """
  def find_connected_transactions(txid) when is_binary(txid) do
    case Transactions.get_transaction_by_txid(txid) do
      nil ->
        {:error, :transaction_not_found}
      
      transaction ->
        incoming = get_input_transactions(transaction)
        outgoing = get_output_transactions(transaction)
        
        {:ok, %{
          transaction: transaction,
          incoming: incoming,
          outgoing: outgoing
        }}
    end
  end

  @doc """
  Traces a transaction path between two transaction IDs.
  Returns the shortest path if one exists.
  """
  def trace_transaction_path(from_txid, to_txid, max_depth \\ 6) do
    case {Transactions.get_transaction_by_txid(from_txid), Transactions.get_transaction_by_txid(to_txid)} do
      {nil, _} ->
        {:error, :from_transaction_not_found}
      
      {_, nil} ->
        {:error, :to_transaction_not_found}
      
      {from_tx, to_tx} ->
        find_path_bfs(from_tx, to_tx, max_depth)
    end
  end

  @doc """
  Analyzes transaction clustering - groups related transactions.
  Uses input/output analysis to identify potential wallet clusters.
  """
  def analyze_transaction_clusters(txids) when is_list(txids) do
    transactions = Enum.map(txids, &Transactions.get_transaction_by_txid/1)
                  |> Enum.reject(&is_nil/1)
    
    clusters = build_clusters(transactions)
    
    {:ok, %{
      clusters: clusters,
      cluster_count: length(clusters),
      transaction_count: length(transactions)
    }}
  end

  # Private helper functions

  defp traverse_transaction_graph(transaction, depth, visited, nodes, edges) do
    if MapSet.member?(visited, transaction.txid) do
      {nodes, edges, visited}
    else
      visited = MapSet.put(visited, transaction.txid)
      nodes = [transaction | nodes]
      
      # Only traverse connections if we have remaining depth
      if depth > 0 do
        # Get input transactions (what this transaction spends from)
        input_transactions = get_input_transactions(transaction)
        
        # Get output transactions (what spends from this transaction)
        output_transactions = get_output_transactions(transaction)
        
        # Add edges for inputs
        input_edges = Enum.map(input_transactions, fn input_tx ->
          %{from: input_tx.txid, to: transaction.txid, type: :spends}
        end)
        
        # Add edges for outputs
        output_edges = Enum.map(output_transactions, fn output_tx ->
          %{from: transaction.txid, to: output_tx.txid, type: :spent_by}
        end)
        
        edges = edges ++ input_edges ++ output_edges
        
        # Recursively traverse connected transactions with reduced depth
        connected_transactions = input_transactions ++ output_transactions
        
        Enum.reduce(connected_transactions, {nodes, edges, visited}, fn tx, {acc_nodes, acc_edges, acc_visited} ->
          traverse_transaction_graph(tx, depth - 1, acc_visited, acc_nodes, acc_edges)
        end)
      else
        # At depth 0, just return current state without traversing further
        {nodes, edges, visited}
      end
    end
  end

  defp get_input_transactions(transaction) do
    transaction
    |> Repo.preload(:inputs)
    |> Map.get(:inputs)
    |> Enum.map(fn input ->
      # Find the transaction that this input references
      Transactions.get_transaction_by_txid(input.txid)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_output_transactions(transaction) do
    # Find transactions that have inputs referencing this transaction's outputs
    from(ti in Reoxt.Transactions.TransactionInput,
      where: ti.txid == ^transaction.txid,
      join: t in assoc(ti, :transaction),
      select: t
    )
    |> Repo.all()
  end

  defp find_path_bfs(from_tx, to_tx, max_depth) do
    queue = [{from_tx, [from_tx.txid]}]
    visited = MapSet.new([from_tx.txid])
    
    do_bfs(queue, to_tx.txid, visited, max_depth, 0)
  end

  defp do_bfs([], _target_txid, _visited, _max_depth, _depth) do
    {:error, :path_not_found}
  end

  defp do_bfs(_queue, _target_txid, _visited, max_depth, depth) when depth > max_depth do
    {:error, :max_depth_exceeded}
  end

  defp do_bfs([{current_tx, path} | rest], target_txid, visited, max_depth, depth) do
    if current_tx.txid == target_txid do
      {:ok, path}
    else
      # Get connected transactions
      connected = get_input_transactions(current_tx) ++ get_output_transactions(current_tx)
      
      new_items = 
        connected
        |> Enum.reject(fn tx -> MapSet.member?(visited, tx.txid) end)
        |> Enum.map(fn tx -> {tx, path ++ [tx.txid]} end)
      
      new_visited = 
        connected
        |> Enum.reduce(visited, fn tx, acc -> MapSet.put(acc, tx.txid) end)
      
      do_bfs(rest ++ new_items, target_txid, new_visited, max_depth, depth + 1)
    end
  end

  defp build_clusters(transactions) do
    # Group transactions that share common addresses or are connected through inputs/outputs
    address_groups = group_by_addresses(transactions)
    connection_groups = group_by_connections(transactions)
    
    # Merge overlapping groups
    merge_clusters(address_groups ++ connection_groups)
  end

  defp group_by_addresses(transactions) do
    transactions
    |> Enum.flat_map(fn tx ->
      tx = Repo.preload(tx, [:inputs, :outputs])
      addresses = Enum.map(tx.outputs, & &1.address) |> Enum.reject(&is_nil/1)
      Enum.map(addresses, fn addr -> {addr, tx} end)
    end)
    |> Enum.group_by(fn {addr, _tx} -> addr end, fn {_addr, tx} -> tx end)
    |> Map.values()
    |> Enum.filter(fn group -> length(group) > 1 end)
  end

  defp group_by_connections(transactions) do
    transactions
    |> Enum.map(fn tx ->
      connected = get_input_transactions(tx) ++ get_output_transactions(tx)
      [tx | connected]
    end)
    |> Enum.filter(fn group -> length(group) > 1 end)
  end

  defp merge_clusters(clusters) do
    # Simple cluster merging - merge clusters that share any transactions
    clusters
    |> Enum.reduce([], fn cluster, acc ->
      txids_in_cluster = MapSet.new(Enum.map(cluster, & &1.txid))
      
      case Enum.find_index(acc, fn existing_cluster ->
        existing_txids = MapSet.new(Enum.map(existing_cluster, & &1.txid))
        not MapSet.disjoint?(txids_in_cluster, existing_txids)
      end) do
        nil ->
          [cluster | acc]
        
        index ->
          existing_cluster = Enum.at(acc, index)
          merged_cluster = Enum.uniq_by(cluster ++ existing_cluster, & &1.txid)
          List.replace_at(acc, index, merged_cluster)
      end
    end)
  end

  @doc """
  Converts graph data to D3.js-friendly format for visualization.
  """
  def format_graph_for_d3(graph_data) do
    %{
      nodes: Enum.map(graph_data.nodes, fn tx ->
        %{
          id: tx.txid,
          txid: tx.txid,
          block_height: tx.block_height,
          fee: tx.fee,
          size: tx.size,
          timestamp: tx.timestamp
        }
      end),
      links: Enum.map(graph_data.edges, fn edge ->
        %{
          source: edge.from,
          target: edge.to,
          type: edge.type
        }
      end)
    }
  end

  @doc """
  Calculates graph statistics for a given transaction graph.
  """
  def calculate_graph_statistics(graph_data) do
    node_count = length(graph_data.nodes)
    edge_count = length(graph_data.edges)
    
    # Calculate degree for each node
    degree_map = calculate_node_degrees(graph_data.edges)
    
    max_degree = if Enum.empty?(degree_map), do: 0, else: Enum.max(Map.values(degree_map))
    avg_degree = if node_count == 0, do: 0, else: (edge_count * 2) / node_count
    
    # Calculate total value flow
    total_value = graph_data.nodes
                 |> Enum.map(fn tx -> tx.fee || 0 end)
                 |> Enum.sum()
    
    %{
      node_count: node_count,
      edge_count: edge_count,
      max_degree: max_degree,
      avg_degree: Float.round(avg_degree, 2),
      total_fee_value: total_value,
      density: if(node_count <= 1, do: 0, else: Float.round(edge_count / (node_count * (node_count - 1) / 2), 4))
    }
  end

  defp calculate_node_degrees(edges) do
    edges
    |> Enum.reduce(%{}, fn edge, acc ->
      acc
      |> Map.update(edge.from, 1, &(&1 + 1))
      |> Map.update(edge.to, 1, &(&1 + 1))
    end)
  end
end
