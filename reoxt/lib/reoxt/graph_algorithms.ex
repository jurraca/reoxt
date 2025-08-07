
defmodule Reoxt.GraphAlgorithms do
  @moduledoc """
  Graph algorithms for transaction analysis.
  """

  alias Reoxt.Transactions.Transaction

  @doc """
  Performs depth-first search to find strongly connected components.
  Useful for identifying tightly connected transaction groups.
  """
  def find_strongly_connected_components(graph_data) do
    nodes = graph_data.nodes |> Enum.map(& &1.txid) |> MapSet.new()
    adjacency_list = build_adjacency_list(graph_data.edges)
    
    {_, components} = tarjan_scc(nodes, adjacency_list)
    components
  end

  @doc """
  Detects cycles in the transaction graph.
  Returns a list of cycles found.
  """
  def detect_cycles(graph_data) do
    adjacency_list = build_adjacency_list(graph_data.edges)
    nodes = graph_data.nodes |> Enum.map(& &1.txid)
    
    visited = MapSet.new()
    rec_stack = MapSet.new()
    cycles = []
    
    {_visited, _rec_stack, cycles} = 
      Enum.reduce(nodes, {visited, rec_stack, cycles}, fn node, {v, rs, c} ->
        if MapSet.member?(v, node) do
          {v, rs, c}
        else
          dfs_cycle_detection(node, adjacency_list, v, rs, c, [])
        end
      end)
    
    cycles
  end

  @doc """
  Calculates centrality measures for nodes in the graph.
  Returns betweenness centrality for each node.
  """
  def calculate_centrality(graph_data) do
    nodes = graph_data.nodes |> Enum.map(& &1.txid)
    adjacency_list = build_adjacency_list(graph_data.edges)
    
    betweenness_centrality(nodes, adjacency_list)
  end

  @doc """
  Finds the shortest paths between all pairs of nodes using Floyd-Warshall algorithm.
  """
  def all_pairs_shortest_paths(graph_data) do
    nodes = graph_data.nodes |> Enum.map(& &1.txid)
    adjacency_list = build_adjacency_list(graph_data.edges)
    
    floyd_warshall(nodes, adjacency_list)
  end

  # Private helper functions

  defp build_adjacency_list(edges) do
    edges
    |> Enum.reduce(%{}, fn edge, acc ->
      Map.update(acc, edge.from, [edge.to], fn existing ->
        [edge.to | existing]
      end)
    end)
  end

  defp tarjan_scc(nodes, adjacency_list) do
    initial_state = %{
      index: 0,
      stack: [],
      indices: %{},
      low_links: %{},
      on_stack: MapSet.new(),
      components: []
    }
    
    Enum.reduce(nodes, initial_state, fn node, state ->
      if Map.has_key?(state.indices, node) do
        state
      else
        tarjan_strongconnect(node, adjacency_list, state)
      end
    end)
    |> then(fn state -> {state.index, state.components} end)
  end

  defp tarjan_strongconnect(node, adjacency_list, state) do
    state = %{state |
      indices: Map.put(state.indices, node, state.index),
      low_links: Map.put(state.low_links, node, state.index),
      stack: [node | state.stack],
      on_stack: MapSet.put(state.on_stack, node),
      index: state.index + 1
    }
    
    neighbors = Map.get(adjacency_list, node, [])
    
    state = Enum.reduce(neighbors, state, fn neighbor, acc_state ->
      cond do
        not Map.has_key?(acc_state.indices, neighbor) ->
          # Successor has not been visited; recurse
          acc_state = tarjan_strongconnect(neighbor, adjacency_list, acc_state)
          low_link = min(Map.get(acc_state.low_links, node), Map.get(acc_state.low_links, neighbor))
          %{acc_state | low_links: Map.put(acc_state.low_links, node, low_link)}
        
        MapSet.member?(acc_state.on_stack, neighbor) ->
          # Successor is in stack and hence in the current SCC
          low_link = min(Map.get(acc_state.low_links, node), Map.get(acc_state.indices, neighbor))
          %{acc_state | low_links: Map.put(acc_state.low_links, node, low_link)}
        
        true ->
          acc_state
      end
    end)
    
    # If node is a root node, pop the stack and create an SCC
    if Map.get(state.low_links, node) == Map.get(state.indices, node) do
      {component, remaining_stack, on_stack} = pop_component(state.stack, state.on_stack, node, [])
      
      %{state |
        stack: remaining_stack,
        on_stack: on_stack,
        components: [component | state.components]
      }
    else
      state
    end
  end

  defp pop_component([head | tail], on_stack, target, component) do
    new_on_stack = MapSet.delete(on_stack, head)
    new_component = [head | component]
    
    if head == target do
      {new_component, tail, new_on_stack}
    else
      pop_component(tail, new_on_stack, target, new_component)
    end
  end

  defp dfs_cycle_detection(node, adjacency_list, visited, rec_stack, cycles, path) do
    if MapSet.member?(rec_stack, node) do
      # Found a cycle
      cycle_start_index = Enum.find_index(path, &(&1 == node))
      cycle = Enum.drop(path, cycle_start_index || 0)
      {visited, rec_stack, [cycle | cycles]}
    else
      if MapSet.member?(visited, node) do
        {visited, rec_stack, cycles}
      else
        visited = MapSet.put(visited, node)
        rec_stack = MapSet.put(rec_stack, node)
        path = [node | path]
        
        neighbors = Map.get(adjacency_list, node, [])
        
        {visited, rec_stack, cycles} = 
          Enum.reduce(neighbors, {visited, rec_stack, cycles}, fn neighbor, {v, rs, c} ->
            dfs_cycle_detection(neighbor, adjacency_list, v, rs, c, path)
          end)
        
        rec_stack = MapSet.delete(rec_stack, node)
        {visited, rec_stack, cycles}
      end
    end
  end

  defp betweenness_centrality(nodes, adjacency_list) do
    # Simplified betweenness centrality calculation
    # For production use, consider implementing Brandes' algorithm
    nodes
    |> Enum.map(fn node ->
      # Count how many shortest paths pass through this node
      paths_through_node = count_paths_through_node(node, nodes, adjacency_list)
      {node, paths_through_node}
    end)
    |> Map.new()
  end

  defp count_paths_through_node(target_node, all_nodes, adjacency_list) do
    # This is a simplified version - in practice you'd want a more sophisticated implementation
    other_nodes = Enum.reject(all_nodes, &(&1 == target_node))
    
    Enum.reduce(other_nodes, 0, fn source, acc ->
      Enum.reduce(other_nodes, acc, fn dest, inner_acc ->
        if source != dest do
          case shortest_path(source, dest, adjacency_list) do
            {:ok, path} when length(path) > 2 ->
              if Enum.member?(Enum.slice(path, 1..-2), target_node) do
                inner_acc + 1
              else
                inner_acc
              end
            _ ->
              inner_acc
          end
        else
          inner_acc
        end
      end)
    end)
  end

  defp shortest_path(source, dest, adjacency_list) do
    # Simple BFS for shortest path
    queue = [{source, [source]}]
    visited = MapSet.new([source])
    
    do_shortest_path_bfs(queue, dest, adjacency_list, visited)
  end

  defp do_shortest_path_bfs([], _dest, _adjacency_list, _visited) do
    {:error, :no_path_found}
  end

  defp do_shortest_path_bfs([{current, path} | rest], dest, adjacency_list, visited) do
    if current == dest do
      {:ok, path}
    else
      neighbors = Map.get(adjacency_list, current, [])
      unvisited_neighbors = Enum.reject(neighbors, &MapSet.member?(visited, &1))
      
      new_queue_items = Enum.map(unvisited_neighbors, fn neighbor ->
        {neighbor, path ++ [neighbor]}
      end)
      
      new_visited = Enum.reduce(unvisited_neighbors, visited, &MapSet.put(&2, &1))
      
      do_shortest_path_bfs(rest ++ new_queue_items, dest, adjacency_list, new_visited)
    end
  end

  defp floyd_warshall(nodes, adjacency_list) do
    # Initialize distance matrix
    node_indices = nodes |> Enum.with_index() |> Map.new()
    n = length(nodes)
    
    # Initialize distances
    distances = 
      for i <- 0..(n-1), j <- 0..(n-1), into: %{} do
        node_i = Enum.at(nodes, i)
        node_j = Enum.at(nodes, j)
        
        cond do
          i == j -> {{i, j}, 0}
          Enum.member?(Map.get(adjacency_list, node_i, []), node_j) -> {{i, j}, 1}
          true -> {{i, j}, :infinity}
        end
      end
    
    # Floyd-Warshall algorithm
    distances = 
      for k <- 0..(n-1), reduce: distances do
        acc_distances ->
          for i <- 0..(n-1), j <- 0..(n-1), reduce: acc_distances do
            inner_distances ->
              dist_ik = Map.get(inner_distances, {i, k})
              dist_kj = Map.get(inner_distances, {k, j})
              dist_ij = Map.get(inner_distances, {i, j})
              
              new_dist = case {dist_ik, dist_kj} do
                {:infinity, _} -> dist_ij
                {_, :infinity} -> dist_ij
                {d1, d2} -> min(dist_ij, d1 + d2)
              end
              
              Map.put(inner_distances, {i, j}, new_dist)
          end
      end
    
    # Convert back to node names
    for {{i, j}, distance} <- distances, into: %{} do
      node_i = Enum.at(nodes, i)
      node_j = Enum.at(nodes, j)
      {{node_i, node_j}, distance}
    end
  end
end
