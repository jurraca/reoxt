
# Script for populating the database with test transaction data.
#
# We create a variety of transaction patterns:
# 1. Simple sends (1 input -> 1-2 outputs)
# 2. Amount splits (1 input -> multiple outputs)
# 3. Consolidations (multiple inputs -> 1 output)
# 4. Complex chains (transactions that reference each other)
# 5. Fan-out/fan-in patterns

alias Reoxt.Repo
alias Reoxt.Transactions
alias Reoxt.Transactions.{Transaction, TransactionInput, TransactionOutput}

# Clear existing data
Repo.delete_all(TransactionOutput)
Repo.delete_all(TransactionInput)
Repo.delete_all(Transaction)

# Genesis/Coinbase transaction (no inputs, only outputs)
IO.puts("Creating genesis transaction...")
{:ok, genesis} = Transactions.create_transaction_with_details(
  %{
    txid: "genesis_coinbase_000000000000000000000000000000000000000000000000000000000000",
    block_height: 1,
    timestamp: ~N[2023-01-01 00:00:00],
    fee: 0,
    size: 250,
    version: 1,
    locktime: 0
  },
  [], # No inputs for coinbase
  [
    %{
      value: 5000000000, # 50 BTC in satoshis
      n: 0,
      script_pub_key: "76a914genesis_address_hash88ac",
      address: "1GenesisAddress111111111111111111111",
      type: "pubkeyhash"
    }
  ]
) |> dbg()

# Simple send: Alice sends 10 BTC to Bob
IO.puts("Creating simple send transaction...")
{:ok, simple_send} = Transactions.create_transaction_with_details(
  %{
    txid: "simple_send_alice_to_bob_1111111111111111111111111111111111111111111111",
    block_height: 2,
    timestamp: ~N[2023-01-01 01:00:00],
    fee: 10000, # 0.0001 BTC fee
    size: 225,
    version: 1,
    locktime: 0
  },
  [
    %{
      txid: genesis.txid,
      vout: 0,
      script_sig: "signature_alice",
      sequence: 4294967295,
      value: 5000000000
    }
  ],
  [
    %{
      value: 1000000000, # 10 BTC to Bob
      n: 0,
      script_pub_key: "76a914bob_address_hash88ac",
      address: "1BobAddress111111111111111111111111",
      type: "pubkeyhash"
    },
    %{
      value: 3999990000, # 39.9999 BTC change back to Alice
      n: 1,
      script_pub_key: "76a914alice_change_hash88ac",
      address: "1AliceChangeAddr1111111111111111111",
      type: "pubkeyhash"
    }
  ]
)

# Amount split: Bob splits his 10 BTC to multiple recipients
IO.puts("Creating amount split transaction...")
{:ok, amount_split} = Transactions.create_transaction_with_details(
  %{
    txid: "amount_split_bob_to_many_222222222222222222222222222222222222222222",
    block_height: 3,
    timestamp: ~N[2023-01-01 02:00:00],
    fee: 15000,
    size: 350,
    version: 1,
    locktime: 0
  },
  [
    %{
      txid: simple_send.txid,
      vout: 0,
      script_sig: "signature_bob",
      sequence: 4294967295,
      value: 1000000000
    }
  ],
  [
    %{
      value: 200000000, # 2 BTC to Charlie
      n: 0,
      script_pub_key: "76a914charlie_address_hash88ac",
      address: "1CharlieAddr11111111111111111111111",
      type: "pubkeyhash"
    },
    %{
      value: 300000000, # 3 BTC to David
      n: 1,
      script_pub_key: "76a914david_address_hash88ac",
      address: "1DavidAddr111111111111111111111111",
      type: "pubkeyhash"
    },
    %{
      value: 150000000, # 1.5 BTC to Eve
      n: 2,
      script_pub_key: "76a914eve_address_hash88ac",
      address: "1EveAddr1111111111111111111111111",
      type: "pubkeyhash"
    },
    %{
      value: 334985000, # 3.34985 BTC change back to Bob
      n: 3,
      script_pub_key: "76a914bob_change_hash88ac",
      address: "1BobChangeAddr111111111111111111111",
      type: "pubkeyhash"
    }
  ]
)

