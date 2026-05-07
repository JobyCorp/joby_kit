defmodule JobyKit.Test.Components do
  @moduledoc false
  use Phoenix.Component

  attr :rest, :global
  attr :variant, :string, default: "soft", values: ~w(solid soft outline ghost link)
  attr :tone, :string, default: "primary", values: ~w(primary success warning error neutral)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button data-component="JobyKit.Test.Components.button" class={["btn", @variant, @tone]}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :label, :string, required: true
  attr :tone, :string, default: "neutral"

  def badge(assigns) do
    ~H"""
    <span data-component="JobyKit.Test.Components.badge" class={["badge", @tone]}>
      {@label}
    </span>
    """
  end
end

defmodule JobyKit.Test.DesignPreviews do
  @moduledoc false
  use Phoenix.Component

  def button_preview(assigns) do
    ~H"""
    <JobyKit.Test.Components.button>Click me</JobyKit.Test.Components.button>
    """
  end

  def badge_preview(assigns) do
    ~H"""
    <JobyKit.Test.Components.badge label="hello" />
    """
  end
end

defmodule JobyKit.Test.Manifest do
  @moduledoc false
  use JobyKit.Manifest

  alias JobyKit.Test.{Components, DesignPreviews}

  category :core,
    label: "Core wrappers",
    description: "Pure daisy wrappers."

  category :composite,
    label: "Composites",
    description: "Multi-primitive patterns."

  component Components, :button,
    category: :core,
    daisy_basis: "btn",
    summary: "A button.",
    preview: &DesignPreviews.button_preview/1

  component Components, :badge,
    category: :core,
    daisy_basis: "badge",
    summary: "A badge.",
    preview: &DesignPreviews.badge_preview/1

  def daisy_overrides do
    %{
      button: %{wrapper: "<.button>", anchor: "#button"},
      badge: %{wrapper: "<.badge>", anchor: "#badge"}
    }
  end
end
