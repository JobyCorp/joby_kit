defmodule JobyKit.DaisyCatalogueTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias JobyKit.DaisyCatalogue

  test "categories/0 returns the seven daisy categories" do
    cats = DaisyCatalogue.categories()
    assert length(cats) == 7
    assert Enum.map(cats, & &1.name) == [
             "Actions",
             "Data display",
             "Navigation",
             "Feedback",
             "Data input",
             "Layout",
             "Mockup"
           ]
  end

  test "every component entry has a stable atom :id" do
    for category <- DaisyCatalogue.categories(),
        component <- category.components do
      assert is_atom(component.id), "expected id atom for #{component.name}"
      assert component.default_status in [:available, :reference]
    end
  end

  test "merged/1 leaves entries at default_status when manifest has no overrides" do
    defmodule NoOverridesManifest do
      use JobyKit.Manifest
      category :core, label: "Core", description: ""
    end

    [actions | _] = DaisyCatalogue.merged(NoOverridesManifest)
    button = Enum.find(actions.components, &(&1.id == :button))
    assert button.status == :available
    assert button.wrapper == nil
    assert button.anchor == nil
  end

  test "merged/1 flips overridden entries to :wrapped and attaches wrapper + anchor" do
    [actions | rest] = DaisyCatalogue.merged(JobyKit.Test.Manifest)
    button = Enum.find(actions.components, &(&1.id == :button))

    assert button.status == :wrapped
    assert button.wrapper == "<.button>"
    assert button.anchor == "#button"

    # Non-overridden entries remain at their default status
    dropdown = Enum.find(actions.components, &(&1.id == :dropdown))
    assert dropdown.status == :available

    # Reference-default entries also stay at :reference
    [_, _, _, _, _, _, mockup] = [actions | rest]
    browser = Enum.find(mockup.components, &(&1.id == :browser_mockup))
    assert browser.status == :reference
  end

  test "demo/1 renders for every catalogue id" do
    for category <- DaisyCatalogue.categories(),
        component <- category.components do
      html = render_component(&DaisyCatalogue.demo/1, id: component.id)
      assert is_binary(html), "demo/1 must render html for #{component.id}"
      assert html != "", "demo/1 returned empty for #{component.id}"
    end
  end

  test "docs_url/1 builds a daisyUI docs URL from a primitive name" do
    assert DaisyCatalogue.docs_url("Button") == "https://daisyui.com/components/button/"

    assert DaisyCatalogue.docs_url("FAB / Speed Dial") ==
             "https://daisyui.com/components/fab-speed-dial/"
  end
end
