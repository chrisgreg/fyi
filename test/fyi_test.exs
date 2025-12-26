defmodule FyiTest do
  use ExUnit.Case
  doctest Fyi

  test "greets the world" do
    assert Fyi.hello() == :world
  end
end
