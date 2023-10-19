defmodule AssetTracking.Asset do
  @moduledoc """
    Represents an asset
  """

  defstruct ~w(purchases sales)a

  @doc """
    Creates a new asset.
  """
  @spec new() :: %__MODULE__{purchases: %PriorityQueue{}, sales: %PriorityQueue{}}
  def new do
    %__MODULE__{
      purchases: PriorityQueue.new(& &1.settle_date, Date),
      sales: PriorityQueue.new(& &1.sell_date, Date)
    }
  end
end
