
defmodule Reoxt do
  @moduledoc """
  Reoxt keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  
  alias Reoxt.BitcoinAnalyzer
  
  defdelegate get_transaction(txid), to: BitcoinAnalyzer
  defdelegate analyze_transaction(txid), to: BitcoinAnalyzer
  defdelegate get_transaction_graph(txid), to: BitcoinAnalyzer
end
