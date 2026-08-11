defmodule JobyKit.KitManifestE2ETest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  # The install template registers JobyKit's own components in every host.
  # Nothing exercised that combination: the fixtures use simple test
  # components, so enrichment never saw a Phoenix.HTML.FormField attr type
  # or a `&Function.identity/1` default. If enrich/1 or the JSON
  # serializer choked on those, /design and /design.json would 500 in
  # every app at once while the suite stayed green.
  defmodule KitManifest do
    use JobyKit.Manifest

    alias JobyKit.CoreComponents
    alias JobyKit.NavComponent

    category(:core, label: "Core wrappers", description: "Shipped by JobyKit.")

    for name <- ~w(badge button card eyebrow flash flash_group header input list modal table
                   theme_toggle icon)a do
      component(CoreComponents, name, category: :core, summary: "Kit component.")
    end

    component(NavComponent, :simple_nav, category: :core, summary: "Kit nav.")
  end

  setup do
    Code.ensure_loaded!(JobyKit.CoreComponents)
    Code.ensure_loaded!(JobyKit.NavComponent)
    Code.ensure_loaded!(KitManifest)
    :ok
  end

  test "every kit component enriches without raising" do
    entries = KitManifest.entries()

    assert length(entries) == 14

    for entry <- entries do
      assert is_list(entry.attrs), "#{entry.data_component} has no attrs list"
      assert is_list(entry.slots)
      assert entry.data_component =~ "JobyKit."
    end
  end

  test "the trickiest attr shapes survive enrichment" do
    input = KitManifest.fetch(JobyKit.CoreComponents, :input)
    table = KitManifest.fetch(JobyKit.CoreComponents, :table)

    # Phoenix.HTML.FormField is a struct type; row_item defaults to a
    # function capture. Both go through format_type/format_default.
    assert Enum.any?(input.attrs, &(&1.name == "field"))
    assert Enum.any?(table.attrs, &(&1.name == "row_item"))

    for attr <- input.attrs ++ table.attrs do
      assert is_binary(attr.type)
      assert is_binary(attr.name)
    end
  end

  test "the whole manifest is JSON-encodable, as /design.json requires" do
    payload = %{
      components:
        Enum.map(KitManifest.entries(), fn e ->
          %{
            module: inspect(e.module),
            function: e.function,
            data_component: e.data_component,
            forked_from_kit: e.forked_from_kit,
            attrs: e.attrs,
            slots: e.slots
          }
        end)
    }

    assert {:ok, json} = Jason.encode(payload)
    assert {:ok, decoded} = Jason.decode(json)
    assert length(decoded["components"]) == 14
  end

  test "the kit's own components satisfy the kit's own contract" do
    # If the linter's per-entry checks fail against JobyKit itself, the
    # contract every host is held to is one the kit doesn't meet.
    violations =
      JobyKit.Lint.run(manifest: KitManifest, paths: [])
      |> Enum.reject(&(&1.rule in [:unregistered_wrapper, :unmarked_component]))

    assert violations == [],
           "kit components violate the contract: " <>
             Enum.map_join(violations, "\n", &"#{&1.rule}: #{&1.message}")
  end

  test "every registered kit component renders through the signature card" do
    # SignatureComponent is what /design draws for each entry; a crash
    # here takes the whole page with it.
    for entry <- KitManifest.entries() do
      html = render_component(&JobyKit.SignatureComponent.signature_card/1, entry: entry)

      assert html =~ entry.data_component
      assert html =~ "data-component-signature"
    end
  end
end
