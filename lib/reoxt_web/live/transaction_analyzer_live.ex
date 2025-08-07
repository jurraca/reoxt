
defmodule ReoxtWeb.TransactionAnalyzerLive do
  use ReoxtWeb, :live_view

  alias Reoxt.BitcoinAnalyzer

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:transaction, nil)
      |> assign(:metrics, nil)
      |> assign(:graph_data, nil)
      |> assign(:txid_form, to_form(%{"txid" => ""}))
      |> assign(:loading, false)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"txid" => txid}, _uri, socket) do
    socket = analyze_transaction(socket, txid)
    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("analyze_transaction", %{"txid" => txid}, socket) do
    socket = analyze_transaction(socket, txid)
    {:noreply, push_patch(socket, to: ~p"/transaction/#{txid}")}
  end

  @impl true
  def handle_event("clear_analysis", _params, socket) do
    socket =
      socket
      |> assign(:transaction, nil)
      |> assign(:metrics, nil)
      |> assign(:graph_data, nil)
      |> assign(:error, nil)
      |> assign(:txid_form, to_form(%{"txid" => ""}))

    {:noreply, push_patch(socket, to: ~p"/")}
  end

  defp analyze_transaction(socket, txid) when is_binary(txid) and txid != "" do
    socket
    |> assign(:loading, true)
    |> assign(:error, nil)
    |> start_async(:analyze_transaction, fn ->
      case BitcoinAnalyzer.analyze_transaction(txid) do
        {:ok, %{transaction: transaction, metrics: metrics}} ->
          {:ok, graph_data} = BitcoinAnalyzer.get_transaction_graph(txid)
          {:ok, transaction, metrics, graph_data}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  defp analyze_transaction(socket, _txid) do
    socket
    |> assign(:error, "Please enter a valid transaction ID")
  end

  @impl true
  def handle_async(:analyze_transaction, {:ok, {:ok, transaction, metrics, graph_data}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:transaction, transaction)
      |> assign(:metrics, metrics)
      |> assign(:graph_data, graph_data)
      |> push_event("update_graph", %{data: graph_data})

    {:noreply, socket}
  end

  @impl true
  def handle_async(:analyze_transaction, {:ok, {:error, reason}}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:error, "Failed to analyze transaction: #{inspect(reason)}")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-4">Bitcoin Transaction Analyzer</h1>
        
        <.form for={@txid_form} phx-submit="analyze_transaction" class="flex gap-4 mb-4">
          <.input 
            field={@txid_form[:txid]} 
            type="text" 
            placeholder="Enter transaction ID (txid)" 
            class="flex-1" 
          />
          <.button type="submit" disabled={@loading}>
            <%= if @loading do %>
              <span class="animate-spin">⏳</span> Analyzing...
            <% else %>
              Analyze
            <% end %>
          </.button>
        </.form>

        <%= if @error do %>
          <.flash kind={:error} flash={%{"error" => @error}} />
        <% end %>
      </div>

      <%= if @transaction do %>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Transaction Details -->
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold mb-4">Transaction Details</h2>
            <dl class="space-y-2">
              <div>
                <dt class="font-medium text-gray-600">TXID:</dt>
                <dd class="text-sm font-mono break-all"><%= @transaction.txid %></dd>
              </div>
              <div>
                <dt class="font-medium text-gray-600">Block Height:</dt>
                <dd><%= @transaction.block_height || "Unconfirmed" %></dd>
              </div>
              <div>
                <dt class="font-medium text-gray-600">Confirmations:</dt>
                <dd><%= @transaction.confirmations || 0 %></dd>
              </div>
              <div>
                <dt class="font-medium text-gray-600">Size:</dt>
                <dd><%= @transaction.size %> bytes</dd>
              </div>
              <div>
                <dt class="font-medium text-gray-600">Virtual Size:</dt>
                <dd><%= @transaction.vsize %> vbytes</dd>
              </div>
            </dl>

            <%= if @metrics do %>
              <h3 class="text-lg font-semibold mt-6 mb-4">Transaction Metrics</h3>
              <dl class="space-y-2">
                <div>
                  <dt class="font-medium text-gray-600">Input Count:</dt>
                  <dd><%= @metrics.input_count %></dd>
                </div>
                <div>
                  <dt class="font-medium text-gray-600">Output Count:</dt>
                  <dd><%= @metrics.output_count %></dd>
                </div>
                <div>
                  <dt class="font-medium text-gray-600">Total Output Value:</dt>
                  <dd><%= @metrics.total_output_value %> BTC</dd>
                </div>
                <div>
                  <dt class="font-medium text-gray-600">Entropy (Placeholder):</dt>
                  <dd><%= Float.round(@metrics.entropy, 4) %></dd>
                </div>
              </dl>
            <% end %>
          </div>

          <!-- Transaction Graph -->
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold mb-4">Transaction Graph</h2>
            <div id="transaction-graph" phx-hook="TransactionGraph" class="w-full h-96 border border-gray-200 rounded"></div>
          </div>
        </div>

        <!-- Inputs and Outputs -->
        <div class="mt-8 grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Inputs -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold mb-4">Inputs (<%= length(@transaction.inputs) %>)</h3>
            <div class="space-y-3">
              <%= for input <- @transaction.inputs do %>
                <div class="border border-gray-200 rounded p-3">
                  <div class="text-sm">
                    <div class="font-medium">Previous TX:</div>
                    <div class="font-mono text-xs break-all text-gray-600"><%= input.previous_txid %></div>
                    <div class="mt-1">
                      <span class="font-medium">Output #:</span> <%= input.previous_vout %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Outputs -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold mb-4">Outputs (<%= length(@transaction.outputs) %>)</h3>
            <div class="space-y-3">
              <%= for output <- @transaction.outputs do %>
                <div class="border border-gray-200 rounded p-3">
                  <div class="text-sm">
                    <div class="flex justify-between">
                      <span class="font-medium">Value:</span>
                      <span class="font-mono"><%= output.value %> BTC</span>
                    </div>
                    <%= if output.address do %>
                      <div class="mt-1">
                        <div class="font-medium">Address:</div>
                        <div class="font-mono text-xs break-all text-gray-600"><%= output.address %></div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="mt-8 text-center">
          <.button phx-click="clear_analysis" class="bg-gray-500 hover:bg-gray-600">
            Clear Analysis
          </.button>
        </div>
      <% end %>
    </div>
    """
  end
end
