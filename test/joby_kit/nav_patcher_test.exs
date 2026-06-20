defmodule JobyKit.NavPatcherTest do
  use ExUnit.Case, async: true

  alias JobyKit.NavPatcher

  @moduletag :tmp_dir

  describe "patch/2 — Phoenix-default layout" do
    test "inserts kit links before the first </ul> inside a <header>",
         %{tmp_dir: dir} do
      path = Path.join(dir, "app.html.heex")

      File.write!(path, """
      <header class="navbar">
        <div class="flex-1"><a href="/">Logo</a></div>
        <div class="flex-none">
          <ul class="flex gap-4">
            <li><a href="/about">About</a></li>
          </ul>
        </div>
      </header>

      <main>
        {@inner_content}
      </main>
      """)

      assert NavPatcher.patch(path) == :patched

      contents = File.read!(path)
      assert contents =~ "<%!-- jobykit:nav-start --%>"
      assert contents =~ "<%!-- jobykit:nav-end --%>"
      assert contents =~ ~s|<.link navigate={~p"/design"}>Design</.link>|
      assert contents =~ ~s|<.link navigate={~p"/custom-designs"}>Custom Designs</.link>|

      # The existing <li> is preserved.
      assert contents =~ ~s|<li><a href="/about">About</a></li>|

      # Inserted before </ul>.
      [head, _tail] = String.split(contents, "</ul>", parts: 2)
      assert head =~ "<%!-- jobykit:nav-start --%>"
      assert head =~ "<%!-- jobykit:nav-end --%>"
    end

    test "matches a <nav> wrapper too", %{tmp_dir: dir} do
      path = Path.join(dir, "app.html.heex")

      File.write!(path, """
      <nav>
        <ul>
          <li><a href="/">Home</a></li>
        </ul>
      </nav>
      """)

      assert NavPatcher.patch(path) == :patched
      assert File.read!(path) =~ "<%!-- jobykit:nav-start --%>"
    end
  end

  describe "patch/2 — idempotency" do
    test "second run is a no-op (returns :unchanged, content unchanged)",
         %{tmp_dir: dir} do
      path = Path.join(dir, "app.html.heex")

      File.write!(path, """
      <nav>
        <ul>
          <li>One</li>
        </ul>
      </nav>
      """)

      assert NavPatcher.patch(path) == :patched
      first = File.read!(path)

      assert NavPatcher.patch(path) == :unchanged
      assert File.read!(path) == first
    end
  end

  describe "patch/2 — no insertable element" do
    test "returns :no_nav_found when there's no <nav> or <header>",
         %{tmp_dir: dir} do
      path = Path.join(dir, "app.html.heex")

      File.write!(path, """
      <main>
        {@inner_content}
      </main>
      """)

      assert NavPatcher.patch(path) == :no_nav_found
      # Original content unchanged.
      assert File.read!(path) =~ "{@inner_content}"
    end

    test "returns :no_nav_found when <nav> exists but has no <ul>",
         %{tmp_dir: dir} do
      path = Path.join(dir, "app.html.heex")

      File.write!(path, """
      <nav>
        <a href="/">Home</a>
      </nav>
      """)

      assert NavPatcher.patch(path) == :no_nav_found
    end
  end

  describe "patch/2 — missing file" do
    test "returns :missing when the path doesn't exist", %{tmp_dir: dir} do
      assert NavPatcher.patch(Path.join(dir, "nope.heex")) == :missing
    end
  end

  describe "patch/2 — custom links" do
    test "honors a custom :links option", %{tmp_dir: dir} do
      path = Path.join(dir, "app.html.heex")

      File.write!(path, """
      <nav>
        <ul></ul>
      </nav>
      """)

      assert NavPatcher.patch(path, links: [{"Foo", "/foo"}, {"Bar", "/bar"}]) == :patched

      contents = File.read!(path)
      assert contents =~ ~s|<.link navigate={~p"/foo"}>Foo</.link>|
      assert contents =~ ~s|<.link navigate={~p"/bar"}>Bar</.link>|
      refute contents =~ ~s|<.link navigate={~p"/design"}>|
    end
  end

  describe "patch/2 — preserves indentation" do
    test "inserts the block at the same indent as the existing </ul>",
         %{tmp_dir: dir} do
      path = Path.join(dir, "app.html.heex")

      File.write!(path, """
      <header>
        <div>
          <ul>
            <li>One</li>
          </ul>
        </div>
      </header>
      """)

      assert NavPatcher.patch(path) == :patched
      contents = File.read!(path)

      # The </ul> line is at 4-space indent; markers should match.
      assert contents =~ "    <%!-- jobykit:nav-start --%>"
      assert contents =~ "    <%!-- jobykit:nav-end --%>"
    end
  end
end
