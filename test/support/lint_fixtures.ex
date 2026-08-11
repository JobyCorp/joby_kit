defmodule JobyKit.Test.LintFixtures.GoodComponents do
  @moduledoc false
  use Phoenix.Component

  attr :rest, :global
  attr :variant, :string, values: ~w(primary), default: "primary"
  slot :inner_block, required: true

  def good_button(assigns) do
    ~H"""
    <button data-component="JobyKit.Test.LintFixtures.GoodComponents.good_button" {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end
end

defmodule JobyKit.Test.LintFixtures.BadComponents do
  @moduledoc false
  use Phoenix.Component

  # Violation: no data-component on root, no `attr :rest, :global`.
  attr :variant, :string, values: ~w(primary), default: "primary"
  slot :inner_block, required: true

  def naked_button(assigns) do
    ~H"""
    <button class="btn">{render_slot(@inner_block)}</button>
    """
  end

  # A wrapper that DOES carry data-component but is intentionally not
  # registered in the fixture manifest, to exercise unregistered_wrapper.
  attr :rest, :global
  attr :label, :string, required: true

  def stray_pill(assigns) do
    ~H"""
    <span data-component="JobyKit.Test.LintFixtures.BadComponents.stray_pill" {@rest}>
      {@label}
    </span>
    """
  end
end

defmodule JobyKit.Test.LintFixtures.GoodManifest do
  @moduledoc false
  use JobyKit.Manifest

  alias JobyKit.Test.LintFixtures.GoodComponents

  category(:core, label: "Core", description: "Core wrappers.")

  component(GoodComponents, :good_button,
    category: :core,
    summary: "A clean button."
  )
end

defmodule JobyKit.Test.LintFixtures.BadManifest do
  @moduledoc false
  use JobyKit.Manifest

  alias JobyKit.Test.LintFixtures.BadComponents

  category(:core, label: "Core", description: "Core wrappers.")

  # Registered wrapper without data-component or rest_global —
  # should fire missing_data_component AND missing_rest_global.
  component(BadComponents, :naked_button,
    category: :core,
    summary: "A button missing the contract."
  )

  # Manifest drift — points at a function that doesn't exist on the
  # module. Should fire :manifest_drift.
  component(BadComponents, :ghost_function,
    category: :core,
    summary: "Drift target."
  )
end

defmodule JobyKit.Test.LintFixtures.DynamicComponents do
  @moduledoc false
  use Phoenix.Component

  # Builds the marker rather than hardcoding it. Valid — the attribute is
  # present at runtime — but a literal string search reports it missing.
  attr :rest, :global
  slot :inner_block, required: true

  def dynamic_pill(assigns) do
    assigns = assign(assigns, :dc, "#{inspect(__MODULE__)}.dynamic_pill")

    ~H"""
    <span data-component={@dc} {@rest}>{render_slot(@inner_block)}</span>
    """
  end
end

defmodule JobyKit.Test.LintFixtures.DynamicManifest do
  @moduledoc false
  use JobyKit.Manifest

  alias JobyKit.Test.LintFixtures.DynamicComponents

  category(:core, label: "Core", description: "Core wrappers.")

  component(DynamicComponents, :dynamic_pill,
    category: :core,
    summary: "Builds its own data-component."
  )
end
