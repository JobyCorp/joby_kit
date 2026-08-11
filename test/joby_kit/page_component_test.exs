defmodule JobyKit.PageComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias JobyKit.PageComponent

  test "page_component renders the four kit sections" do
    html = render_component(&PageComponent.page_component/1, manifest: JobyKit.Test.Manifest)

    assert html =~ ~s(data-jobykit-page="kit")
    assert html =~ "design-system-decision-tree"
    assert html =~ "design-system-wrapper-contract"
    assert html =~ "design-system-index"
    assert html =~ "design-system-daisyui"
  end

  test "page_component shows only :core entries on the kit surface" do
    html = render_component(&PageComponent.page_component/1, manifest: JobyKit.Test.Manifest)

    # Both registered entries are :core in the test manifest, both should render.
    assert html =~ "design-category-core"
    assert html =~ ~s(data-function="button")
    assert html =~ ~s(data-function="badge")

    # No composite/domain category articles render.
    refute html =~ "design-category-composite"
    refute html =~ "design-category-domain"
  end

  test "page_component renders the agent-redirect callout when custom_path is set" do
    html =
      render_component(&PageComponent.page_component/1,
        manifest: JobyKit.Test.Manifest,
        custom_path: "/custom-designs"
      )

    assert html =~ "design-system-agent-redirect"
    assert html =~ ~s(href="/custom-designs")
  end

  test "page_component omits the agent-redirect callout when custom_path is nil" do
    html = render_component(&PageComponent.page_component/1, manifest: JobyKit.Test.Manifest)
    refute html =~ "design-system-agent-redirect"
  end

  test "custom_page_component renders only non-:core entries and a back-link" do
    defmodule MultiCategoryManifest do
      use JobyKit.Manifest

      alias JobyKit.Test.Components

      category :core, label: "Core", description: ""
      category :composite, label: "Composites", description: ""
      category :domain, label: "Domain", description: ""

      component Components, :button, category: :core, summary: "core entry"
      component Components, :badge, category: :composite, summary: "composite entry"
    end

    html =
      render_component(&PageComponent.custom_page_component/1,
        manifest: MultiCategoryManifest,
        back_to: "/design"
      )

    assert html =~ ~s(data-jobykit-page="custom")
    assert html =~ ~s(href="/design")
    assert html =~ "design-category-composite"

    # :core never surfaces here even when it's in the manifest.
    refute html =~ "design-category-core"
    refute html =~ ~s(data-function="button")

    # Composites (and domain) entries do.
    assert html =~ ~s(data-function="badge")
  end
end
