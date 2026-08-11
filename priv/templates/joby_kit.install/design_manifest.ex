defmodule <%= @web_module %>.DesignManifest do
  @moduledoc """
  This app's component manifest. Backed by `JobyKit.Manifest`.

  The default registrations point at `JobyKit.CoreComponents` — the kit
  ships the standard scaffolding (`button`, `card`, `icon`, `input`,
  `flash`, `header`, `list`, `table`) so every JobyKit-installed app
  gets contract-clean wrappers for free.

  Add a `component/3` line for every additional wrapper, composite, and
  domain component you want to surface on `/design` and
  `/custom-designs`. The JSON manifest at `/design.json` combines all
  entries.
  """

  use JobyKit.Manifest

  alias JobyKit.CoreComponents
  alias JobyKit.NavComponent
  alias <%= @web_module %>.CompositeComponents
  alias <%= @web_module %>.DesignPreviews

  category :core,
    label: "Core wrappers",
    description: "One wrapper per daisyUI primitive. Ship by JobyKit."

  category :composite,
    label: "Generic composites",
    description: "Multi-primitive patterns reused across domains."

  category :domain,
    label: "Domain composites",
    description: "Composites tied to a product area."

  # ---------------------------------------------------------------------- core
  # The kit-shipped scaffolding. Each component carries the wrapper
  # contract (data-component, attr :rest, :global, attrs with values:
  # enums) and is lint-clean by construction.

  component CoreComponents, :button,
    category: :core,
    daisy_basis: "btn",
    summary: "Standard text button, with link auto-detection via :rest.",
    preview: &DesignPreviews.button_preview/1

  component CoreComponents, :badge,
    category: :core,
    daisy_basis: "badge",
    summary: "Status chip with a semantic tone (neutral/ok/warn/danger/info).",
    preview: &DesignPreviews.badge_preview/1

  component CoreComponents, :card,
    category: :core,
    daisy_basis: "card",
    summary: "Padded content surface with eyebrow, title, and actions slots.",
    preview: &DesignPreviews.card_preview/1

  component CoreComponents, :icon,
    category: :core,
    daisy_basis: "hero-*",
    summary: "Heroicon span. Pass `name=\"hero-x-mark\"` and an optional `class`.",
    preview: &DesignPreviews.icon_preview/1

  component CoreComponents, :input,
    category: :core,
    daisy_basis: "input / select / textarea / checkbox",
    summary: "Form input with label and error rendering. Supports all standard input types.",
    preview: &DesignPreviews.input_preview/1

  component CoreComponents, :eyebrow,
    category: :core,
    summary: "Small uppercase label. Used by card and header for their :eyebrow slots.",
    preview: &DesignPreviews.eyebrow_preview/1

  component CoreComponents, :flash,
    category: :core,
    daisy_basis: "alert",
    summary: "Toast-style flash notice. Use inside `flash_group/1` from your root layout.",
    preview: &DesignPreviews.flash_preview/1

  # `flash_group` is the page's single `toast` container — it's
  # `position: fixed`, so an inline preview would float over the design
  # page instead of sitting in its card. Registered without one so it's
  # still discoverable (attrs, source, data-component) on /design and in
  # /design.json.
  component CoreComponents, :flash_group,
    category: :core,
    daisy_basis: "toast",
    summary: "The root-layout flash container. Stacks every notice in one fixed toast."

  component CoreComponents, :header,
    category: :core,
    summary: "Page or section header with subtitle and actions slots.",
    preview: &DesignPreviews.header_preview/1

  component CoreComponents, :list,
    category: :core,
    daisy_basis: "list",
    summary: "Title/value pairs rendered as a daisyUI list.",
    preview: &DesignPreviews.list_preview/1

  component CoreComponents, :modal,
    category: :core,
    daisy_basis: "modal",
    summary: "Server-driven dialog. One on_cancel covers button, backdrop, and Escape.",
    preview: &DesignPreviews.modal_preview/1

  component CoreComponents, :table,
    category: :core,
    daisy_basis: "table",
    summary: "Column-slot table. Accepts a plain list or a LiveView stream.",
    preview: &DesignPreviews.table_preview/1

  component CoreComponents, :theme_toggle,
    category: :core,
    daisy_basis: "theme-controller",
    summary: "Segmented system / light / dark control. Pairs with the root-layout theme script.",
    preview: &DesignPreviews.theme_toggle_preview/1

  component NavComponent, :simple_nav,
    category: :core,
    daisy_basis: "navbar",
    summary: "App navbar with active state and an :actions slot. Draws no surface of its own.",
    preview: &DesignPreviews.simple_nav_preview/1

  # ----------------------------------------------------------------- composite
  # `empty_state` is the worked example — a real composite that bundles
  # `<.icon>` + a heading + an optional action slot. Use it as the
  # template for your own composites: copy the attr / slot / data-component
  # shape, register the new entry here, and add a preview in
  # `design_previews.ex`. Generic composites belong in
  # `<%= @web_module %>.CompositeComponents`; domain-specific ones in
  # their own module (e.g. `<%= @web_module %>.ChatComponents`).

  component CompositeComponents, :empty_state,
    category: :composite,
    summary: "Centered icon + title + optional action; fills empty containers.",
    preview: &DesignPreviews.empty_state_preview/1

  # -------------------------------------------------------------------- domain
  # Add domain composites here:
  #
  #   component <%= @web_module %>.ChatComponents, :composer,
  #     category: :domain,
  #     summary: "Message composer with response-length controls."

  @doc """
  Tells `JobyKit.DaisyCatalogue` which daisyUI primitives this app has
  wrapped, so the catalogue rendering flips them to `:wrapped` and links
  to the signature card on the index. The atoms must match
  `JobyKit.DaisyCatalogue` ids (`:button`, `:badge`, `:card`, …).
  """
  def daisy_overrides do
    %{
      button: %{
        wrapper: "<.button>",
        anchor: "#jobykit-component-jobykit-corecomponents-button"
      },
      card: %{
        wrapper: "<.card>",
        anchor: "#jobykit-component-jobykit-corecomponents-card"
      },
      alert: %{
        wrapper: "<.flash>",
        anchor: "#jobykit-component-jobykit-corecomponents-flash"
      },
      toast: %{
        wrapper: "<.flash_group>",
        anchor: "#jobykit-component-jobykit-corecomponents-flash_group"
      },
      list: %{
        wrapper: "<.list>",
        anchor: "#jobykit-component-jobykit-corecomponents-list"
      },
      table: %{
        wrapper: "<.table>",
        anchor: "#jobykit-component-jobykit-corecomponents-table"
      },
      text_input: %{
        wrapper: "<.input>",
        anchor: "#jobykit-component-jobykit-corecomponents-input"
      },
      select: %{
        wrapper: "<.input type=\"select\">",
        anchor: "#jobykit-component-jobykit-corecomponents-input"
      },
      textarea: %{
        wrapper: "<.input type=\"textarea\">",
        anchor: "#jobykit-component-jobykit-corecomponents-input"
      },
      checkbox: %{
        wrapper: "<.input type=\"checkbox\">",
        anchor: "#jobykit-component-jobykit-corecomponents-input"
      },
      badge: %{
        wrapper: "<.badge>",
        anchor: "#jobykit-component-jobykit-corecomponents-badge"
      },
      modal: %{
        wrapper: "<.modal>",
        anchor: "#jobykit-component-jobykit-corecomponents-modal"
      },
      theme_controller: %{
        wrapper: "<.theme_toggle>",
        anchor: "#jobykit-component-jobykit-corecomponents-theme_toggle"
      },
      navbar: %{
        wrapper: "<.simple_nav>",
        anchor: "#jobykit-component-jobykit-navcomponent-simple_nav"
      }
    }
  end
end
