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

  The previews call `JobyKit.CoreComponents` directly via the
  `CoreComponents` alias so the rendered HTML matches what the manifest
  declares — no dependency on the host's `<App>Web.CoreComponents`
  resolution.
  """

  use <%= @web_module %>, :html

  alias JobyKit.CoreComponents
  alias <%= @web_module %>.CompositeComponents

  def button_preview(assigns) do
    ~H"""
    <div class="flex flex-col gap-3">
      <div class="flex flex-wrap items-center gap-2">
        <CoreComponents.button>Default</CoreComponents.button>
        <CoreComponents.button variant="primary">Primary</CoreComponents.button>
        <CoreComponents.button variant="neutral">Neutral</CoreComponents.button>
        <CoreComponents.button variant="ghost">Ghost</CoreComponents.button>
        <CoreComponents.button variant="danger">Delete</CoreComponents.button>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <CoreComponents.button size="xs">XS</CoreComponents.button>
        <CoreComponents.button size="sm">Small</CoreComponents.button>
        <CoreComponents.button size="lg">Large</CoreComponents.button>
        <CoreComponents.button shape="circle" variant="ghost" aria-label="Close">
          <CoreComponents.icon name="hero-x-mark" class="size-4" />
        </CoreComponents.button>
      </div>
    </div>
    """
  end

  def card_preview(assigns) do
    ~H"""
    <div class="grid gap-3 sm:grid-cols-2">
      <CoreComponents.card>
        <:eyebrow>Bordered</:eyebrow>
        <:title>Default card</:title>
        Padded content surface backed by daisyUI's <code class="font-mono text-xs">card</code>.
        <:actions><CoreComponents.button>Action</CoreComponents.button></:actions>
      </CoreComponents.card>
      <CoreComponents.card variant="elevated">
        <:eyebrow>Elevated</:eyebrow>
        <:title>Card with shadow</:title>
        Lifts on hover via the wrapper's transition.
      </CoreComponents.card>
    </div>
    """
  end

  def icon_preview(assigns) do
    ~H"""
    <div class="flex items-center gap-3 text-base-content/80">
      <CoreComponents.icon name="hero-sparkles" />
      <CoreComponents.icon name="hero-arrow-right" class="size-5" />
      <CoreComponents.icon name="hero-bolt" class="size-7 text-primary" />
    </div>
    """
  end

  def input_preview(assigns) do
    assigns =
      assigns
      |> Map.put(:form, Phoenix.Component.to_form(%{"email" => ""}, as: :preview))

    ~H"""
    <div class="flex max-w-md flex-col gap-3">
      <CoreComponents.input field={@form[:email]} type="email" label="Email" />
      <CoreComponents.input
        name="bio"
        value=""
        type="textarea"
        label="Bio"
        placeholder="Tell us about yourself"
      />
    </div>
    """
  end

  def flash_preview(assigns) do
    assigns = Map.put(assigns, :preview_flash, %{"info" => "Saved.", "error" => "Try again."})

    ~H"""
    <div class="relative flex flex-col gap-2">
      <CoreComponents.flash kind={:info} flash={@preview_flash} />
      <CoreComponents.flash kind={:error} flash={@preview_flash} title="Heads up" />
    </div>
    """
  end

  def header_preview(assigns) do
    ~H"""
    <CoreComponents.header level="h2">
      Team settings
      <:eyebrow>Workspace</:eyebrow>
      <:subtitle>Manage members and their permissions.</:subtitle>
      <:actions>
        <CoreComponents.button variant="primary">Invite</CoreComponents.button>
      </:actions>
    </CoreComponents.header>
    """
  end

  def list_preview(assigns) do
    ~H"""
    <CoreComponents.list>
      <:item title="Status">Active</:item>
      <:item title="Plan">Team</:item>
      <:item title="Seats">12 of 20 used</:item>
    </CoreComponents.list>
    """
  end

  def table_preview(assigns) do
    assigns =
      Map.put(assigns, :rows, [
        %{id: 1, name: "Ada Lovelace", role: "Owner"},
        %{id: 2, name: "Alan Turing", role: "Member"}
      ])

    ~H"""
    <CoreComponents.table id="preview-table" rows={@rows}>
      <:col :let={row} label="Name">{row.name}</:col>
      <:col :let={row} label="Role">{row.role}</:col>
      <:action :let={row}>
        <CoreComponents.button size="xs">Edit {row.id}</CoreComponents.button>
      </:action>
      <:empty>No members yet.</:empty>
    </CoreComponents.table>
    """
  end

  def empty_state_preview(assigns) do
    ~H"""
    <div class="grid gap-4 sm:grid-cols-2">
      <CompositeComponents.empty_state icon="hero-inbox" title="No messages yet">
        Start a conversation with a teammate to see it here.
        <:action>
          <CoreComponents.button variant="primary">New message</CoreComponents.button>
        </:action>
      </CompositeComponents.empty_state>
      <CompositeComponents.empty_state
        icon="hero-sparkles"
        title="Set up your workspace"
        tone="primary"
      >
        Connect your first integration to populate this dashboard.
      </CompositeComponents.empty_state>
    </div>
    """
  end
end
