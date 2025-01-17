defmodule EctoEnumMigration do
  @moduledoc """
  Provides a DSL to easily handle Postgres Enum Types in Ecto database migrations.
  """

  import Ecto.Migration, only: [execute: 1, execute: 2]

  @doc """
  Create a Postgres Enum Type.

  ## Examples

  ```elixir
  defmodule MyApp.Repo.Migrations.CreateTypeMigration do
    use Ecto.Migration
    import EctoEnumMigration

    def change do
      create_type(:status, [:registered, :active, :inactive, :archived])
    end
  end
  ```

  By default the type will be created in the `public` schema.
  To change the schema of the type pass the `schema` option.

  ```elixir
  create_type(:status, [:registered, :active, :inactive, :archived], schema: "custom_schema")
  ```

  """
  @spec create_type(name :: atom(), values :: [atom()], opts :: Keyword.t()) :: :ok | no_return()
  def create_type(name, values, opts \\ [])
      when is_atom(name) and is_list(values) and is_list(opts) do
    type_name = type_name(name, opts)
    type_values = values |> Enum.map(fn value -> "'#{value}'" end) |> Enum.join(", ")

    create_sql = "CREATE TYPE #{type_name} AS ENUM (#{type_values});"
    drop_sql = "DROP TYPE #{type_name};"

    execute(create_sql, drop_sql)
  end

  @doc """
  Drop a Postgres Enum Type.

  This command is not reversible, so make sure to include a `down/0` step in the migration.


  ## Examples

  ```elixir
  defmodule MyApp.Repo.Migrations.DropTypeMigration do
    use Ecto.Migration
    import EctoEnumMigration

    def up do
      drop_type(:status)
    end

    def down do
      create_type(:status, [:registered, :active, :inactive, :archived])
    end
  end
  ```

  By default the type will be created in the `public` schema.
  To change the schema of the type pass the `schema` option.

  ```elixir
  drop_type(:status, schema: "custom_schema")
  ```

  """
  @spec drop_type(name :: atom(), opts :: Keyword.t()) :: :ok | no_return()
  def drop_type(name, opts \\ []) when is_atom(name) and is_list(opts) do
    [
      "DROP TYPE",
      if_exists_sql(opts),
      type_name(name, opts),
      ";"
    ]
    |> execute_query()
  end

  @doc """
  Rename a Postgres Type.

  ## Examples

  ```elixir
  defmodule MyApp.Repo.Migrations.RenameTypeMigration do
    use Ecto.Migration
    import EctoEnumMigration

    def change do
      rename_type(:status, :status_renamed)
    end
  end
  ```

  By default the type will be created in the `public` schema.
  To change the schema of the type pass the `schema` option.

  ```elixir
  rename_type(:status, :status_renamed, schema: "custom_schema")
  ```

  """
  @spec rename_type(before_name :: atom(), after_name :: atom(), opts :: Keyword.t()) ::
          :ok | no_return()
  def rename_type(before_name, after_name, opts \\ [])
      when is_atom(before_name) and is_atom(after_name) and is_list(opts) do
    before_type_name = type_name(before_name, opts)
    after_type_name = type_name(after_name, opts)

    up_sql = "ALTER TYPE #{before_type_name} RENAME TO #{after_name};"
    down_sql = "ALTER TYPE #{after_type_name} RENAME TO #{before_name};"

    execute(up_sql, down_sql)
  end

  @doc """
  Add a value to a existing Postgres type.

  This operation is not reversible, existing values cannot be removed from an enum type.
  Checkout [Enumerated Types](https://www.postgresql.org/docs/current/datatype-enum.html)
  for more information.

  Also it cannot be used inside a transaction block, we need to set
  `@disable_ddl_transaction true` in the migration.

  ## Examples

  ```elixir
  defmodule MyApp.Repo.Migrations.AddValueToTypeMigration do
    use Ecto.Migration
    import EctoEnumMigration
    @disable_ddl_transaction true

    def up do
      add_value_to_type(:status, :finished)
    end
    
    def down do
    end
  end
  ```

  By default the type will be created in the `public` schema.
  To change the schema of the type pass the `schema` option.

  ```elixir
  add_value_to_type(:status, :finished, schema: "custom_schema")
  ```

  If the new value's place in the enum's ordering is not specified,
  then the new item is placed at the end of the list of values.

  But we specify the the place in the ordering for the new value with the
  `:before` and `:after` options.

  ```elixir
  add_value_to_type(:status, :finished, before: :started)
  ```

  ```elixir
  add_value_to_type(:status, :finished, after: :started)
  ```

  If you want to avoid having issues when the value already exists, you can specify the option `if_not_exists: true`.

  """
  @spec add_value_to_type(name :: atom(), value :: atom(), opts :: Keyword.t()) ::
          :ok | no_return()

  def add_value_to_type(name, value, opts \\ []) do
    [
      "ALTER TYPE",
      type_name(name, opts),
      "ADD VALUE",
      if_not_exists(opts),
      to_value(value),
      before_after(opts),
      ";"
    ]
    |> execute_query()
  end

  @doc """
  Rename a value of a Postgres Type.

  ***Only compatible with Postgres version 10+***

  ## Examples

  ```elixir
  defmodule MyApp.Repo.Migrations.RenameTypeMigration do
    use Ecto.Migration
    import EctoEnumMigration

    def change do
      rename_value(:status, :finished, :done)
    end
  end
  ```

  By default the type will be created in the `public` schema.
  To change the schema of the type pass the `schema` option.

  ```elixir
  rename_value(:status, :finished, :done, schema: "custom_schema")
  ```

  """
  @spec rename_value(
          type_name :: atom(),
          before_value :: atom(),
          after_value :: atom(),
          opts :: Keyword.t()
        ) :: :ok | no_return()

  def rename_value(type_name, before_value, after_value, opts \\ [])
      when is_atom(type_name) and is_atom(before_value) and is_atom(after_value) and is_list(opts) do
    type_name = type_name(type_name, opts)
    before_value = to_value(before_value)
    after_value = to_value(after_value)

    up_sql = "
      ALTER TYPE #{type_name} RENAME VALUE #{before_value} TO #{after_value};
    "

    down_sql = "
      ALTER TYPE #{type_name} RENAME VALUE #{after_value} TO #{before_value};
    "

    execute(up_sql, down_sql)
  end

  defp if_not_exists(opts) do
    if_not_exists = Keyword.get(opts, :if_not_exists)

    if if_not_exists do
      ["IF NOT EXISTS"]
    else
      []
    end
  end

  defp before_after(opts) do
    before_value = Keyword.get(opts, :before)
    after_value = Keyword.get(opts, :after)

    cond do
      before_value ->
        ["BEFORE ", to_value(before_value)]

      after_value ->
        ["AFTER ", to_value(after_value)]

      true ->
        []
    end
  end

  defp to_value(value) do
    [?', to_string(value), ?']
  end

  defp type_name(name, opts) do
    schema = Keyword.get(opts, :schema, "public")
    "#{schema}.#{name}"
  end

  defp if_exists_sql(opts) do
    if Keyword.get(opts, :if_exists, false) do
      "IF EXISTS"
    else
      []
    end
  end

  defp execute_query(terms) do
    terms
    |> Enum.reject(&(is_nil(&1) || &1 == []))
    |> Enum.intersperse(?\s)
    |> IO.iodata_to_binary()
    |> execute()
  end
end
