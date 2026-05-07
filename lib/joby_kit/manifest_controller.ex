defmodule JobyKit.ManifestController do
  @moduledoc """
  Serves the host's design manifest as JSON for agent consumption.

  Hosts wire this up by passing their manifest module via route
  `:private`:

      scope "/" do
        pipe_through :authenticated_json
        get "/design.json", JobyKit.ManifestController, :show,
          private: %{joby_kit_manifest: MyAppWeb.DesignManifest}
      end

  The controller does not enforce auth on its own — that's the host's
  pipeline's responsibility. Pair it with a JSON-accepting authenticated
  pipeline (or a public pipeline if the manifest is OK to expose).
  """

  use Phoenix.Controller, formats: [:json]

  alias JobyKit.Contract

  def show(conn, _params) do
    case fetch_manifest(conn) do
      {:ok, manifest} ->
        Phoenix.Controller.json(conn, payload(manifest))

      :error ->
        conn
        |> put_status(:internal_server_error)
        |> Phoenix.Controller.json(%{
          error: "missing manifest",
          hint:
            "Pass the manifest module via route private, e.g. private: %{joby_kit_manifest: MyAppWeb.DesignManifest}"
        })
    end
  end

  defp fetch_manifest(conn) do
    case conn.private[:joby_kit_manifest] do
      module when is_atom(module) and not is_nil(module) -> {:ok, module}
      _ -> :error
    end
  end

  defp payload(manifest) do
    %{
      generated_at: DateTime.utc_now(),
      contract: %{
        build_order: Enum.map(Contract.build_order(), & &1.title),
        rules: Enum.map(Contract.rules(), & &1.title),
        taxonomy:
          Enum.map(Contract.taxonomy(), fn layer ->
            %{layer: layer.layer, title: layer.title, body: layer.body}
          end)
      },
      categories:
        Enum.map(manifest.categories(), fn category ->
          %{
            id: category,
            label: manifest.category_label(category),
            description: manifest.category_description(category)
          }
        end),
      components: Enum.map(manifest.entries(), &serialize_entry/1)
    }
  end

  defp serialize_entry(entry) do
    %{
      module: inspect(entry.module),
      function: entry.function,
      label: entry.label,
      category: entry.category,
      daisy_basis: entry.daisy_basis,
      summary: entry.summary,
      anchor: entry.anchor,
      data_component: entry.data_component,
      source: entry.source,
      line: entry.line,
      attrs: entry.attrs,
      slots: entry.slots
    }
  end
end
