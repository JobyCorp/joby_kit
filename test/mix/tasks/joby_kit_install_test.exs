defmodule Mix.Tasks.JobyKit.InstallTest do
  use ExUnit.Case

  @moduletag :tmp_dir

  test "generates the four expected files using the host's app + web module names",
       %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      Mix.Tasks.JobyKit.Install.run([])

      manifest = File.read!("lib/demo_app_web/design_manifest.ex")
      assert manifest =~ "defmodule DemoAppWeb.DesignManifest do"
      assert manifest =~ "use JobyKit.Manifest"
      assert manifest =~ "alias DemoAppWeb.{CoreComponents, DesignPreviews}"
      assert manifest =~ "component CoreComponents, :button,"
      assert manifest =~ ~s|"#jobykit-component-demo_app_web-corecomponents-button"|

      previews = File.read!("lib/demo_app_web/design_previews.ex")
      assert previews =~ "defmodule DemoAppWeb.DesignPreviews do"
      assert previews =~ "use DemoAppWeb, :html"
      assert previews =~ "def button_preview(assigns)"

      design_live = File.read!("lib/demo_app_web/live/design_system_live.ex")
      assert design_live =~ "defmodule DemoAppWeb.DesignSystemLive do"
      assert design_live =~ "JobyKit.PageComponent.page_component"
      assert design_live =~ "manifest={DemoAppWeb.DesignManifest}"

      custom_live = File.read!("lib/demo_app_web/live/custom_designs_live.ex")
      assert custom_live =~ "defmodule DemoAppWeb.CustomDesignsLive do"
      assert custom_live =~ "JobyKit.PageComponent.custom_page_component"
    end)
  end

  test "respects --web override", %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "underscore_app", fn ->
      Mix.Tasks.JobyKit.Install.run(["--web", "MyCustomWeb"])

      assert File.read!("lib/my_custom_web/design_manifest.ex") =~
               "defmodule MyCustomWeb.DesignManifest do"

      refute File.exists?("lib/underscore_app_web/design_manifest.ex")
    end)
  end

  test "skips existing files without --force", %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      File.mkdir_p!("lib/demo_app_web/live")
      File.write!("lib/demo_app_web/design_manifest.ex", "# pre-existing\n")

      Mix.Tasks.JobyKit.Install.run([])

      # The existing file is preserved.
      assert File.read!("lib/demo_app_web/design_manifest.ex") == "# pre-existing\n"

      # Other files generate normally.
      assert File.exists?("lib/demo_app_web/design_previews.ex")
    end)
  end

  test "overwrites existing files when --force is passed", %{tmp_dir: tmp_dir} do
    in_tmp_project(tmp_dir, "demo_app", fn ->
      File.mkdir_p!("lib/demo_app_web/live")
      File.write!("lib/demo_app_web/design_manifest.ex", "# stale\n")

      Mix.Tasks.JobyKit.Install.run(["--force"])

      assert File.read!("lib/demo_app_web/design_manifest.ex") =~ "use JobyKit.Manifest"
    end)
  end

  defp in_tmp_project(tmp_dir, app_name, fun) do
    project = Path.join(tmp_dir, app_name)
    File.mkdir_p!(project)

    Mix.Project.in_project(String.to_atom(app_name), project, [], fn _ ->
      File.cd!(project, fun)
    end)
  end
end
