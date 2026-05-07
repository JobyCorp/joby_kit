defmodule JobyKit.ContractTest do
  use ExUnit.Case, async: true

  alias JobyKit.Contract

  test "build_order returns five steps with stable shape" do
    steps = Contract.build_order()
    assert length(steps) == 5
    assert Enum.map(steps, & &1.step) == [1, 2, 3, 4, 5]
    assert Enum.all?(steps, &(is_binary(&1.title) and is_binary(&1.description)))
    assert Enum.all?(steps, &(&1.tone in [:neutral, :warning, :error]))
  end

  test "rules returns five wrapper-contract entries with stable keys" do
    rules = Contract.rules()
    assert length(rules) == 5

    keys = Enum.map(rules, & &1.key)
    assert keys == ["attrs", "data-component", "rest-global", "tokens-only", "design-page"]

    assert Enum.all?(rules, &(is_binary(&1.title) and is_binary(&1.body)))
  end

  test "taxonomy returns three layers (core, composite, domain)" do
    layers = Contract.taxonomy()
    assert Enum.map(layers, & &1.layer) == [:core, :composite, :domain]
    assert Enum.all?(layers, &(is_binary(&1.title) and is_binary(&1.body)))
  end
end
