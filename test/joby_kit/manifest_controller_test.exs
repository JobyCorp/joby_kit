defmodule JobyKit.ManifestControllerTest do
  use ExUnit.Case, async: true

  alias JobyKit.ManifestController

  defp call(action, private) do
    conn =
      Plug.Test.conn(:get, "/design.json")
      |> Plug.Conn.put_private(:phoenix_endpoint, JobyKit.Test.Endpoint)
      |> Map.update!(:private, &Map.merge(&1, private))

    apply(ManifestController, action, [conn, %{}])
  end

  defmodule Endpoint do
    @moduledoc false
    def config(:render_errors), do: [accepts: ~w(json)]
  end

  test "show/2 returns the combined manifest payload" do
    conn = call(:show, %{joby_kit_manifest: JobyKit.Test.Manifest})

    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]

    payload = Jason.decode!(conn.resp_body)

    assert is_binary(payload["generated_at"])

    # Contract sections present.
    assert payload["contract"]["build_order"] |> length() == 5
    assert payload["contract"]["rules"] |> length() == 5
    assert payload["contract"]["taxonomy"] |> length() == 3

    # Categories present in declaration order.
    assert Enum.map(payload["categories"], & &1["id"]) == ["core", "composite"]

    # Components present (both :core in this test manifest).
    # The kit's entries plus this manifest's two. /design.json is the
    # single source of truth for agents, so it spans both surfaces.
    kit_count = length(JobyKit.KitManifest.entries())
    assert length(payload["components"]) == kit_count + 2

    names = Enum.map(payload["components"], & &1["data_component"])
    assert "JobyKit.CoreComponents.button" in names

    # Look up by data_component, not function name: the kit ships a
    # `button` too, so matching on the name alone finds the wrong one.
    host_button =
      Enum.find(
        payload["components"],
        &(&1["data_component"] == "JobyKit.Test.Components.button")
      )

    assert host_button["module"] == "JobyKit.Test.Components"
    assert host_button["category"] == "core"
    assert host_button["daisy_basis"] == "btn"
    assert is_list(host_button["attrs"])

    kit_button =
      Enum.find(payload["components"], &(&1["data_component"] == "JobyKit.CoreComponents.button"))

    assert kit_button["module"] == "JobyKit.CoreComponents"
  end

  test "show/2 returns a 500 JSON when no manifest is configured" do
    conn = call(:show, %{})

    assert conn.status == 500
    payload = Jason.decode!(conn.resp_body)
    assert payload["error"] == "missing manifest"
    assert payload["hint"] =~ "joby_kit_manifest"
  end
end
