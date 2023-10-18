defmodule AssetTracking.Purchase do
  @moduledoc """
    Represents a purchase of an asset
  """

  defstruct [:settle_date, :quantity, :unit_price, reinserted?: false]
end
