defmodule ExamplePhoenix.StoreFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ExamplePhoenix.Store` context.
  """

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    {:ok, product} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        price: "120.5"
      })
      |> ExamplePhoenix.Store.create_product()

    product
  end
end
