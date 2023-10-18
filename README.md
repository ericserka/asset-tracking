# AssetTracking

This project was developed using the latest version of elixir (1.15.7) and aims to track assets and calculate capital gains or losses.

The code is documented using [Typespecs](https://hexdocs.pm/elixir/typespecs.html), inline comments, function documentation (@doc) and module documentation (@moduledoc). The code was also tested using ExUnit.

As external dependencies, the following were used:

1. [Duct.Multi](https://hexdocs.pm/duct/Duct.Multi.html): a clean pipeline pattern 
2. [Tarams](https://hexdocs.pm/tarams/readme.html) for input validation
3. [ExDoc](https://hexdocs.pm/ex_doc/readme.html) for documentation generation
4. [Decimal](https://hexdocs.pm/decimal/Decimal.html) for handling quantities and prices
5. [Prioqueue](https://hexdocs.pm/prioqueue/api-reference.html) to guarantee the fifo procedure based on dates

## Usage

1. Have the elixir installed on your machine.
2. Run `mix deps.get` to install project dependencies.


Now, you can:

- Run `iex -S mix` to open the interactive elixir.
- Run `mix test` to run all the project tests.
- Run `mix docs` and open `doc/index.html` file to access documentation in the browser.