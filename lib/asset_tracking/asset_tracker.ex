defmodule AssetTracking.AssetTracker do
  @moduledoc """
    This module aims to implement the following functionality:
    1. Update the inventory after asset purchases with a settle date and quantity.
    2. Update the inventory after asset asset sales with a sell date and quantity.
    3. Update the asset inventory using a FIFO procedure based on the dates.
    4. Calculate the capital gains or losses for each sale.

    Example usage

    ```
      iex> alias AssetTracking.AssetTracker
      AssetTracking.AssetTracker
      iex> asset_tracker = AssetTracker.new()
      %AssetTracking.AssetTracker{inventory: %{}}
      iex> asset_tracker = AssetTracker.add_purchase(asset_tracker, "APPL", ~D[2023-10-19], Decimal.new(5), Decimal.new(200))
      %AssetTracking.AssetTracker{
        inventory: %{
          "APPL" => %AssetTracking.Asset{
            purchases: %PriorityQueue{
              mapper: #Function<1.122398763/1 in AssetTracking.Asset.new/0>,
              sorter: Date,
              queue: [
                %AssetTracking.Purchase{
                  settle_date: ~D[2023-10-19],
                  quantity: Decimal.new("5"),
                  unit_price: Decimal.new("200")
                }
              ]
            },
            sales: %PriorityQueue{
              mapper: #Function<2.122398763/1 in AssetTracking.Asset.new/0>,
              sorter: Date,
              queue: []
            }
          }
        }
      }
      iex> asset_tracker = AssetTracker.add_purchase(asset_tracker, "APPL", ~D[2023-10-18], Decimal.new(3), Decimal.new(100))
      %AssetTracking.AssetTracker{
        inventory: %{
          "APPL" => %AssetTracking.Asset{
            purchases: %PriorityQueue{
              mapper: #Function<1.122398763/1 in AssetTracking.Asset.new/0>,
              sorter: Date,
              queue: [
                %AssetTracking.Purchase{
                  settle_date: ~D[2023-10-18],
                  quantity: Decimal.new("3"),
                  unit_price: Decimal.new("100")
                },
                %AssetTracking.Purchase{
                  settle_date: ~D[2023-10-19],
                  quantity: Decimal.new("5"),
                  unit_price: Decimal.new("200")
                }
              ]
            },
            sales: %PriorityQueue{
              mapper: #Function<2.122398763/1 in AssetTracking.Asset.new/0>,
              sorter: Date,
              queue: []
            }
          }
        }
      }
      iex> {asset_tracker, realized_gain_or_loss} = AssetTracker.add_sale(asset_tracker, "APPL", ~D[2023-10-20], Decimal.new(1), Decimal.new(10))
      {%AssetTracking.AssetTracker{
        inventory: %{
          "APPL" => %AssetTracking.Asset{
            purchases: %PriorityQueue{
              mapper: #Function<1.122398763/1 in AssetTracking.Asset.new/0>,
              sorter: Date,
              queue: [
                %AssetTracking.Purchase{
                  settle_date: ~D[2023-10-18],
                  quantity: Decimal.new("2.0"),
                  unit_price: Decimal.new("100")
                },
                %AssetTracking.Purchase{
                  settle_date: ~D[2023-10-19],
                  quantity: Decimal.new("5"),
                  unit_price: Decimal.new("200")
                }
              ]
            },
            sales: %PriorityQueue{
              mapper: #Function<2.122398763/1 in AssetTracking.Asset.new/0>,
              sorter: Date,
              queue: [
                %AssetTracking.Sale{
                  sell_date: ~D[2023-10-20],
                  quantity: Decimal.new("1"),
                  unit_price: Decimal.new("10")
                }
              ]
            }
          }
        }
      }, Decimal.new("-90.0")}
      iex> AssetTracker.unrealized_gain_or_loss(asset_tracker, "APPL", Decimal.new(50))
      Decimal.new("-850.0")
    ```
  """

  defstruct inventory: %{}

  alias AssetTracking.Pipelines.AssetTracker.AddPurchase, as: AddPurchasePipeline
  alias AssetTracking.Pipelines.AssetTracker.AddSale, as: AddSalePipeline

  alias AssetTracking.Pipelines.AssetTracker.CalculateUnrealizedGainOrLoss,
    as: CalculateUnrealizedGainOrLossPipeline

  @doc """
    Create a new asset tracker.
  """
  @spec new() :: %__MODULE__{inventory: map()}
  def new, do: %__MODULE__{}

  @doc """
    Add a new purchase to the asset tracker.
  """
  @spec add_purchase(
          %__MODULE__{inventory: map()},
          String.t(),
          %Date{},
          %Decimal{},
          %Decimal{}
        ) :: %__MODULE__{inventory: map()} | {:error, map()}
  def add_purchase(%__MODULE__{} = asset_tracker, asset_symbol, settle_date, quantity, unit_price) do
    AddPurchasePipeline.call(%{
      asset_tracker: asset_tracker,
      asset_symbol: asset_symbol,
      settle_date: settle_date,
      quantity: quantity,
      unit_price: unit_price
    })
  end

  @doc """
    Records the symbol sale in the system
  """
  @spec add_sale(
          %__MODULE__{inventory: map()},
          String.t(),
          %Date{},
          %Decimal{},
          %Decimal{}
        ) :: %__MODULE__{inventory: map()} | {:error, map()}
  def add_sale(%__MODULE__{} = asset_tracker, asset_symbol, sell_date, quantity, unit_price) do
    AddSalePipeline.call(%{
      asset_tracker: asset_tracker,
      asset_symbol: asset_symbol,
      sell_date: sell_date,
      quantity: quantity,
      unit_price: unit_price
    })
  end

  @doc """
    Returns the total unrealized capital gain or loss for the asset
  """
  @spec unrealized_gain_or_loss(
          %__MODULE__{inventory: map()},
          String.t(),
          %Decimal{}
        ) :: %Decimal{} | {:error, map()}
  def unrealized_gain_or_loss(%__MODULE__{} = asset_tracker, asset_symbol, market_price) do
    CalculateUnrealizedGainOrLossPipeline.call(%{
      asset_tracker: asset_tracker,
      asset_symbol: asset_symbol,
      market_price: market_price
    })
  end
end
