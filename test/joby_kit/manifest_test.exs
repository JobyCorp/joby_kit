defmodule JobyKit.ManifestTest do
  use ExUnit.Case, async: true

  alias JobyKit.Test.Manifest

  setup do
    # Generator tests run Mix.Project.in_project/4 which can purge and
    # reload test/support modules. That wipes Phoenix.Component's
    # compile-time __components__/0 metadata. Force-reload the test
    # components so introspection sees the attrs we declared.
    Code.ensure_loaded!(JobyKit.Test.Components)
    Code.ensure_loaded!(JobyKit.Test.Manifest)
    :ok
  end

  test "registers categories in declaration order" do
    assert Manifest.categories() == [:core, :composite]
  end

  test "category_label/1 returns the declared label" do
    assert Manifest.category_label(:core) == "Core wrappers"
    assert Manifest.category_label(:composite) == "Composites"
  end

  test "category_label/1 raises for unknown categories" do
    assert_raise ArgumentError, fn -> Manifest.category_label(:nope) end
  end

  test "category_description/1 returns declared description" do
    assert Manifest.category_description(:core) == "Pure daisy wrappers."
  end

  test "entries/0 enriches each registration with introspected metadata" do
    entries = Manifest.entries()
    assert length(entries) == 2

    button = Enum.find(entries, &(&1.function == :button))
    assert button.module == JobyKit.Test.Components
    assert button.category == :core
    assert button.daisy_basis == "btn"
    assert button.summary == "A button."
    assert button.label == "Button"
    assert button.data_component == "JobyKit.Test.Components.button"
    assert is_function(button.preview, 1)

    # Attrs are introspected from the host component (variant + tone, not
    # :rest or :class which the enrich helper drops).
    attr_names = Enum.map(button.attrs, & &1.name)
    assert "variant" in attr_names
    assert "tone" in attr_names
    refute "rest" in attr_names
    refute "class" in attr_names

    variant_attr = Enum.find(button.attrs, &(&1.name == "variant"))
    assert variant_attr.values == ["solid", "soft", "outline", "ghost", "link"]
    assert variant_attr.default == "soft"
  end

  test "by_category/0 groups entries and preserves category order" do
    [{first_cat, _}, {second_cat, _}] = Manifest.by_category()
    assert first_cat == :core
    assert second_cat == :composite
  end

  test "fetch/2 finds the registered entry, nil otherwise" do
    entry = Manifest.fetch(JobyKit.Test.Components, :button)
    assert entry.function == :button

    assert Manifest.fetch(JobyKit.Test.Components, :nope) == nil
  end

  describe "forked_from_kit?/2" do
    test "a kit-named component owned by the host is a fork" do
      # airo does `import JobyKit.CoreComponents, except: [button: 1, table: 1]`
      # and registers its own — which is why the 0.2.1 table/1 fix shipped
      # into a component airo never renders.
      assert JobyKit.Manifest.forked_from_kit?(SomeAppWeb.CoreComponents, :button)
      assert JobyKit.Manifest.forked_from_kit?(SomeAppWeb.CoreComponents, :table)
    end

    test "the kit's own components are never forks" do
      refute JobyKit.Manifest.forked_from_kit?(JobyKit.CoreComponents, :button)
    end

    test "a host component the kit does not ship is not a fork" do
      refute JobyKit.Manifest.forked_from_kit?(SomeAppWeb.CompositeComponents, :empty_state)
      refute JobyKit.Manifest.forked_from_kit?(SomeAppWeb.ChatComponents, :composer)
    end

    test "entries carry the flag so /design.json can report it" do
      entry = JobyKit.Test.Manifest.entries() |> hd()
      assert Map.has_key?(entry, :forked_from_kit)
    end
  end

  describe "compile-time validation" do
    test "an undeclared category is a compile error, not silent invisibility" do
      # by_category/0 only walks declared categories, so an entry under a
      # typo'd one vanishes from /design and /custom-designs while still
      # appearing in entries() and /design.json.
      assert_raise ArgumentError, ~r/category :cor, which is not declared/, fn ->
        JobyKit.Manifest.validate_categories!(
          FakeManifest,
          [{JobyKit.Test.Components, :button, [category: :cor]}],
          [{:core, label: "Core", description: "x"}]
        )
      end
    end

    test "the error names the categories that do exist" do
      err =
        assert_raise ArgumentError, fn ->
          JobyKit.Manifest.validate_categories!(
            FakeManifest,
            [{JobyKit.Test.Components, :button, [category: :nope]}],
            [{:core, label: "Core", description: "x"}, {:composite, label: "C", description: "y"}]
          )
        end

      assert Exception.message(err) =~ ":composite, :core"
    end

    test "a declared category passes" do
      assert :ok ==
               JobyKit.Manifest.validate_categories!(
                 FakeManifest,
                 [{JobyKit.Test.Components, :button, [category: :core]}],
                 [{:core, label: "Core", description: "x"}]
               )
    end

    test "an anonymous preview is rejected with an actionable message" do
      # Stored at compile time, so it hits Macro.escape and dies with
      # "cannot escape #Function<...>" — which names no component.
      assert_raise ArgumentError, ~r/anonymous preview function/, fn ->
        JobyKit.Manifest.validate_categories!(
          FakeManifest,
          [{JobyKit.Test.Components, :button, [category: :core, preview: fn _ -> nil end]}],
          [{:core, label: "Core", description: "x"}]
        )
      end
    end

    test "a remote capture preview passes" do
      assert :ok ==
               JobyKit.Manifest.validate_categories!(
                 FakeManifest,
                 [
                   {JobyKit.Test.Components, :button,
                    [category: :core, preview: &JobyKit.Test.DesignPreviews.button_preview/1]}
                 ],
                 [{:core, label: "Core", description: "x"}]
               )
    end
  end

  describe "category lookups are consistently strict" do
    test "both label and description raise on an unknown category" do
      # They disagreed: label raised, description returned "". A caller
      # got either a crash or silently blank prose depending on which it
      # happened to call.
      assert_raise ArgumentError, fn -> JobyKit.Test.Manifest.category_label(:nope) end
      assert_raise ArgumentError, fn -> JobyKit.Test.Manifest.category_description(:nope) end
    end
  end
end
