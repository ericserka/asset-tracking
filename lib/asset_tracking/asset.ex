defmodule AssetTracking.Asset do
  @moduledoc """
    Represents an asset
  """
  alias AssetTracking.Purchase
  alias AssetTracking.Sale

  defstruct ~w(purchases sales)a

  @doc """
    Creates a new asset.
  """
  @spec new() :: %__MODULE__{purchases: Prioqueue.t(), sales: Prioqueue.t()}
  def new do
    %__MODULE__{
      purchases: Prioqueue.empty(cmp_fun: &purchases_cmp_fun/2),
      sales: Prioqueue.empty(cmp_fun: &sales_cmp_fun/2)
    }
  end

  @spec purchases_cmp_fun(%Purchase{}, %Purchase{}) :: :lt | :eq | :gt
  defp purchases_cmp_fun(a, b),
    do: if(b.reinserted?, do: :gt, else: Date.compare(a.settle_date, b.settle_date))

  @spec sales_cmp_fun(%Sale{}, %Sale{}) :: :lt | :eq | :gt
  defp sales_cmp_fun(a, b), do: Date.compare(a.sell_date, b.sell_date)
end
