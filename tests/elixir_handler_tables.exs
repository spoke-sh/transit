alias Transit.Station.Sdk.{Catalog, Logical, TableMutation, TableMutationReference, Value}
alias Transit.Station.Sdk.{Row, TableBasis, TablePage, TableCreation, TableStatus, TableWitness}
alias Transit.Client.ResourceRef

max = 18_446_744_073_709_551_615
resource = %ResourceRef{realm: 46, resource: 7}

schema = %Catalog.Schema{
  object: max,
  revision: 1,
  next_column: 4,
  columns: [
    %Catalog.Column{id: 1, name: "id", type: :int64, nullable: false},
    %Catalog.Column{id: 2, name: "amount", type: {:decimal, 20, 2}},
    %Catalog.Column{
      id: 3,
      name: "tags",
      type: {:list, %Logical.Element{type: :utf8, nullable: true}}
    }
  ],
  primary_key: [1]
}

mutation =
  {:insert,
   [
     [
       %Catalog.Assignment{column: 1, value: {:value, {:atom, {:signed, 7}}}},
       %Catalog.Assignment{column: 2, value: {:value, {:atom, {:decimal, 12345}}}},
       %Catalog.Assignment{
         column: 3,
         value: {:value, {:list, [:null, {:value, {:atom, {:utf8, "red"}}}]}}
       }
     ]
   ]}

{:ok, intent} = TableMutation.prepare(resource, 17, max, schema, mutation)
{:ok, saved} = TableMutation.save(intent)
{:ok, ^intent} = TableMutation.load(saved)
%{"schema" => actual} = :transit_sdk_value.json(saved, 96)
^schema = actual |> :transit_catalog_value.parse_schema() |> Catalog.convert()

# Catalog schema decoding must restore public logical structs at every depth,
# including element records shared by list, array and map descriptors.
for type <- [
      {:list, %Logical.Element{type: :utf8, nullable: true}},
      {:array, %Logical.Element{type: :int128}, 2},
      {:map, :utf8,
       %Logical.Element{
         type: {:list, %Logical.Element{type: {:decimal, 20, 2}, nullable: true}}
       }},
      {:structure,
       [
         %Logical.Field{
           name: "nested",
           type: {:list, %Logical.Element{type: :utf8}},
           optional: true
         }
       ]}
    ] do
  nested_schema = %Catalog.Schema{
    object: max,
    revision: 1,
    next_column: 2,
    columns: [%Catalog.Column{id: 1, name: "nested", type: type}]
  }

  ^nested_schema =
    nested_schema
    |> Catalog.native()
    |> :transit_catalog_value.schema()
    |> :transit_catalog_value.parse_schema()
    |> Catalog.convert()
end

{:error, _} = TableMutation.load(" " <> saved)
{:error, _} = TableMutation.prepare(resource, 17, 0, schema, mutation)

{:error, _} =
  TableMutation.prepare(resource, 17, max, schema, {:insert, List.duplicate([], 1025)})

{:ok, _} =
  TableMutation.prepare(
    resource,
    17,
    max,
    schema,
    {:update, [%Catalog.Assignment{column: 2, value: :default}], [{:state, 2, :null}]}
  )

reference = %{
  "definition" => :transit_catalog_value.definition(),
  "realm" => 46,
  "resource" => 7,
  "object" => Integer.to_string(max),
  "principal" => 17,
  "operation" => Integer.to_string(max),
  "digest" => String.duplicate("ab", 32)
}

reference_data = :transit_sdk_value.encode(reference)
{:ok, ref} = TableMutationReference.load(reference_data)
{:ok, ^reference_data} = TableMutationReference.save(ref)

{:error, _} =
  TableMutationReference.load(:transit_sdk_value.encode(Map.delete(reference, "definition")))

status = %{
  "reference" => reference,
  "state" => "applied",
  "route" => "statement",
  "admitted_input" => 9,
  "completed_input" => 11,
  "counts" => %{"matched" => "1", "changed" => "1"},
  "rejection" => "none",
  "witness" => nil
}

# Native neutral JSON null is :null; public absent optional fields are nil.
status = %{status | "witness" => :null}

%TableStatus{
  reference: ^ref,
  state: :applied,
  completed_input: 11,
  counts: %Catalog.Counts{matched: 1, changed: 1}
} =
  status |> :transit_table_value.status() |> Value.convert()

%TableCreation{state: :building, admitted_input: 9, completed_input: nil} =
  Value.convert({:transit_table_creation, :building, 9, :undefined})

%TableBasis{resource: ^resource, revision: 4, object: ^max, head: <<0::256>>} =
  Value.convert({:transit_table_basis, {:transit_resource, 46, 7}, 4, max, <<0::256>>})

%TablePage{rows: [%Row{identity: <<0::160>>, cells: [:null]}], next: nil} =
  Value.convert({:transit_table_page, [{:transit_row, <<0::160>>, [:null]}], :undefined})

%TableWitness{source: :withheld, row: nil, column: 1, text: "", truncated: false} =
  Value.convert({:transit_table_witness, :withheld, :undefined, 1, "", false})

plan = %Transit.Station.Sdk.UnifiedQuery.Plan{
  projection: [3, 1, 127],
  output_names: ["tags", nil, "last"],
  limit: max,
  predicate: {:compare, 1, :gt, {:decimal, 123}}
}

%{"projection" => [3, 1, 127], "limit" => "18446744073709551615"} =
  plan |> Transit.Station.Sdk.UnifiedQuery.native() |> :transit_unified_query.plan()

IO.puts(
  "Elixir handler Tables: general schemas, logical cells, saved mutations/references, typed outcomes and full-width query plans passed."
)
