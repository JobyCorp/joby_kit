defmodule JobyKit.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias JobyKit.CoreComponents

  describe "wrapper contract" do
    test "every shipped component carries data-component on its root" do
      assigns = %{rows: [%{name: "Mira"}], flash: %{"info" => "hi"}, empty_flash: %{}}

      icon = rendered_to_string(~H|<CoreComponents.icon name="hero-x-mark" />|)
      button = rendered_to_string(~H|<CoreComponents.button>Click</CoreComponents.button>|)
      card = rendered_to_string(~H|<CoreComponents.card>body</CoreComponents.card>|)
      header = rendered_to_string(~H|<CoreComponents.header>Title</CoreComponents.header>|)

      list =
        rendered_to_string(
          ~H|<CoreComponents.list><:item title="Foo">Bar</:item></CoreComponents.list>|
        )

      table =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@rows}>
          <:col :let={row} label="Name">{row.name}</:col>
        </CoreComponents.table>
        """)

      flash = rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} />|)
      flash_group = rendered_to_string(~H|<CoreComponents.flash_group flash={@empty_flash} />|)
      input = rendered_to_string(~H|<CoreComponents.input name="q" value="" type="text" />|)

      assert icon =~ ~s|data-component="JobyKit.CoreComponents.icon"|
      assert button =~ ~s|data-component="JobyKit.CoreComponents.button"|
      assert card =~ ~s|data-component="JobyKit.CoreComponents.card"|
      assert header =~ ~s|data-component="JobyKit.CoreComponents.header"|
      assert list =~ ~s|data-component="JobyKit.CoreComponents.list"|
      assert table =~ ~s|data-component="JobyKit.CoreComponents.table"|
      assert flash =~ ~s|data-component="JobyKit.CoreComponents.flash"|
      assert flash_group =~ ~s|data-component="JobyKit.CoreComponents.flash_group"|
      assert input =~ ~s|data-component="JobyKit.CoreComponents.input"|
    end
  end

  describe "button" do
    test "renders as <button> by default" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.button>Send</CoreComponents.button>|)

      assert html =~ "<button"
      assert html =~ "btn"
      assert html =~ "Send"
    end

    test "renders as <a> link when navigate is passed" do
      assigns = %{}

      html =
        rendered_to_string(~H|<CoreComponents.button navigate="/">Home</CoreComponents.button>|)

      assert html =~ "<a"
      assert html =~ ~s|href="/"|
    end

    test "size attr appends btn-sm/btn-lg; md is implicit" do
      assigns = %{}

      sm = rendered_to_string(~H|<CoreComponents.button size="sm">x</CoreComponents.button>|)
      lg = rendered_to_string(~H|<CoreComponents.button size="lg">x</CoreComponents.button>|)
      md = rendered_to_string(~H|<CoreComponents.button size="md">x</CoreComponents.button>|)

      assert sm =~ "btn-sm"
      assert lg =~ "btn-lg"
      refute md =~ "btn-sm"
      refute md =~ "btn-lg"
    end

    test "class is additive — variant default still applies" do
      assigns = %{}

      html =
        rendered_to_string(~H|<CoreComponents.button class="ml-2">x</CoreComponents.button>|)

      assert html =~ "btn-primary"
      assert html =~ "ml-2"
    end
  end

  describe "card" do
    test "renders eyebrow, title, actions slots when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.card>
          <:eyebrow>/design</:eyebrow>
          <:title>Kit</:title>
          body
          <:actions>Open</:actions>
        </CoreComponents.card>
        """)

      assert html =~ "/design"
      assert html =~ "Kit"
      assert html =~ "Open"
      assert html =~ "body"
    end

    test "variant=elevated applies the elevated class set" do
      assigns = %{}

      html =
        rendered_to_string(~H|<CoreComponents.card variant="elevated">body</CoreComponents.card>|)

      assert html =~ "shadow-sm"
    end
  end

  describe "input" do
    test "renders text input with label" do
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input name="user[email]" value="" type="text" label="Email" />|
        )

      assert html =~ ~s|name="user[email]"|
      assert html =~ "Email"
      assert html =~ "input"
    end

    test "renders error messages and adds error class when errors present" do
      errors = ["is invalid"]
      assigns = %{errors: errors}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input name="user[email]" value="bad" type="text" errors={@errors} />
        """)

      assert html =~ "is invalid"
      assert html =~ "input-error"
    end

    test "select renders option markup" do
      options = [{"Admin", "admin"}, {"User", "user"}]
      assigns = %{options: options}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          name="user[role]"
          value=""
          type="select"
          options={@options}
          prompt="Pick one"
        />
        """)

      assert html =~ "<select"
      assert html =~ "Pick one"
      assert html =~ "Admin"
    end

    test "textarea renders normalized value" do
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input name="post[body]" value="hello" type="textarea" />|
        )

      assert html =~ "<textarea"
      assert html =~ "hello"
    end

    test "checkbox renders hidden + visible inputs" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input name="user[agreed]" value={true} type="checkbox" label="Agreed" />
        """)

      assert html =~ ~s|type="checkbox"|
      assert html =~ ~s|type="hidden"|
      assert html =~ "Agreed"
    end

    test "class is additive for text inputs" do
      assigns = %{}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input name="q" value="" type="text" class="max-w-md" />|
        )

      assert html =~ "max-w-md"
      assert html =~ ~r/class="[^"]*\binput\b/
    end
  end

  describe "translate_error/1" do
    test "interpolates %{key} placeholders" do
      assert CoreComponents.translate_error({"must be at most %{count} chars", count: 10}) ==
               "must be at most 10 chars"
    end

    test "returns plain strings unchanged" do
      assert CoreComponents.translate_error("oh no") == "oh no"
    end

    test "leaves unmatched placeholders alone" do
      assert CoreComponents.translate_error({"value %{x} extra", count: 10}) ==
               "value %{x} extra"
    end
  end

  describe "show/2 and hide/2" do
    test "return Phoenix.LiveView.JS commands" do
      assert %Phoenix.LiveView.JS{} = CoreComponents.show("#foo")
      assert %Phoenix.LiveView.JS{} = CoreComponents.hide("#foo")
    end
  end

  describe "flash id" do
    test "defaults to flash-<kind> when the caller omits id" do
      # `attr :id` puts :id in assigns as nil, so this can't be assign_new/3:
      # the key is always present. Getting it wrong renders the toast with no
      # id and a `hide(to: "#")` dismiss handler, which throws in the browser.
      assigns = %{flash: %{"info" => "Saved."}}

      html = rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} />|)

      assert html =~ ~s|id="flash-info"|
      assert html =~ ~s|#flash-info|
      refute html =~ ~s|&quot;to&quot;:&quot;#&quot;|
    end

    test "an explicit id still wins" do
      assigns = %{flash: %{"error" => "Nope."}}

      html =
        rendered_to_string(
          ~H|<CoreComponents.flash id="custom-toast" kind={:error} flash={@flash} />|
        )

      assert html =~ ~s|id="custom-toast"|
      assert html =~ ~s|#custom-toast|
    end

    test "every toast flash_group renders carries a usable selector" do
      assigns = %{flash: %{"info" => "Saved.", "error" => "Nope."}}

      html = rendered_to_string(~H|<CoreComponents.flash_group flash={@flash} />|)

      refute html =~ ~s|&quot;to&quot;:&quot;#&quot;|
    end
  end
end
