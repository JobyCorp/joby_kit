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
end
