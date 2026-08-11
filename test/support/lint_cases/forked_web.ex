defmodule ForkedFixtureWeb do
  @moduledoc false

  def html_helpers do
    quote do
      import JobyKit.CoreComponents, except: [button: 1, table: 1]
      import ForkedFixtureWeb.CoreComponents
    end
  end
end
