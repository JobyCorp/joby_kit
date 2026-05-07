defmodule <%= @web_module %>.DesignManifest do
  @moduledoc """
  This app's component manifest. Backed by `JobyKit.Manifest`.

  Add a `component/3` line for every wrapper, composite, and domain
  component you want to surface on `/design` and `/custom-designs`.
  Categories `:core` shows up on the kit page; `:composite` and
  `:domain` show up on the custom-designs page. The JSON manifest at
  `/design.json` combines all entries.
  """

  use JobyKit.Manifest

  alias <%= @web_module %>.{CoreComponents, DesignPreviews}

  category :core,
    label: "Core wrappers",
    description: "One wrapper per daisyUI primitive. Live in core_components."

  category :composite,
    label: "Generic composites",
    description: "Multi-primitive patterns reused across domains."

  category :domain,
    label: "Domain composites",
    description: "Composites tied to a product area."

  # ---------------------------------------------------------------------- core
  # Example registration — pointing at Phoenix's default <.button> wrapper that
  # ships with `mix phx.new`. Add a `component/3` line for every wrapper your
  # app exposes through CoreComponents.

  component CoreComponents, :button,
    category: :core,
    daisy_basis: "btn",
    summary: "Standard text button.",
    preview: &DesignPreviews.button_preview/1

  # ----------------------------------------------------------------- composite
  # Add generic composites here:
  #
  #   component <%= @web_module %>.UIComponents, :listing_card,
  #     category: :composite,
  #     summary: "Navigable directory entry.",
  #     preview: &DesignPreviews.listing_card_preview/1

  # -------------------------------------------------------------------- domain
  # Add domain composites here:
  #
  #   component <%= @web_module %>.ChatComponents, :composer,
  #     category: :domain,
  #     summary: "Message composer with response-length controls."

  @doc """
  Tells `JobyKit.DaisyCatalogue` which daisyUI primitives this app has wrapped,
  so the catalogue rendering flips them to `:wrapped` and links to the
  signature card on the index. The atoms must match `JobyKit.DaisyCatalogue`
  ids (`:button`, `:badge`, `:card`, `:alert`, `:modal`, …).
  """
  def daisy_overrides do
    %{
      button: %{
        wrapper: "<.button>",
        anchor: "#jobykit-component-<%= @web_module_anchor %>-corecomponents-button"
      }
    }
  end
end
