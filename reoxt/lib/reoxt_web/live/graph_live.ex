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
     |> assign(:selected_algorithm, "centrality")}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-6">
      <h1 class="text-4xl font-bold mb-8 text-center" style="color: #bf40ff; text-shadow: 0 0 20px #bf40ff;">
        reoxt 
      </h1>

      <div class="mb-8 text-center">
        <button
          phx-click="search_graph"
          class="btn btn-primary mr-4 px-6 py-3 text-lg"
        >
          <span class="mr-2">🔍</span> Search Graph
        </button>

        <button
          phx-click="clear_graph"
          class="btn btn-secondary px-6 py-3 text-lg"
        >
          <span class="mr-2">🗑️</span> Clear Graph
        </button>
      </div>

      <!-- Search Controls -->
      <div class="bg-base-200 rounded-lg shadow-lg p-6 mb-8">
        <.form
          for={%{}}
          as={:search}
          phx-submit="search_graph"
          class="flex flex-wrap gap-4 items-end justify-center"
        >
          <div class="flex-1 min-w-[250px]">
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Transaction ID
            </label>
            <input
              type="text"
              name="search[txid]"
              value={@selected_txid}
              placeholder="Enter transaction hash..."
              class="w-full px-4 py-3 border border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-neon-cyan"
              style="background-color: #1a1a1a; color: #e0e0e0;"
              required
            />
          </div>

          <div class="w-32">
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Depth
            </label>
            <select
              name="search[depth]"
              class="w-full px-4 py-3 border border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-neon-cyan"
              style="background-color: #1a1a1a; color: #e0e0e0;"
            >
              <option value="1" selected={@search_depth == 1}>1</option>
              <option value="2" selected={@search_depth == 2}>2</option>
              <option value="3" selected={@search_depth == 3}>3</option>
              <option value="4" selected={@search_depth == 4}>4</option>
              <option value="5" selected={@search_depth == 5}>5</option>
            </select>
          </div>

          <button
            type="submit"
            disabled={@loading}
            class="px-6 py-3 bg-neon-green text-black font-bold rounded-lg hover:bg-neon-green-dark disabled:opacity-50 disabled:cursor-not-allowed transition duration-300 ease-in-out"
          >
            {if @loading, do: "Loading...", else: "Search"}
          </button>

          <button
            type="button"
            phx-click="clear_graph"
            class="px-4 py-3 bg-gray-700 text-white rounded-lg hover:bg-gray-600 transition duration-300 ease-in-out"
          >
            Clear
          </button>
        </.form>
      </div>

      <!-- Error Display -->
      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">Error</h3>
              <div class="mt-2 text-sm text-red-700">
                <%= @error %>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Main Content Area -->
      <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
        <!-- Graph Visualization -->
        <div class="lg:col-span-3">
          <div class="card shadow-lg" style="background: linear-gradient(145deg, #0a0a0a, #1a1a1a);">
            <div class="p-4 border-b border-gray-700">
              <h2 class="text-lg font-semibold" style="color: #00d4ff;">Transaction Network</h2>
            </div>
            <div class="p-4">
              <div
                id="graph-container"
                phx-hook="GraphVisualization"
                phx-update="ignore"
                class="w-full h-[600px] rounded-lg"
                style="background: linear-gradient(145deg, #0a0a0a, #1a1a1a); border: 2px solid rgba(191, 64, 255, 0.3);"
              >
                <%= if @loading do %>
                  <div class="flex items-center justify-center h-full">
                    <div class="text-center">
                      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-neon-green mx-auto"></div>
                      <p class="mt-2 text-gray-400">Loading graph...</p>
                    </div>
                  </div>
                <% else %>
                  <%= if @graph_data == nil do %>
                    <div class="flex items-center justify-center h-full text-gray-500">
                      <div class="text-center">
                        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                        </svg>
                        <h3 class="mt-2 text-sm font-medium text-gray-300">No graph loaded</h3>
                        <p class="mt-1 text-sm text-gray-500">Enter a transaction ID to visualize the network</p>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Graph Statistics -->
          <%= if @graph_data do %>
            <div class="card shadow-lg" style="background: linear-gradient(145deg, #0a0a0a, #1a1a1a);">
              <h3 class="text-lg font-semibold mb-3" style="color: #00d4ff;">Graph Statistics</h3>
              <div class="space-y-2 text-sm">
                <div class="flex justify-between text-gray-300">
                  <span>Transactions:</span>
                  <span class="font-medium" style="color: #bf40ff;"><%= @graph_stats.transaction_count || 0 %></span>
                </div>
                <div class="flex justify-between text-gray-300">
                  <span>Connections:</span>
                  <span class="font-medium" style="color: #bf40ff;"><%= @graph_stats.edge_count || 0 %></span>
                </div>
                <div class="flex justify-between text-gray-300">
                  <span>Total Value:</span>
                  <span class="font-medium" style="color: #bf40ff;"><%= @graph_stats.total_value || "0" %> BTC</span>
                </div>
                <div class="flex justify-between text-gray-300">
                  <span>Avg. Confirmations:</span>
                  <span class="font-medium" style="color: #bf40ff;"><%= @graph_stats.avg_confirmations || 0 %></span>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Graph Algorithms -->
          <%= if @graph_data do %>
            <div class="card shadow-lg" style="background: linear-gradient(145deg, #0a0a0a, #1a1a1a);">
              <h3 class="text-lg font-semibold mb-3" style="color: #bf00ff;">Graph Analysis</h3>

              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-300 mb-2">
                  Algorithm
                </label>
                <select
                  phx-change="run_algorithm"
                  name="algorithm"
                  class="w-full px-4 py-3 border border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-neon-purple"
                  style="background-color: #1a1a1a; color: #e0e0e0;"
                >
                  <option value="centrality" selected={@selected_algorithm == "centrality"}>
                    Centrality Analysis
                  </option>
                  <option value="cycles" selected={@selected_algorithm == "cycles"}>
                    Cycle Detection
                  </option>
                  <option value="components" selected={@selected_algorithm == "components"}>
                    Connected Components
                  </option>
                  <option value="shortest_paths" selected={@selected_algorithm == "shortest_paths"}>
                    Shortest Paths
                  </option>
                </select>
              </div>

              <%= if @algorithm_result do %>
                <div class="text-sm">
                  <h4 class="font-medium mb-2 text-gray-300">Results:</h4>
                  <div class="bg-base-300 rounded p-3 max-h-32 overflow-y-auto" style="background-color: #1f1f1f;">
                    <pre class="text-xs text-gray-400"><%= inspect(@algorithm_result, pretty: true, limit: :infinity) %></pre>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Legend -->
          <div class="card shadow-lg" style="background: linear-gradient(145deg, #0a0a0a, #1a1a1a);">
            <h3 class="text-lg font-semibold mb-3" style="color: #1e90ff;">Legend</h3>
            <div class="space-y-2 text-sm">
              <div class="flex items-center">
                <div class="w-3 h-3 rounded-full mr-2" style="background: #1e90ff; box-shadow: 0 0 8px #1e90ff;"></div>
                <span class="text-gray-300">Unconfirmed</span>
              </div>
              <div class="flex items-center">
                <div class="w-3 h-3 rounded-full mr-2" style="background: #bf40ff; box-shadow: 0 0 8px #bf40ff;"></div>
                <span class="text-gray-300">High Value (&gt;1 BTC)</span>
              </div>
              <div class="flex items-center">
                <div class="w-3 h-3 rounded-full mr-2" style="background: #00d4ff; box-shadow: 0 0 8px #00d4ff;"></div>
                <span class="text-gray-300">Low Confirmations</span>
              </div>
              <div class="flex items-center">
                <div class="w-3 h-3 rounded-full mr-2" style="background: #8a2be2; box-shadow: 0 0 8px #8a2be2;"></div>
                <span class="text-gray-300">Normal</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
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
end