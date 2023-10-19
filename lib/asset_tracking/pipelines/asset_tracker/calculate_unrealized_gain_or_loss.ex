defmodule AssetTracking.Pipelines.AssetTracker.CalculateUnrealizedGainOrLoss do
  @moduledoc """
    Pipeline for calculating unrealized gain or loss for an asset.
  """

  use AssetTracking, :pipeline

  alias AssetTracking.Asset

  @doc """
    Pipeline function
  """
  @spec call(map()) :: %Decimal{} | {:error, map()}
  def call(input) do
    input_schema = %{
      asset_tracker: [type: %{inventory: [type: :map, required: true]}, required: true],
      asset_symbol: [type: :string, required: true],
      market_price: [type: :decimal, required: true, func: &must_be_positive/1]
    }

    Duct.Multi.new()
    |> Duct.Multi.run(:validated_input, fn _ -> validate_input(input, input_schema) end)
    |> Duct.Multi.run(:unrealized_gain_or_loss, &sum_unrealized_gain_or_loss/1)
    |> Duct.run()
    |> output()
  end

  defp sum_unrealized_gain_or_loss(%{
         validated_input: %{
           asset_tracker: asset_tracker,
           asset_symbol: asset_symbol,
           market_price: market_price
         }
       }) do
    %Asset{purchases: purchases} = Map.get(asset_tracker.inventory, asset_symbol, Asset.new())
    PriorityQueue.fold(purchases, Decimal.new(0), &sum_accumulator(&1, &2, market_price))
  end

  defp output({:error, _, reason, _input}), do: {:error, reason}

  defp output({:ok, %{unrealized_gain_or_loss: unrealized_gain_or_loss}}),
    do: unrealized_gain_or_loss

  defp sum_accumulator(purchase, acc, market_unit_price) do
    purchase_price = Decimal.mult(purchase.quantity, purchase.unit_price)
    market_price = Decimal.mult(purchase.quantity, market_unit_price)
    unrealized_capital_gain_or_loss = Decimal.sub(market_price, purchase_price)
    Decimal.add(acc, unrealized_capital_gain_or_loss)
  end
end
