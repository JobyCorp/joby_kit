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

  test "docs_url/1 derives a slug from a bare primitive name" do
    assert DaisyCatalogue.docs_url("Button") == "https://daisyui.com/components/button/"
    assert DaisyCatalogue.docs_url("Radial progress") == "https://daisyui.com/components/radial-progress/"
  end

  test "docs_url/1 honours an entry's docs_slug over its display name" do
    # Deriving from the display name 404s wherever our label differs from
    # daisy's URL. Each of these was a live 404 before the override existed;
    # the replacements were verified against daisyui.com.
    expected = %{
      fab: "fab",
      chat_bubble: "chat",
      text_input: "input",
      drawer: "drawer",
      browser_mockup: "mockup-browser",
      code_mockup: "mockup-code",
      phone_mockup: "mockup-phone",
      window_mockup: "mockup-window",
      mega_menu: "megamenu"
    }

    entries =
      for category <- DaisyCatalogue.categories(),
          component <- category.components,
          into: %{},
          do: {component.id, component}

    for {id, slug} <- expected do
      assert DaisyCatalogue.docs_url(entries[id]) ==
               "https://daisyui.com/components/#{slug}/",
             "#{id} should document against /components/#{slug}/"
    end
  end

  @tag :external
  test "every catalogue docs_url resolves on daisyui.com" do
    # Excluded by default (needs network). Run with:
    #   mix test --include external
    # This is the only honest way to catch slug drift — the derived slug
    # can't be validated offline, and daisy renames doc pages between
    # minors. Eight entries were live 404s before docs_slug existed.
    broken =
      for category <- DaisyCatalogue.categories(),
          component <- category.components,
          url = DaisyCatalogue.docs_url(component),
          {out, 0} = System.cmd("curl", ["-s", "-o", "/dev/null", "-w", "%{http_code}", "-L", "--max-time", "10", url]),
          out != "200" do
        "#{component.id} -> #{url} (HTTP #{out})"
      end

    assert broken == [], "broken daisyUI docs links:\n" <> Enum.join(broken, "\n")
  end

  test "declares the daisyUI version the catalogue was verified against" do
    assert DaisyCatalogue.daisy_version() =~ ~r/^\d+\.\d+\.\d+$/
  end

  test "post-5.0 primitives are present and marked with the version that added them" do
    # A host on an older vendored bundle will not have these classes at all,
    # so the catalogue has to say which daisy release introduced each.
    since =
      for category <- DaisyCatalogue.categories(),
          component <- category.components,
          Map.has_key?(component, :since),
          into: %{},
          do: {component.id, component.since}

    assert since[:hover_gallery] == "5.1"
    assert since[:hover_3d] == "5.5"
    assert since[:text_rotate] == "5.5"
    assert since[:aura] == "5.6"
    assert since[:mega_menu] == "5.6"
    assert since[:otp] == "5.6"
  end

  test "every :since entry says so in its note, so it renders on the page" do
    for category <- DaisyCatalogue.categories(),
        component <- category.components,
        version = component[:since] do
      assert component[:note] =~ version,
             "#{component.id} is :since #{version} but its note does not mention it"
    end
  end

  test "no demo uses a class daisyUI 4 removed" do
    # card-compact and label-text were dropped in daisy 5; demos carrying
    # them teach a dead API on the page that is meant to be the reference.
    for category <- DaisyCatalogue.categories(),
        component <- category.components do
      html = render_component(&DaisyCatalogue.demo/1, id: component.id)

      refute html =~ "card-compact", "#{component.id} demo uses removed card-compact"
      refute html =~ "label-text", "#{component.id} demo uses removed label-text"
    end
  end
end
