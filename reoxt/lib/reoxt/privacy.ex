
defmodule Reoxt.Privacy do
  @moduledoc """
  The Privacy context for transaction privacy analysis.
  """

  alias Reoxt.Privacy.Boltzmann

  @doc """
  Calculate the entropy of a transaction using the Boltzmann method.
  Returns the Shannon entropy (log2 of possible combinations).
  """
  def calculate_entropy(transaction) do
    Boltzmann.calculate_entropy(transaction)
  end

  @doc """
  Analyze transaction for all possible input/output mappings.
  Returns detailed analysis including combinations and deterministic links.
  """
  def analyze_transaction(transaction) do
    Boltzmann.analyze_transaction(transaction)
  end
end
