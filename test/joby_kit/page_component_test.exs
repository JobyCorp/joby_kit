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

  test "the kit surface shows kit-owned components, whatever category they declare" do
    defmodule KitOwnedManifest do
      use JobyKit.Manifest

      category(:core, label: "Core", description: "")

      component(JobyKit.CoreComponents, :button, category: :core, summary: "kit button")
      component(JobyKit.NavComponent, :simple_nav, category: :core, summary: "kit nav")
    end

    html = render_component(&PageComponent.page_component/1, manifest: KitOwnedManifest)

    assert html =~ ~s(data-function="button")
    assert html =~ ~s(data-function="simple_nav")
  end

  test "a host component registered as :core does NOT reach the kit surface" do
    # The regression this split exists for. Category is a host-chosen
    # atom, so keying the pages off it let an app label its own component
    # `:core` and have it render on /design as though JobyKit shipped it.
    # Found in the wild: an API gateway had two of its own components
    # sitting on the kit page. Ownership decides the page now.
    defmodule ImposterManifest do
      use JobyKit.Manifest

      alias JobyKit.Test.Components

      category(:core, label: "Core", description: "")

      component(JobyKit.CoreComponents, :button, category: :core, summary: "genuinely kit")
      component(Components, :badge, category: :core, summary: "host component claiming :core")
    end

    kit = render_component(&PageComponent.page_component/1, manifest: ImposterManifest)
    custom = render_component(&PageComponent.custom_page_component/1, manifest: ImposterManifest)

    # Asserted on the module rather than the function name: the kit ships
    # a `badge` of its own, so a name-based check would pass for the
    # wrong reason.
    refute kit =~ "JobyKit.Test.Components",
           "a host module reached the kit surface"

    assert kit =~ "JobyKit.CoreComponents.button"

    # The host's component lands on the custom page instead, with no
    # manifest change required of the host.
    assert custom =~ "JobyKit.Test.Components"
    refute custom =~ ~s(data-module="JobyKit.CoreComponents")
  end

  test "kit_component_modules/0 names what the kit page will show" do
    modules = PageComponent.kit_component_modules()

    assert JobyKit.CoreComponents in modules
    assert JobyKit.NavComponent in modules

    # Every module the shipped install template registers under a JobyKit
    # namespace has to be in this list, or those components silently
    # vanish from /design in every generated app.
    refute JobyKit.Test.Components in modules
  end

  test "custom_page_component renders host entries and a back-link" do
    defmodule MultiCategoryManifest do
      use JobyKit.Manifest

      alias JobyKit.Test.Components

      category(:composite, label: "Composites", description: "")
      category(:domain, label: "Domain", description: "")

      component(Components, :button, category: :composite, summary: "composite entry")
      component(Components, :badge, category: :domain, summary: "domain entry")
    end

    html =
      render_component(&PageComponent.custom_page_component/1,
        manifest: MultiCategoryManifest,
        back_to: "/design"
      )

    assert html =~ ~s(data-jobykit-page="custom")
    assert html =~ ~s(href="/design")
    assert html =~ "design-category-composite"
    assert html =~ "design-category-domain"
    assert html =~ ~s(data-function="button")
    assert html =~ ~s(data-function="badge")
  end
end
