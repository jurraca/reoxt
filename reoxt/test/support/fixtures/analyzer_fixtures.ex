defmodule Reoxt.AnalyzerFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Reoxt.Analyzer` context.
  """

  @doc """
  Generate a bitcoin_rpc.
  """
  def bitcoin_rpc_fixture(attrs \\ %{}) do
    {:ok, bitcoin_rpc} =
      attrs
      |> Enum.into(%{
        host: "some host",
        password: "some password",
        port: 42,
        username: "some username"
      })
      |> Reoxt.Analyzer.create_bitcoin_rpc()

    bitcoin_rpc
  end
end
