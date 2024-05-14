defmodule AssetTracking.Pipelines.AssetTracker.AddSale do
  @moduledoc """
    Pipeline that records the sale in the system,
    updates the inventory and returns a tuple containing the updated AssetTracker
    and the calculated gain or loss
  """

  use AssetTracking, :pipeline

  alias AssetTracking.Purchase
  alias AssetTracking.Asset
  alias AssetTracking.AssetTracker
  alias AssetTracking.Sale

  @doc """
    Pipeline function
  """
  @spec call(map()) ::
          {%AssetTracker{inventory: map()}, %Decimal{}} | {:error, map() | String.t()}
  def call(input) do
    input_schema = %{
      asset_tracker: [type: %{inventory: [type: :map, required: true]}, required: true],
      asset_symbol: [type: :string, required: true],
      sell_date: [type: :date, required: true],
      quantity: [type: :decimal, required: true, func: &must_be_positive/1],
      unit_price: [type: :decimal, required: true, func: &must_be_positive/1]
    }

    Duct.Multi.new()
    |> Duct.Multi.run(:validated_input, fn _ -> validate_input(input, input_schema) end)
    |> Duct.Multi.run(:asset_data, &get_asset_data/1)
    |> Duct.Multi.run(:available_quantity?, &determine_if_quantity_is_available/1)
    |> Duct.Multi.run(:total_sale_price, &calculate_total_sale_price/1)
    |> Duct.Multi.run(:updated_asset_data, &update_asset_sales/1)
    |> Duct.Multi.run(:updated_asset_tracker, &update_asset_tracker/1)
    |> Duct.Multi.run(:output, &sell_symbol/1)
    |> Duct.run()
    |> output()
  end

  defp get_asset_data(%{
         validated_input: %{asset_tracker: asset_tracker, asset_symbol: asset_symbol}
       }),
       do: Map.get(asset_tracker.inventory, asset_symbol, Asset.new())

  defp determine_if_quantity_is_available(%{
         validated_input: %{quantity: quantity},
         asset_data: %Asset{purchases: purchases}
       }) do
    quantity_available =
      PriorityQueue.fold(purchases, Decimal.new(0), &Decimal.add(&1.quantity, &2))

    Decimal.eq?(quantity_available, quantity) or Decimal.gt?(quantity_available, quantity)
  end

  defp calculate_total_sale_price(%{available_quantity?: false}),
    do: {:error, "You do not have enough quantity to make this sale"}

  defp calculate_total_sale_price(%{
         validated_input: %{quantity: quantity, unit_price: unit_price}
       }),
       do: Decimal.mult(quantity, unit_price)

  defp update_asset_sales(%{
         validated_input: %{sell_date: sell_date, quantity: quantity, unit_price: unit_price},
         asset_data: %Asset{sales: sales} = asset_data
       }) do
    %Asset{
      asset_data
      | sales:
          PriorityQueue.push_in(sales, %Sale{
            sell_date: sell_date,
            quantity: quantity,
            unit_price: unit_price
          })
    }
  end

  defp update_asset_tracker(%{
         validated_input: %{asset_tracker: asset_tracker, asset_symbol: asset_symbol},
         updated_asset_data: updated_asset_data
       }) do
    %AssetTracker{
      inventory: Map.put(asset_tracker.inventory, asset_symbol, updated_asset_data)
    }
  end

  defp sell_symbol(%{
         validated_input: %{
           asset_symbol: asset_symbol,
           quantity: quantity
         },
         total_sale_price: total_sale_price,
         updated_asset_tracker: %AssetTracker{} = asset_tracker
       }) do
    do_sell_symbol(
      asset_tracker,
      asset_symbol,
      total_sale_price,
      Decimal.to_float(quantity),
      Decimal.new(0)
    )
  end

  defp output({:error, _, reason, _input}), do: {:error, reason}

  defp output({:ok, %{output: output}}), do: output

  defp do_sell_symbol(
         %AssetTracker{} = asset_tracker,
         _,
         total_sale_price,
         +0.0,
         total_purchase_price
       ),
       do: {asset_tracker, Decimal.sub(total_sale_price, total_purchase_price)}

  defp do_sell_symbol(
         %AssetTracker{inventory: inventory} = asset_tracker,
         asset_symbol,
         total_sale_price,
         quantity_left,
         total_purchase_price
       ) do
    %Asset{purchases: purchases} = asset_data = Map.get(inventory, asset_symbol, Asset.new())

    {:ok, oldest_purchase} = PriorityQueue.peek(purchases)

    quantity_left = Decimal.from_float(quantity_left)

    max_quantity_to_sell = Decimal.min(oldest_purchase.quantity, quantity_left)

    new_purchase = %Purchase{
      oldest_purchase
      | quantity: Decimal.sub(oldest_purchase.quantity, max_quantity_to_sell)
    }

    new_quantity_left = quantity_left |> Decimal.sub(max_quantity_to_sell) |> Decimal.to_float()

    new_purchases =
      new_purchase.quantity
      |> Decimal.eq?(0)
      |> if do
        {:ok, {_, purchases_rest}} = PriorityQueue.out(purchases)
        purchases_rest
      else
        PriorityQueue.replace_head(purchases, new_purchase)
      end

    new_total_purchase_price =
      Decimal.add(
        total_purchase_price,
        Decimal.mult(max_quantity_to_sell, oldest_purchase.unit_price)
      )

    new_asset_data = %Asset{asset_data | purchases: new_purchases}

    new_inventory = %{inventory | asset_symbol => new_asset_data}

    new_asset_tracker = %AssetTracker{asset_tracker | inventory: new_inventory}

    do_sell_symbol(
      new_asset_tracker,
      asset_symbol,
      total_sale_price,
      new_quantity_left,
      new_total_purchase_price
    )
  end
end
