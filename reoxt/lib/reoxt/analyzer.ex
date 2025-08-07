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
end
