defmodule <%= @web_module %>.DesignPreviews do
  @moduledoc """
  Per-component preview functions referenced by `<%= @web_module %>.DesignManifest`.

  Each public function takes `assigns` (typically `%{}`) and returns a
  small HEEx rendering the component with sensible defaults. The
  manifest registers these via `preview: &<%= @web_module %>.DesignPreviews.X_preview/1`,
  and `JobyKit.SignatureComponent` invokes them inside the per-component
  card's collapsible Preview section.

  Naming convention: every preview function ends in `_preview` so they
  don't collide with the imported component functions of the same name
  (e.g. `button` vs `button_preview`).
  """

  use <%= @web_module %>, :html

  def button_preview(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-2">
      <.button>Default</.button>
      <.button class="btn-primary">Primary</.button>
      <.button class="btn-soft btn-warning">Soft warning</.button>
    </div>
    """
  end
end
