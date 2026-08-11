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

    test "type passes through so form buttons can opt out of submitting" do
      assigns = %{}

      html =
        rendered_to_string(~H|<CoreComponents.button type="button">Cancel</CoreComponents.button>|)

      assert html =~ ~s|type="button"|
    end

    test "omitting type leaves the attribute off (browser default applies)" do
      assigns = %{}
      html = rendered_to_string(~H|<CoreComponents.button>Save</CoreComponents.button>|)

      refute html =~ ~s|type=|
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

    test "tolerates opts that don't implement String.Chars" do
      # Ecto attaches these to every cast error on an array field. Stringifying
      # opts eagerly (rather than inside the String.replace/4 function form)
      # raises Protocol.UndefinedError on the tuple and 500s the whole form.
      assert CoreComponents.translate_error(
               {"is invalid", [type: {:array, :string}, validation: :cast]}
             ) == "is invalid"
    end

    test "interpolates stringable opts alongside non-stringable ones" do
      assert CoreComponents.translate_error(
               {"expected %{count}", [count: 3, type: {:array, :id}, validation: :cast]}
             ) == "expected 3"
    end

    test "tolerates non-stringable values in a matched placeholder's siblings" do
      # A subset/inclusion error carries a list of atoms plus a real placeholder.
      assert CoreComponents.translate_error(
               {"must be one of %{count}", [count: 2, enum: [:a, :b], validation: :subset]}
             ) == "must be one of 2"
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

  describe "flash positioning" do
    test "a flash is an alert, not its own fixed toast container" do
      # Each flash owning a `toast` container meant simultaneous notices
      # stacked at the same fixed position and occluded each other.
      assigns = %{flash: %{"info" => "Saved."}}

      html = rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} />|)

      assert html =~ "alert"
      refute html =~ "toast"
    end

    test "flash_group supplies exactly one toast container for every notice" do
      assigns = %{flash: %{"info" => "Saved.", "error" => "Nope."}}

      html = rendered_to_string(~H|<CoreComponents.flash_group flash={@flash} />|)

      assert count(html, "toast toast-top toast-end") == 1
      # Both notices still render, now stacked inside that one container.
      assert html =~ "Saved."
      assert html =~ "Nope."
    end

    test "the toast container is click-through; notices are not" do
      assigns = %{flash: %{"info" => "Saved."}}

      html = rendered_to_string(~H|<CoreComponents.flash_group flash={@flash} />|)

      assert html =~ "pointer-events-none"
      assert html =~ "pointer-events-auto"
    end

    test "info is a polite status; error stays assertive" do
      assigns = %{flash: %{"info" => "Saved.", "error" => "Nope."}}

      info = rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} />|)
      error = rendered_to_string(~H|<CoreComponents.flash kind={:error} flash={@flash} />|)

      assert info =~ ~s|role="status"|
      assert error =~ ~s|role="alert"|
    end

    test "class is declared, so it merges into the root instead of colliding" do
      # Previously `class` arrived via :rest and landed as a second class
      # attribute alongside the hardcoded identity classes.
      assigns = %{flash: %{"info" => "Saved."}}

      flash =
        rendered_to_string(~H|<CoreComponents.flash kind={:info} flash={@flash} class="mt-4" />|)

      group = rendered_to_string(~H|<CoreComponents.flash_group flash={@flash} class="z-10" />|)

      assert root_class(flash) =~ "alert"
      assert root_class(flash) =~ "mt-4"
      assert root_class(group) =~ "toast"
      assert root_class(group) =~ "z-10"
    end
  end

  # Every host form goes through the FormField clause; the raw name/value
  # mode above is the exception, not the rule.
  describe "input with a Phoenix.HTML.FormField" do
    test "derives id, name, and value from the field" do
      assigns = %{field: to_form(%{"email" => "ada@example.com"}, as: :user)[:email]}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input field={@field} type="email" label="Email" />|
        )

      assert html =~ ~s|id="user_email"|
      assert html =~ ~s|name="user[email]"|
      assert html =~ ~s|value="ada@example.com"|
      assert html =~ "Email"
    end

    test "an explicit id wins over the field's" do
      assigns = %{field: to_form(%{"email" => ""}, as: :user)[:email]}

      html = rendered_to_string(~H|<CoreComponents.input field={@field} id="custom" />|)

      assert html =~ ~s|id="custom"|
      # the name still comes from the field
      assert html =~ ~s|name="user[email]"|
    end

    test "renders translated errors once the field has been used" do
      form = to_form(%{"email" => "nope"}, as: :user, errors: [email: {"is invalid", []}])
      assigns = %{field: form[:email]}

      html = rendered_to_string(~H|<CoreComponents.input field={@field} label="Email" />|)

      assert html =~ "is invalid"
      assert html =~ "input-error"
    end

    test "suppresses errors on a field the user has not touched" do
      # used_input?/1 gates this: params carry no "email" key, so the error
      # exists on the changeset but must not render yet.
      form = to_form(%{}, as: :user, errors: [email: {"is invalid", []}])
      assigns = %{field: form[:email]}

      html = rendered_to_string(~H|<CoreComponents.input field={@field} label="Email" />|)

      refute html =~ "is invalid"
      refute html =~ "input-error"
    end

    test "an array-field cast error renders instead of crashing the form" do
      # The P0 fixed in 0.2.3, exercised through the path a host actually
      # takes: Ecto attaches non-String.Chars opts to array-field cast
      # errors, and translate_error/1 used to raise on them mid-render.
      form =
        to_form(%{"tags" => "x"},
          as: :post,
          errors: [tags: {"is invalid", [type: {:array, :string}, validation: :cast]}]
        )

      assigns = %{field: form[:tags]}

      html = rendered_to_string(~H|<CoreComponents.input field={@field} label="Tags" />|)

      assert html =~ "is invalid"
    end

    test "multiple appends [] to the derived name" do
      assigns = %{field: to_form(%{"tags" => ["a"]}, as: :post)[:tags]}

      html =
        rendered_to_string(
          ~H|<CoreComponents.input field={@field} type="select" multiple options={[a: "a"]} />|
        )

      assert html =~ ~s|name="post[tags][]"|
    end
  end

  describe "table with a LiveView stream" do
    setup do
      # stream/4 attaches an after-render hook, so the socket needs a real
      # lifecycle in :private — a bare %Socket{} has only :live_temp.
      socket = %Phoenix.LiveView.Socket{
        private: %{live_temp: %{}, lifecycle: %Phoenix.LiveView.Lifecycle{}}
      }

      socket =
        Phoenix.LiveView.stream(socket, :users, [
          %{id: 1, name: "Ada"},
          %{id: 2, name: "Alan"}
        ])

      %{stream: socket.assigns.streams.users}
    end

    test "marks the tbody for stream updates and derives row dom ids", %{stream: stream} do
      assigns = %{stream: stream}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@stream}>
          <:col :let={{_id, user}} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ ~s|phx-update="stream"|
      assert html =~ ~s|id="users"|
      assert html =~ ~s|id="users-1"|
      assert html =~ ~s|id="users-2"|
      assert html =~ "Ada"
      assert html =~ "Alan"
    end

    test "the col slot receives {dom_id, item} tuples, not bare items", %{stream: stream} do
      # Worth pinning: the doc example's `:let={user}` + `user.name` raises
      # under a stream. Callers must destructure or pass row_item.
      assigns = %{stream: stream}

      assert_raise BadMapError, fn ->
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@stream}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)
      end
    end

    test "row_item can unwrap the tuple for callers who prefer bare items", %{stream: stream} do
      assigns = %{stream: stream}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@stream} row_item={fn {_id, user} -> user end}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ "Ada"
      assert html =~ ~s|id="users-1"|
    end
  end

  describe "table with a plain list" do
    test "omits the stream attribute entirely" do
      assigns = %{rows: [%{id: 1, name: "Ada"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@rows}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      refute html =~ "phx-update"
      assert html =~ "Ada"
    end

    test "row_click makes the data cells clickable but not the action cell" do
      assigns = %{rows: [%{id: 1, name: "Ada"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@rows} row_click={fn row -> "pick-#{row.id}" end}>
          <:col :let={user} label="Name">{user.name}</:col>
          <:action :let={user}>edit-{user.id}</:action>
        </CoreComponents.table>
        """)

      assert html =~ "hover:cursor-pointer"
      assert html =~ "pick-1"
      assert html =~ "edit-1"
      # The action column header is screen-reader only.
      assert html =~ "sr-only"
    end

    test "row_id overrides the generated row identifier" do
      assigns = %{rows: [%{id: 7, name: "Ada"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@rows} row_id={fn row -> "u-#{row.id}" end}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ ~s|id="u-7"|
    end
  end

  defp count(haystack, needle), do: length(String.split(haystack, needle)) - 1

  # The class attribute of the first (root) element in the rendered markup.
  defp root_class(html) do
    [_, class] = Regex.run(~r/class="([^"]*)"/, html)
    class
  end
end
