defmodule JobyKit.NavComponent do
  @moduledoc """
  Small kit-shipped navigation primitives. The `simple_nav/1` function
  component renders a three-link daisyUI navbar suitable for the
  greenfield bootstrap (`mix joby_kit.new`) — Home / Design / Custom
  Designs — with an active-state highlight.

  Hosts can use it anywhere: a layout, a LiveView render, or a function
  component template. Pass `links:` to override the default link list.
  """

  use Phoenix.Component

  @default_links [
    %{key: "home", label: "Home", href: "/"},
    %{key: "design", label: "Design", href: "/design"},
    %{key: "custom-designs", label: "Custom Designs", href: "/custom-designs"}
  ]

  attr :active, :string, default: nil
  attr :brand, :string, default: "JobyKit"
  attr :brand_href, :string, default: "/"
  attr :links, :list, default: @default_links
  attr :class, :any, default: nil

  def simple_nav(assigns) do
    ~H"""
    <nav
      data-component="JobyKit.NavComponent.simple_nav"
      class={[
        "navbar gap-2 border-b border-base-300 bg-base-100 px-4 py-2",
        @class
      ]}
    >
      <div class="flex-1">
        <.link
          navigate={@brand_href}
          class="btn btn-ghost text-lg font-semibold normal-case"
        >
          {@brand}
        </.link>
      </div>
      <ul class="menu menu-horizontal gap-1 px-1">
        <li :for={link <- @links}>
          <.link
            navigate={link.href}
            class={[
              "rounded-lg",
              @active == link.key && "menu-active"
            ]}
          >
            {link.label}
          </.link>
        </li>
      </ul>
    </nav>
    """
  end
end
