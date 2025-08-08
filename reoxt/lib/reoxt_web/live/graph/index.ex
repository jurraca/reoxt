defmodule ReoxtWeb.GraphLive do
  use ReoxtWeb, :live_view

  alias Reoxt.Analyzer
  alias Reoxt.Transactions
  alias Reoxt.GraphAlgorithms

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Transaction Graph")
     |> assign(:loading, false)
     |> assign(:error, nil)
     |> assign(:graph_data, nil)
     |> assign(:selected_txid, "")
     |> assign(:search_depth, 3)
     |> assign(:graph_stats, %{})
     |> assign(:algorithm_result, nil)
     |> assign(:selected_algorithm, "centrality")
     |> assign(:hovered_transaction, nil)
     |> assign(:show_transaction_details, false)}
  end

  @impl true
  def handle_params(%{"txid" => txid}, _uri, socket) do
    send(self(), {:load_graph, txid})
    {:noreply, assign(socket, :selected_txid, txid)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search_graph", %{"search" => %{"txid" => txid, "depth" => depth}}, socket) do
    cleaned_txid = String.trim(txid)
    depth = String.to_integer(depth)

    # Validate input before proceeding
    case validate_transaction_id(cleaned_txid) do
      :ok ->
        socket =
          socket
          |> assign(:selected_txid, cleaned_txid)
          |> assign(:search_depth, depth)
          |> assign(:loading, true)
          |> assign(:error, nil)

        send(self(), {:load_graph, cleaned_txid})
        {:noreply, socket}

      {:error, reason} ->
        error_message = format_error_message(reason, cleaned_txid)

        socket =
          socket
          |> assign(:selected_txid, cleaned_txid)
          |> assign(:search_depth, depth)
          |> assign(:loading, false)
          |> assign(:error, error_message)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("run_algorithm", %{"algorithm" => algorithm}, socket) do
    case socket.assigns.graph_data do
      nil ->
        {:noreply, put_flash(socket, :error, "Please load a graph first")}

      graph_data ->
        result = run_graph_algorithm(algorithm, graph_data)

        socket =
          socket
          |> assign(:selected_algorithm, algorithm)
          |> assign(:algorithm_result, result)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_graph", _params, socket) do
    {:noreply,
     socket
     |> assign(:graph_data, nil)
     |> assign(:selected_txid, "")
     |> assign(:graph_stats, %{})
     |> assign(:algorithm_result, nil)
     |> push_event("clear_graph", %{})}
  end

  @impl true
  def handle_event("node_hover", %{"txid" => txid, "x" => x, "y" => y}, socket) do
    # Find transaction details from the current graph data
    transaction_details = case socket.assigns.graph_data do
      nil -> nil
      graph_data ->
        Enum.find(graph_data.nodes, &(&1.id == txid))
    end
    
    {:noreply, 
     socket
     |> assign(:hovered_transaction, transaction_details)
     |> assign(:show_transaction_details, true)}
  end

  @impl true
  def handle_event("node_leave", %{"txid" => _txid}, socket) do
    # Hide transaction details when mouse leaves node
    {:noreply, 
     socket
     |> assign(:hovered_transaction, nil)
     |> assign(:show_transaction_details, false)}
  end

  @impl true
  def handle_info({:load_graph, txid}, socket) do
    case build_transaction_graph(txid, socket.assigns.search_depth) do
      {:ok, graph_data} ->
        stats = calculate_graph_stats(graph_data)

        socket =
          socket
          |> assign(:loading, false)
          |> assign(:graph_data, graph_data)
          |> assign(:graph_stats, stats)
          |> assign(:error, nil)
          |> push_event("render_graph", %{graph_data: graph_data})

        {:noreply, socket}

      {:error, reason} ->
        error_message = format_error_message(reason, txid)

        socket =
          socket
          |> assign(:loading, false)
          |> assign(:error, error_message)
          |> assign(:graph_data, nil)
          |> assign(:graph_stats, %{})

        {:noreply, socket}
    end
  end

  # Private functions
  defp build_transaction_graph(txid, depth) do
    # Validate transaction ID format first
    case validate_transaction_id(txid) do
      :ok ->
        try do
          case Analyzer.build_transaction_graph(txid, depth) do
            {:error, reason} ->
              {:error, reason}
            graph_data when is_map(graph_data) ->
              {:ok, graph_data}
          end
        rescue
          error ->
            {:error, error}
        catch
          :throw, {:error, reason} ->
            {:error, reason}
          :error, reason ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_transaction_id(txid) when is_binary(txid) do
    cleaned_txid = String.trim(txid)

    cond do
      cleaned_txid == "" ->
        {:error, :empty_txid}

      byte_size(cleaned_txid) != 64 ->
        {:error, :invalid_length}

      not Regex.match?(~r/^[a-fA-F0-9]{64}$/, cleaned_txid) ->
        {:error, :invalid_format}

      true ->
        :ok
    end
  end

  defp validate_transaction_id(_), do: {:error, :invalid_type}

  defp format_error_message(reason, txid) do
    case reason do
      :empty_txid ->
        "Please enter a transaction ID."

      :invalid_length ->
        "Transaction ID must be exactly 64 characters long. You entered #{byte_size(String.trim(txid))} characters."

      :invalid_format ->
        "Transaction ID must contain only hexadecimal characters (0-9, a-f, A-F)."

      :invalid_type ->
        "Invalid transaction ID format."

      %{message: message} when is_binary(message) ->
        cond do
          String.contains?(message, "not found") or String.contains?(message, "No such") ->
            "Transaction '#{String.slice(txid, 0, 8)}...' not found. Please verify the transaction ID and try again."

          String.contains?(message, "connection") ->
            "Unable to connect to Bitcoin node. Please check your RPC configuration."

          String.contains?(message, "unauthorized") ->
            "Authentication failed. Please check your RPC credentials."

          true ->
            "Error: #{message}"
        end

      error when is_atom(error) ->
        case error do
          :not_found ->
            "Transaction '#{String.slice(txid, 0, 8)}...' not found in the blockchain."

          :connection_error ->
            "Unable to connect to Bitcoin node. Please check your network connection."

          :timeout ->
            "Request timed out. The Bitcoin node may be busy."

          _ ->
            "An unexpected error occurred: #{error}"
        end

      %{__exception__: true} = exception ->
        case exception do
          %RuntimeError{message: message} ->
            if String.contains?(message, "not found") do
              "Transaction '#{String.slice(txid, 0, 8)}...' not found in the blockchain."
            else
              "Error: #{message}"
            end

          _ ->
            "An error occurred while fetching transaction data."
        end

      _ ->
        "Failed to load transaction graph. Please try again with a valid transaction ID."
    end
  end

  defp calculate_graph_stats(graph_data) do
    transaction_count = length(graph_data.nodes)
    edge_count = length(graph_data.edges)

    total_value =
      graph_data.nodes
      |> Enum.flat_map(& &1.outputs)
      |> Enum.map(& &1.value)
      |> Enum.filter(&is_number/1)
      |> Enum.sum()
      |> case do
        0 -> "0"
        val -> :erlang.float_to_binary(val / 100_000_000, decimals: 8)
      end

    avg_confirmations =
      graph_data.nodes
      |> Enum.map(&get_confirmations(&1))
      |> Enum.filter(&is_number/1)
      |> case do
        [] -> 0
        confirmations -> Enum.sum(confirmations) / length(confirmations) |> Float.round(1)
      end

    %{
      transaction_count: transaction_count,
      edge_count: edge_count,
      total_value: total_value,
      avg_confirmations: avg_confirmations
    }
  end

  defp run_graph_algorithm("centrality", graph_data) do
    GraphAlgorithms.calculate_centrality(graph_data)
  end

  defp run_graph_algorithm("cycles", graph_data) do
    GraphAlgorithms.detect_cycles(graph_data)
  end

  defp run_graph_algorithm("components", graph_data) do
    GraphAlgorithms.find_strongly_connected_components(graph_data)
  end

  defp run_graph_algorithm("shortest_paths", graph_data) do
    GraphAlgorithms.all_pairs_shortest_paths(graph_data)
  end

  defp run_graph_algorithm(_, _graph_data) do
    %{error: "Unknown algorithm"}
  end

  # Helper function to calculate confirmations
  defp get_confirmations(node) do
    # Assuming get_block_height() is available and returns the current block height.
    # If not, this needs to be implemented or passed in.
    current_height = 17 #Reoxt.BitcoinRpcClient.get_best_block()

    # If confirmations field exists and is valid, use it. Otherwise, calculate.
    case Map.get(node, :confirmations) do
      nil ->
        block_height = Map.get(node, :block_height)
        if is_integer(block_height) && is_integer(current_height) && block_height <= current_height do
          current_height - block_height
        else
          0 # Default to 0 if block_height is missing or invalid
        end
      confirmations ->
        confirmations # Use the existing confirmations if available
    end
  end

  # Helper function to format timestamps
  defp format_timestamp(timestamp) when is_binary(timestamp), do: timestamp
  defp format_timestamp(%NaiveDateTime{} = timestamp) do
    NaiveDateTime.to_string(timestamp)
  end
  defp format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp) |> DateTime.to_string()
  end
  defp format_timestamp(_), do: "N/A"

  # Helper function to format BTC amounts
  defp format_btc_amount(satoshis) when is_integer(satoshis) do
    :erlang.float_to_binary(satoshis / 100_000_000, decimals: 8)
  end
  defp format_btc_amount(_), do: "0.00000000"

  # Helper function to calculate total output value
  defp calculate_total_output_value(outputs) when is_list(outputs) do
    total_satoshis = Enum.reduce(outputs, 0, fn output, acc ->
      case Map.get(output, :value) do
        value when is_integer(value) -> acc + value
        _ -> acc
      end
    end)
    format_btc_amount(total_satoshis)
  end
  defp calculate_total_output_value(_), do: "0.00000000"
end