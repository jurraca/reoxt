
defmodule Reoxt.Privacy.Boltzmann do
  @moduledoc """
  Implementation of the Boltzmann method for calculating transaction entropy.
  
  Based on the research by Greg Maxwell, this calculates the Shannon entropy
  of a transaction by determining how many possible mappings of inputs to
  outputs are mathematically possible given only the transaction values.
  
  Formula: E = log2(N)
  Where:
  - E = entropy of the transaction
  - N = number of possible combinations (mappings of inputs to outputs)
  """

  require Logger

  @doc """
  Calculate the entropy of a transaction.
  
  Returns a map with:
  - entropy: The Shannon entropy (log2 of combinations)
  - combinations: Number of possible input/output mappings
  - deterministic_links: Links that are certain regardless of interpretation
  """
  def calculate_entropy(transaction) do
    with {:ok, analysis} <- analyze_transaction(transaction) do
      entropy = if analysis.combinations > 0 do
        :math.log2(analysis.combinations)
      else
        0.0
      end

      Map.put(analysis, :entropy, entropy)
    end
  end

  @doc """
  Analyze a transaction to find all possible input/output mappings.

  This implements the core Boltzmann analysis algorithm.
  """
  def analyze_transaction(%{inputs: []}) do
    {:ok, %{
      combinations: 1,
      entropy: 0.0,
      deterministic_links: [],
      interpretation: "coinbase",
      analysis_type: "coinbase_transaction"
    }}
  end

  def analyze_transaction(%{outputs: []}), do: {:error, "outputs to the transaction are empty"}

  def analyze_transaction(%{inputs: inputs, outputs: outputs} = transaction) do
    input_values = Enum.map(inputs, & &1.value)
    input_total = Enum.sum(input_values)

    output_values = Enum.map(outputs, & &1.n |> then(fn n ->
      Enum.find(outputs, &(&1.n == n)).value
    end))
    output_total = Enum.sum(output_values)

    cond do
      input_total != output_total ->
        # Invalid transaction (shouldn't happen with proper data)
        # account for fees diff
        {:error, "Input/output value mismatch"}

      true ->
        perform_combinatorial_analysis(input_values, output_values, inputs, outputs)
    end
  end

  # Main combinatorial analysis
  defp perform_combinatorial_analysis(input_values, output_values, inputs, outputs) do
    # Generate all possible partitions of inputs
    input_partitions = generate_partitions(input_values)
    
    # For each partition, check if it can map to output partitions
    valid_mappings = 
      input_partitions
      |> Enum.flat_map(fn input_partition ->
        output_partitions = generate_partitions(output_values)
        
        output_partitions
        |> Enum.filter(fn output_partition ->
          can_map_partitions?(input_partition, output_partition)
        end)
        |> Enum.map(fn output_partition ->
          {input_partition, output_partition}
        end)
      end)
      |> Enum.uniq()

    # Find deterministic links (links that appear in ALL valid mappings)
    deterministic_links = find_deterministic_links(valid_mappings, inputs, outputs)

    # Count unique valid mappings
    combinations = length(valid_mappings)

    {:ok, %{
      combinations: combinations,
      deterministic_links: deterministic_links,
      valid_mappings: valid_mappings,
      analysis_type: classify_transaction_type(length(inputs), length(outputs), combinations)
    }}
  end

  # Generate all possible partitions of a list of values
  defp generate_partitions([]), do: [[]]
  defp generate_partitions([value | rest]) do
    rest_partitions = generate_partitions(rest)
    
    # For each existing partition, we can either:
    # 1. Add the value to an existing subset
    # 2. Create a new subset with just this value
    Enum.flat_map(rest_partitions, fn partition ->
      # Add to existing subsets
      existing_additions = 
        partition
        |> Enum.with_index()
        |> Enum.map(fn {subset, index} ->
          List.replace_at(partition, index, [value | subset])
        end)
      
      # Create new subset
      new_subset_addition = [[value] | partition]
      
      [new_subset_addition | existing_additions]
    end)
  end

  # Check if input partition can map to output partition (same total values)
  defp can_map_partitions?(input_partition, output_partition) do
    input_sums = Enum.map(input_partition, &Enum.sum/1) |> Enum.sort()
    output_sums = Enum.map(output_partition, &Enum.sum/1) |> Enum.sort()
    
    input_sums == output_sums
  end

  # Find links that appear in ALL valid mappings (deterministic)
  defp find_deterministic_links(valid_mappings, inputs, outputs) do
    if length(valid_mappings) <= 1 do
      # If there's only one mapping, all links are deterministic
      case valid_mappings do
        [{input_partition, output_partition}] ->
          create_deterministic_links(input_partition, output_partition, inputs, outputs)
        [] ->
          []
      end
    else
      # Find links that appear in ALL mappings
      all_links = 
        valid_mappings
        |> Enum.map(fn {input_partition, output_partition} ->
          create_deterministic_links(input_partition, output_partition, inputs, outputs)
        end)
      
      # Find intersection of all link sets
      case all_links do
        [first | rest] ->
          Enum.reduce(rest, first, fn links, acc ->
            Enum.filter(acc, fn link ->
              Enum.any?(links, fn other_link ->
                same_link?(link, other_link)
              end)
            end)
          end)
        [] ->
          []
      end
    end
  end

  # Create deterministic links from a specific mapping
  defp create_deterministic_links(input_partition, output_partition, inputs, outputs) do
    # This is a simplified version - in practice, you'd need to track
    # which specific inputs/outputs are linked in this mapping
    # For now, return empty list as this requires more complex tracking
    []
  end

  # Check if two links are the same
  defp same_link?(link1, link2) do
    link1.input_indices == link2.input_indices and 
    link1.output_indices == link2.output_indices
  end

  # Classify the transaction type based on structure and entropy
  defp classify_transaction_type(input_count, output_count, combinations) do
    cond do
      input_count == 1 and output_count == 1 ->
        "simple_send"
      
      input_count == 1 and output_count == 2 and combinations == 1 ->
        "basic_payment"
      
      input_count == 1 and output_count > 2 ->
        "amount_split"
      
      input_count > 1 and output_count == 1 ->
        "consolidation"
      
      combinations == 1 ->
        "unambiguous"
      
      combinations == 2 ->
        "ambiguous_low"
      
      combinations > 2 and combinations <= 10 ->
        "ambiguous_medium"
      
      combinations > 10 ->
        "ambiguous_high"
      
      true ->
        "complex"
    end
  end

  @doc """
  Calculate entropy for multiple transactions in batch.
  """
  def batch_calculate_entropy(transactions) do
    transactions
    |> Enum.map(fn transaction ->
      case calculate_entropy(transaction) do
        {:ok, analysis} ->
          {transaction.txid, analysis}
        {:error, reason} ->
          {transaction.txid, %{error: reason}}
      end
    end)
    |> Map.new()
  end

  @doc """
  Get entropy statistics for a list of entropy values.
  """
  def entropy_statistics(entropy_values) do
    valid_entropies = Enum.reject(entropy_values, &is_nil/1)
    
    if length(valid_entropies) > 0 do
      %{
        count: length(valid_entropies),
        min: Enum.min(valid_entropies),
        max: Enum.max(valid_entropies),
        average: Enum.sum(valid_entropies) / length(valid_entropies),
        median: calculate_median(valid_entropies)
      }
    else
      %{
        count: 0,
        min: nil,
        max: nil,
        average: nil,
        median: nil
      }
    end
  end

  defp calculate_median([]), do: nil
  defp calculate_median(values) do
    sorted = Enum.sort(values)
    length = length(sorted)
    
    if rem(length, 2) == 0 do
      middle_right = div(length, 2)
      middle_left = middle_right - 1
      (Enum.at(sorted, middle_left) + Enum.at(sorted, middle_right)) / 2
    else
      Enum.at(sorted, div(length, 2))
    end
  end
end
