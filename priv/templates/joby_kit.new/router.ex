defmodule <%= @web_module %>.Router do
  use <%= @web_module %>, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {<%= @web_module %>.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", <%= @web_module %> do
    pipe_through :browser

    live "/", HomeLive, :index
    live "/design", DesignSystemLive, :index
    live "/custom-designs", CustomDesignsLive, :index
  end

  scope "/" do
    pipe_through :api

    get "/design.json", JobyKit.ManifestController, :show,
      private: %{joby_kit_manifest: <%= @web_module %>.DesignManifest}
  end

  if Application.compile_env(:<%= @app %>, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: <%= @web_module %>.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