# Consolidation: Multiple people send to Frank
IO.puts("Creating consolidation transaction...")
{:ok, consolidation} = Transactions.create_transaction_with_details(
  %{
    txid: "consolidation_many_to_frank_33333333333333333333333333333333333333333",
    block_height: 4,
    timestamp: ~N[2023-01-01 03:00:00],
    fee: 25000,
    size: 450,
    version: 1,
    locktime: 0
  },
  [
    %{
      txid: amount_split.txid,
      vout: 0, # Charlie's 2 BTC
      script_sig: "signature_charlie",
      sequence: 4294967295,
      value: 200000000
    },
    %{
      txid: amount_split.transaction.txid,
      vout: 1, # David's 3 BTC
      script_sig: "signature_david",
      sequence: 4294967295,
      value: 300000000
    },
    %{
      txid: amount_split.transaction.txid,
      vout: 2, # Eve's 1.5 BTC
      script_sig: "signature_eve",
      sequence: 4294967295,
      value: 150000000
    }
  ],
  [
    %{
      value: 624975000, # 6.24975 BTC to Frank (total minus fee)
      n: 0,
      script_pub_key: "76a914frank_address_hash88ac",
      address: "1FrankAddr111111111111111111111111",
      type: "pubkeyhash"
    }
  ]
)

# Chain continuation: Frank sends part of his BTC
IO.puts("Creating chain continuation transaction...")
{:ok, chain_continue} = Transactions.create_transaction_with_details(
  %{
    txid: "chain_continue_frank_to_grace_444444444444444444444444444444444444444",
    block_height: 5,
    timestamp: ~N[2023-01-01 04:00:00],
    fee: 12000,
    size: 225,
    version: 1,
    locktime: 0
  },
  [
    %{
      txid: consolidation.transaction.txid,
      vout: 0,
      script_sig: "signature_frank",
      sequence: 4294967295,
      value: 624975000
    }
  ],
  [
    %{
      value: 400000000, # 4 BTC to Grace
      n: 0,
      script_pub_key: "76a914grace_address_hash88ac",
      address: "1GraceAddr111111111111111111111111",
      type: "pubkeyhash"
    },
    %{
      value: 224963000, # 2.24963 BTC change back to Frank
      n: 1,
      script_pub_key: "76a914frank_change_hash88ac",
      address: "1FrankChangeAddr111111111111111111",
      type: "pubkeyhash"
    }
  ]
)

# Complex multi-sig transaction
IO.puts("Creating multi-sig transaction...")
{:ok, multisig_tx} = Transactions.create_transaction_with_details(
  %{
    txid: "multisig_transaction_555555555555555555555555555555555555555555555",
    block_height: 6,
    timestamp: ~N[2023-01-01 05:00:00],
    fee: 20000,
    size: 375,
    version: 1,
    locktime: 0
  },
  [
    %{
      txid: chain_continue.transaction.txid,
      vout: 0, # Grace's 4 BTC
      script_sig: "multisig_signature_grace",
      sequence: 4294967295,
      value: 400000000
    }
  ],
  [
    %{
      value: 379980000, # 3.7998 BTC to multi-sig address
      n: 0,
      script_pub_key: "a914multisig_script_hash87",
      address: "3MultiSigAddr11111111111111111111",
      type: "scripthash"
    }
  ]
)

# Fan-out pattern: One input creates many small outputs
IO.puts("Creating fan-out transaction...")
{:ok, fanout_tx} = Transactions.create_transaction_with_details(
  %{
    txid: "fanout_pattern_666666666666666666666666666666666666666666666666",
    block_height: 7,
    timestamp: ~N[2023-01-01 06:00:00],
    fee: 30000,
    size: 800,
    version: 1,
    locktime: 0
  },
  [
    %{
      txid: simple_send.transaction.txid,
      vout: 1, # Alice's change
      script_sig: "signature_alice_fanout",
      sequence: 4294967295,
      value: 3999990000
    }
  ],
  Enum.map(0..9, fn i ->
    %{
      value: 399000000, # 3.99 BTC each (10 outputs)
      n: i,
      script_pub_key: "76a914recipient_#{i}_hash88ac",
      address: "1Recipient#{i}Addr111111111111111111",
      type: "pubkeyhash"
    }
  end) ++ [
    %{
      value: 69960000, # 0.6996 BTC change
      n: 10,
      script_pub_key: "76a914alice_fanout_change_hash88ac",
      address: "1AliceFanoutChange111111111111111",
      type: "pubkeyhash"
    }
  ]
)

# Create some additional isolated transactions for graph complexity
IO.puts("Creating additional isolated transactions...")

# Another coinbase transaction (different block)
{:ok, coinbase2} = Transactions.create_transaction_with_details(
  %{
    txid: "coinbase2_block8_777777777777777777777777777777777777777777777777",
    block_height: 8,
    timestamp: ~N[2023-01-01 07:00:00],
    fee: 0,
    size: 250,
    version: 1,
    locktime: 0
  },
  [],
  [
    %{
      value: 5000000000, # 50 BTC
      n: 0,
      script_pub_key: "76a914miner2_address_hash88ac",
      address: "1Miner2Addr111111111111111111111111",
      type: "pubkeyhash"
    }
  ]
)

