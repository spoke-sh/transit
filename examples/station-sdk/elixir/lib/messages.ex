defmodule Transit.SdkExamples.Add do
  @enforce_keys [:value]
  defstruct [:value]
end

defmodule Transit.SdkExamples.Total do
  @enforce_keys [:value]
  defstruct [:value]
end

defmodule Transit.SdkExamples.Read do
  defstruct []
end

defmodule Transit.SdkExamples.Start do
  defstruct []
end

defmodule Transit.SdkExamples.Initialize do
  defstruct []
end

defmodule Transit.SdkExamples.Insert do
  @enforce_keys [:key]
  defstruct [:key, value: nil]
end

defmodule Transit.SdkExamples.Rows do
  defstruct []
end
