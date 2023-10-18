defmodule AssetTracking.AssetTrackerTest do
  use ExUnit.Case, async: true

  alias AssetTracking.Sale
  alias AssetTracking.Asset
  alias AssetTracking.Purchase
  alias AssetTracking.AssetTracker

  test "new/0 should return %AssetTracker{} with empty inventory" do
    assert %AssetTracker{inventory: %{}} = AssetTracker.new()
  end

  describe "add_purchase/5" do
    setup :generate_valid_purchases_attrs

    test "should return error when invalid input", %{some_purchase: some_purchase} do
      assert {:error, %{asset_symbol: ["is invalid"]}} =
               AssetTracker.add_purchase(
                 AssetTracker.new(),
                 123,
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )

      assert {:error, %{settle_date: ["is required"]}} =
               AssetTracker.add_purchase(
                 AssetTracker.new(),
                 "APPL",
                 nil,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )

      assert {:error, %{quantity: ["must be positive"]}} =
               AssetTracker.add_purchase(
                 AssetTracker.new(),
                 "APPL",
                 some_purchase.settle_date,
                 0,
                 some_purchase.unit_price
               )
    end

    test "should add new purchase to asset purchases queue when current asset purchases queue is empty",
         %{
           some_purchase: some_purchase
         } do
      assert %AssetTracker{inventory: %{"APPL" => %Asset{purchases: purchases}}} =
               AssetTracker.add_purchase(
                 AssetTracker.new(),
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )

      assert Prioqueue.size(purchases) == 1
    end

    test "should add new purchase to asset purchases queue when current asset purchases queue is not empty",
         %{
           some_purchase: some_purchase,
           future_purchase: future_purchase
         } do
      assert %AssetTracker{inventory: %{"APPL" => %Asset{purchases: purchases}}} =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_purchase(
                 "APPL",
                 future_purchase.settle_date,
                 future_purchase.quantity,
                 future_purchase.unit_price
               )

      assert Prioqueue.size(purchases) == 2

      # The oldest purchase should be the head of the queue
      assert {:ok, head} = Prioqueue.peek_min(purchases)
      assert Decimal.eq?(head.quantity, some_purchase.quantity)
      assert Decimal.eq?(head.unit_price, some_purchase.unit_price)
      assert Date.compare(head.settle_date, some_purchase.settle_date) == :eq
    end

    test "if the settle date of the purchases are equal, the oldest purchase should be considered the purchase that was inserted first",
         %{some_purchase: some_purchase} do
      another_quantity = 2
      another_price = Decimal.new(1000)

      assert %AssetTracker{inventory: %{"APPL" => %Asset{purchases: purchases}}} =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 another_quantity,
                 another_price
               )
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )

      assert Prioqueue.size(purchases) == 2

      assert {:ok, head} = Prioqueue.peek_min(purchases)
      assert Decimal.eq?(head.quantity, another_quantity)
      assert Decimal.eq?(head.unit_price, another_price)
    end

    test "should add two new purchases, one for each asset", %{some_purchase: some_purchase} do
      assert %AssetTracker{
               inventory: %{
                 "APPL" => %Asset{purchases: appl_purchases},
                 "SAMSUN" => %Asset{purchases: samsun_purchases}
               }
             } =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_purchase(
                 "SAMSUN",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )

      assert Prioqueue.size(appl_purchases) == 1
      assert Prioqueue.size(samsun_purchases) == 1
    end
  end

  describe "add_sale/5" do
    setup :generate_valid_purchases_and_sales_attrs

    test "should return error when invalid input", %{some_sale: some_sale} do
      assert {:error, %{asset_symbol: ["is invalid"]}} =
               AssetTracker.add_sale(
                 AssetTracker.new(),
                 123,
                 some_sale.sell_date,
                 some_sale.quantity,
                 some_sale.unit_price
               )

      assert {:error, %{sell_date: ["is required"]}} =
               AssetTracker.add_sale(
                 AssetTracker.new(),
                 "APPL",
                 nil,
                 some_sale.quantity,
                 some_sale.unit_price
               )

      assert {:error, %{quantity: ["must be positive"]}} =
               AssetTracker.add_sale(
                 AssetTracker.new(),
                 "APPL",
                 some_sale.sell_date,
                 0,
                 some_sale.unit_price
               )
    end

    test "should return error if there is an attempt to sell a quantity greater than available",
         %{
           some_purchase: some_purchase,
           some_sale: some_sale
         } do
      assert {:error, "You do not have enough quantity to make this sale"} =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_sale(
                 "APPL",
                 some_sale.sell_date,
                 some_sale.quantity,
                 some_sale.unit_price
               )
    end

    test "update asset tracker after a sale", %{
      some_purchase: some_purchase,
      single_unit_sale: single_unit_sale
    } do
      assert {%AssetTracker{
                inventory: %{
                  "APPL" => %Asset{purchases: purchases, sales: sales}
                }
              },
              realized_gain_or_loss} =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_sale(
                 "APPL",
                 single_unit_sale.sell_date,
                 single_unit_sale.quantity,
                 single_unit_sale.unit_price
               )

      assert Decimal.eq?(realized_gain_or_loss, Decimal.new(-90))
      assert Prioqueue.size(purchases) == 1
      assert Prioqueue.size(sales) == 1
    end

    test "update first the older purchase if more than 1 purchase", %{
      some_purchase: some_purchase,
      future_purchase: future_purchase,
      single_unit_sale: single_unit_sale
    } do
      assert {%AssetTracker{
                inventory: %{
                  "APPL" => %Asset{purchases: purchases, sales: sales}
                }
              },
              realized_gain_or_loss} =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 future_purchase.settle_date,
                 future_purchase.quantity,
                 future_purchase.unit_price
               )
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_sale(
                 "APPL",
                 single_unit_sale.sell_date,
                 single_unit_sale.quantity,
                 single_unit_sale.unit_price
               )

      assert Decimal.eq?(realized_gain_or_loss, Decimal.new(-90))
      assert Prioqueue.size(purchases) == 2
      assert Prioqueue.size(sales) == 1

      assert {:ok, oldest_purchase} = Prioqueue.peek_min(purchases)

      assert some_purchase.quantity
             |> Decimal.sub(single_unit_sale.quantity)
             |> Decimal.eq?(oldest_purchase.quantity)
    end

    test "purchases queue should be empty after the last purchase has had all its units sold", %{
      some_purchase: some_purchase,
      some_sale: some_sale
    } do
      assert {%AssetTracker{
                inventory: %{
                  "APPL" => %Asset{purchases: purchases, sales: sales}
                }
              },
              realized_gain_or_loss} =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_sale(
                 "APPL",
                 some_sale.sell_date,
                 some_purchase.quantity,
                 some_sale.unit_price
               )

      assert Decimal.eq?(realized_gain_or_loss, Decimal.new(600))
      assert Prioqueue.empty?(purchases)
      assert Prioqueue.size(sales) == 1
    end

    test "purchases queue should be reduced in size after a purchase has had all its units sold",
         %{
           some_purchase: some_purchase,
           future_purchase: future_purchase,
           some_sale: some_sale
         } do
      assert {%AssetTracker{
                inventory: %{
                  "APPL" => %Asset{purchases: purchases, sales: sales}
                }
              },
              realized_gain_or_loss} =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_purchase(
                 "APPL",
                 future_purchase.settle_date,
                 future_purchase.quantity,
                 future_purchase.unit_price
               )
               |> AssetTracker.add_sale(
                 "APPL",
                 some_sale.sell_date,
                 some_purchase.quantity,
                 some_sale.unit_price
               )

      assert Decimal.eq?(realized_gain_or_loss, Decimal.new(600))
      assert Prioqueue.size(purchases) == 1
      assert Prioqueue.size(sales) == 1
    end

    test "oldest sale should be inserted at the head of the sales queue", %{
      some_purchase: some_purchase,
      single_unit_sale: single_unit_sale,
      future_sale: future_sale
    } do
      assert {%AssetTracker{
                inventory: %{
                  "APPL" => %Asset{purchases: purchases, sales: sales}
                }
              } = asset_tracker,
              realized_gain_or_loss} =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_sale(
                 "APPL",
                 future_sale.sell_date,
                 future_sale.quantity,
                 future_sale.unit_price
               )

      assert Decimal.eq?(realized_gain_or_loss, Decimal.new(-160))
      assert Prioqueue.size(purchases) == 1
      assert Prioqueue.size(sales) == 1

      assert {%AssetTracker{
                inventory: %{
                  "APPL" => %Asset{purchases: purchases, sales: sales}
                }
              },
              realized_gain_or_loss} =
               AssetTracker.add_sale(
                 asset_tracker,
                 "APPL",
                 single_unit_sale.sell_date,
                 single_unit_sale.quantity,
                 single_unit_sale.unit_price
               )

      assert Decimal.eq?(realized_gain_or_loss, Decimal.new(-90))
      assert Prioqueue.empty?(purchases)
      assert Prioqueue.size(sales) == 2

      assert {:ok, oldest_sale} = Prioqueue.peek_min(sales)
      assert oldest_sale == single_unit_sale
    end

    test "the sale of one asset should not interfere with others", %{
      some_purchase: some_purchase,
      single_unit_sale: single_unit_sale
    } do
      assert {%AssetTracker{
                inventory: %{
                  "APPL" => %Asset{purchases: appl_purchases, sales: appl_sales},
                  "SAMSUN" => %Asset{purchases: samsun_purchases, sales: samsun_sales}
                }
              },
              realized_gain_or_loss} =
               AssetTracker.new()
               |> AssetTracker.add_purchase(
                 "APPL",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_purchase(
                 "SAMSUN",
                 some_purchase.settle_date,
                 some_purchase.quantity,
                 some_purchase.unit_price
               )
               |> AssetTracker.add_sale(
                 "SAMSUN",
                 single_unit_sale.sell_date,
                 single_unit_sale.quantity,
                 single_unit_sale.unit_price
               )

      assert Decimal.eq?(realized_gain_or_loss, Decimal.new(-90))

      assert Prioqueue.size(appl_purchases) == 1
      assert Prioqueue.empty?(appl_sales)

      assert Prioqueue.size(samsun_purchases) == 1
      assert Prioqueue.size(samsun_sales) == 1

      assert {:ok, samsun_sale} = Prioqueue.peek_min(samsun_sales)
      assert samsun_sale == single_unit_sale

      assert {:ok, samsun_purchase} = Prioqueue.peek_min(samsun_purchases)

      assert some_purchase.quantity
             |> Decimal.sub(single_unit_sale.quantity)
             |> Decimal.eq?(samsun_purchase.quantity)

      assert {:ok, appl_purchase} = Prioqueue.peek_min(appl_purchases)
      assert Decimal.eq?(some_purchase.quantity, appl_purchase.quantity)
    end
  end

  describe "unrealized_gain_or_loss/3" do
    setup :generate_valid_purchases_and_sales_attrs

    test "should return error when invalid input" do
      assert {:error, %{market_price: ["is invalid"]}} =
               AssetTracker.unrealized_gain_or_loss(
                 AssetTracker.new(),
                 "APPL",
                 "abcd"
               )

      assert {:error, %{asset_symbol: ["is required"]}} =
               AssetTracker.unrealized_gain_or_loss(
                 AssetTracker.new(),
                 nil,
                 Decimal.new(123)
               )
    end

    test "if there is not any purchase for the symbol then return zero" do
      AssetTracker.new()
      |> AssetTracker.unrealized_gain_or_loss(
        "APPL",
        Decimal.new(300)
      )
      |> Kernel.==(Decimal.new(0))
      |> assert()
    end

    test "should correctly calculate unrealized gain", %{
      some_purchase: some_purchase,
      future_purchase: future_purchase
    } do
      AssetTracker.new()
      |> AssetTracker.add_purchase(
        "APPL",
        some_purchase.settle_date,
        some_purchase.quantity,
        some_purchase.unit_price
      )
      |> AssetTracker.add_purchase(
        "APPL",
        future_purchase.settle_date,
        future_purchase.quantity,
        future_purchase.unit_price
      )
      |> AssetTracker.unrealized_gain_or_loss("APPL", Decimal.new(300))
      |> Kernel.==(Decimal.new(1100))
      |> assert()
    end

    test "should correctly compute unrealized loss", %{
      some_purchase: some_purchase,
      future_purchase: future_purchase
    } do
      AssetTracker.new()
      |> AssetTracker.add_purchase(
        "APPL",
        some_purchase.settle_date,
        some_purchase.quantity,
        some_purchase.unit_price
      )
      |> AssetTracker.add_purchase(
        "APPL",
        future_purchase.settle_date,
        future_purchase.quantity,
        future_purchase.unit_price
      )
      |> AssetTracker.unrealized_gain_or_loss("APPL", Decimal.new(50))
      |> Kernel.==(Decimal.new(-900))
      |> assert()
    end

    test "should correctly compute unrealized gain with sales", %{
      some_purchase: some_purchase,
      future_purchase: future_purchase,
      some_sale: some_sale
    } do
      AssetTracker.new()
      |> AssetTracker.add_purchase(
        "APPL",
        some_purchase.settle_date,
        some_purchase.quantity,
        some_purchase.unit_price
      )
      |> AssetTracker.add_purchase(
        "APPL",
        future_purchase.settle_date,
        future_purchase.quantity,
        future_purchase.unit_price
      )
      |> AssetTracker.add_sale(
        "APPL",
        some_sale.sell_date,
        some_sale.quantity,
        some_sale.unit_price
      )
      |> elem(0)
      |> AssetTracker.unrealized_gain_or_loss("APPL", Decimal.new(300))
      |> Kernel.==(Decimal.new(400))
      |> assert()
    end

    test "should correctly compute unrealized loss with sales", %{
      some_purchase: some_purchase,
      future_purchase: future_purchase,
      some_sale: some_sale
    } do
      AssetTracker.new()
      |> AssetTracker.add_purchase(
        "APPL",
        some_purchase.settle_date,
        some_purchase.quantity,
        some_purchase.unit_price
      )
      |> AssetTracker.add_purchase(
        "APPL",
        future_purchase.settle_date,
        future_purchase.quantity,
        future_purchase.unit_price
      )
      |> AssetTracker.add_sale(
        "APPL",
        some_sale.sell_date,
        some_sale.quantity,
        some_sale.unit_price
      )
      |> elem(0)
      |> AssetTracker.unrealized_gain_or_loss("APPL", Decimal.new(50))
      |> Kernel.==(Decimal.new(-600))
      |> assert()
    end
  end

  defp generate_valid_purchases_attrs(_context) do
    some_purchase = %Purchase{
      settle_date: Date.utc_today(),
      quantity: Decimal.new(3),
      unit_price: Decimal.new(100)
    }

    future_purchase = %Purchase{
      settle_date: Date.add(Date.utc_today(), 1),
      quantity: Decimal.new(5),
      unit_price: Decimal.new(200)
    }

    {:ok, %{some_purchase: some_purchase, future_purchase: future_purchase}}
  end

  defp generate_valid_purchases_and_sales_attrs(context) do
    {:ok, purchases} = generate_valid_purchases_attrs(context)

    some_sale = %Sale{
      sell_date: Date.utc_today(),
      quantity: Decimal.new(4),
      unit_price: Decimal.new(300)
    }

    single_unit_sale = %Sale{
      sell_date: Date.utc_today(),
      quantity: Decimal.new(1),
      unit_price: Decimal.new(10)
    }

    future_sale = %Sale{
      sell_date: Date.add(Date.utc_today(), 1),
      quantity: Decimal.new(2),
      unit_price: Decimal.new(20)
    }

    sales = %{some_sale: some_sale, single_unit_sale: single_unit_sale, future_sale: future_sale}

    {:ok, Map.merge(sales, purchases)}
  end
end