# Cross-chain reference: Use output from fanout in new transaction
{:ok, cross_chain} = Transactions.create_transaction_with_details(
  %{
    txid: "cross_chain_ref_888888888888888888888888888888888888888888888888",
    block_height: 9,
    timestamp: ~N[2023-01-01 08:00:00],
    fee: 18000,
    size: 450,
    version: 1,
    locktime: 0
  },
  [
    %{
      txid: fanout_tx.transaction.txid,
      vout: 0, # Recipient0's output
      script_sig: "signature_recipient0",
      sequence: 4294967295,
      value: 399000000
    },
    %{
      txid: fanout_tx.transaction.txid,
      vout: 1, # Recipient1's output
      script_sig: "signature_recipient1",
      sequence: 4294967295,
      value: 399000000
    },
    %{
      txid: coinbase2.transaction.txid,
      vout: 0, # Miner2's coinbase
      script_sig: "signature_miner2",
      sequence: 4294967295,
      value: 5000000000
    }
  ],
  [
    %{
      value: 2000000000, # 20 BTC to final recipient
      n: 0,
      script_pub_key: "76a914final_recipient_hash88ac",
      address: "1FinalRecipient11111111111111111111",
      type: "pubkeyhash"
    },
    %{
      value: 3797982000, # 37.97982 BTC change
      n: 1,
      script_pub_key: "76a914cross_chain_change_hash88ac",
      address: "1CrossChainChange111111111111111111",
      type: "pubkeyhash"
    }
  ]
)

# Circular reference pattern: Create a more complex graph
{:ok, circular1} = Transactions.create_transaction_with_details(
  %{
    txid: "circular_part1_999999999999999999999999999999999999999999999999",
    block_height: 10,
    timestamp: ~N[2023-01-01 09:00:00],
    fee: 15000,
    size: 300,
    version: 1,
    locktime: 0
  },
  [
    %{
      txid: cross_chain.transaction.txid,
      vout: 1, # Cross chain change
      script_sig: "signature_circular1",
      sequence: 4294967295,
      value: 3797982000
    }
  ],
  [
    %{
      value: 1000000000, # 10 BTC
      n: 0,
      script_pub_key: "76a914circular_addr1_hash88ac",
      address: "1CircularAddr111111111111111111111",
      type: "pubkeyhash"
    },
    %{
      value: 2797967000, # 27.97967 BTC
      n: 1,
      script_pub_key: "76a914circular_addr2_hash88ac",
      address: "1CircularAddr211111111111111111111",
      type: "pubkeyhash"
    }
  ]
)

{:ok, circular2} = Transactions.create_transaction_with_details(
  %{
    txid: "circular_part2_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    block_height: 11,
    timestamp: ~N[2023-01-01 10:00:00],
    fee: 12000,
    size: 280,
    version: 1,
    locktime: 0
  },
  [
    %{
      txid: circular1.transaction.txid,
      vout: 0, # 10 BTC from circular1
      script_sig: "signature_circular2",
      sequence: 4294967295,
      value: 1000000000
    }
  ],
  [
    %{
      value: 500000000, # 5 BTC
      n: 0,
      script_pub_key: "76a914circular_addr3_hash88ac",
      address: "1CircularAddr311111111111111111111",
      type: "pubkeyhash"
    },
    %{
      value: 487988000, # 4.87988 BTC
      n: 1,
      script_pub_key: "76a914circular_addr4_hash88ac",
      address: "1CircularAddr411111111111111111111",
      type: "pubkeyhash"
    }
  ]
)

IO.puts("Seed data created successfully!")

# Print summary
IO.puts("\n=== TRANSACTION SUMMARY ===")
IO.puts("Genesis coinbase: #{genesis.transaction.txid}")
IO.puts("Simple send: #{simple_send.transaction.txid}")
IO.puts("Amount split: #{amount_split.transaction.txid}")
IO.puts("Consolidation: #{consolidation.transaction.txid}")
IO.puts("Chain continuation: #{chain_continue.transaction.txid}")
IO.puts("Multi-sig: #{multisig_tx.transaction.txid}")
IO.puts("Fan-out: #{fanout_tx.transaction.txid}")
IO.puts("Second coinbase: #{coinbase2.transaction.txid}")
IO.puts("Cross-chain: #{cross_chain.transaction.txid}")
IO.puts("Circular part 1: #{circular1.transaction.txid}")
IO.puts("Circular part 2: #{circular2.transaction.txid}")

total_transactions = Repo.aggregate(Transaction, :count)
total_inputs = Repo.aggregate(TransactionInput, :count)
total_outputs = Repo.aggregate(TransactionOutput, :count)

IO.puts("\nTotal transactions: #{total_transactions}")
IO.puts("Total inputs: #{total_inputs}")
IO.puts("Total outputs: #{total_outputs}")
IO.puts("\nDatabase seeded with comprehensive transaction graph!")
