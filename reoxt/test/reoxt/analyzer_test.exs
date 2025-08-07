defmodule Reoxt.AnalyzerTest do
  use Reoxt.DataCase

  alias Reoxt.Analyzer

  describe "bitcoin_rpc_configs" do
    alias Reoxt.Analyzer.BitcoinRpc

    import Reoxt.AnalyzerFixtures

    @invalid_attrs %{host: nil, password: nil, port: nil, username: nil}

    test "list_bitcoin_rpc_configs/0 returns all bitcoin_rpc_configs" do
      bitcoin_rpc = bitcoin_rpc_fixture()
      assert Analyzer.list_bitcoin_rpc_configs() == [bitcoin_rpc]
    end

    test "get_bitcoin_rpc!/1 returns the bitcoin_rpc with given id" do
      bitcoin_rpc = bitcoin_rpc_fixture()
      assert Analyzer.get_bitcoin_rpc!(bitcoin_rpc.id) == bitcoin_rpc
    end

    test "create_bitcoin_rpc/1 with valid data creates a bitcoin_rpc" do
      valid_attrs = %{host: "some host", password: "some password", port: 42, username: "some username"}

      assert {:ok, %BitcoinRpc{} = bitcoin_rpc} = Analyzer.create_bitcoin_rpc(valid_attrs)
      assert bitcoin_rpc.host == "some host"
      assert bitcoin_rpc.password == "some password"
      assert bitcoin_rpc.port == 42
      assert bitcoin_rpc.username == "some username"
    end

    test "create_bitcoin_rpc/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Analyzer.create_bitcoin_rpc(@invalid_attrs)
    end

    test "update_bitcoin_rpc/2 with valid data updates the bitcoin_rpc" do
      bitcoin_rpc = bitcoin_rpc_fixture()
      update_attrs = %{host: "some updated host", password: "some updated password", port: 43, username: "some updated username"}

      assert {:ok, %BitcoinRpc{} = bitcoin_rpc} = Analyzer.update_bitcoin_rpc(bitcoin_rpc, update_attrs)
      assert bitcoin_rpc.host == "some updated host"
      assert bitcoin_rpc.password == "some updated password"
      assert bitcoin_rpc.port == 43
      assert bitcoin_rpc.username == "some updated username"
    end

    test "update_bitcoin_rpc/2 with invalid data returns error changeset" do
      bitcoin_rpc = bitcoin_rpc_fixture()
      assert {:error, %Ecto.Changeset{}} = Analyzer.update_bitcoin_rpc(bitcoin_rpc, @invalid_attrs)
      assert bitcoin_rpc == Analyzer.get_bitcoin_rpc!(bitcoin_rpc.id)
    end

    test "delete_bitcoin_rpc/1 deletes the bitcoin_rpc" do
      bitcoin_rpc = bitcoin_rpc_fixture()
      assert {:ok, %BitcoinRpc{}} = Analyzer.delete_bitcoin_rpc(bitcoin_rpc)
      assert_raise Ecto.NoResultsError, fn -> Analyzer.get_bitcoin_rpc!(bitcoin_rpc.id) end
    end

    test "change_bitcoin_rpc/1 returns a bitcoin_rpc changeset" do
      bitcoin_rpc = bitcoin_rpc_fixture()
      assert %Ecto.Changeset{} = Analyzer.change_bitcoin_rpc(bitcoin_rpc)
    end
  end
end
