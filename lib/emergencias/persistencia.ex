defmodule Emergencias.Persistencia do
  @moduledoc "Persistencia sencilla en archivos de texto plano (Base64 de término Erlang)."
  def cargar(nombre, defecto \\ %{}) do
    ruta = ruta(nombre)
    case File.read(ruta) do
      {:ok, contenido} ->
        try do
          contenido |> String.trim() |> Base.decode64!() |> :erlang.binary_to_term([:safe])
        rescue
          _ -> defecto
        end
      {:error, _} -> defecto
    end
  end
  def guardar(nombre, dato) do
    ruta = ruta(nombre)
    with :ok <- File.mkdir_p(Path.dirname(ruta)),
         contenido = dato |> :erlang.term_to_binary() |> Base.encode64(),
         :ok <- File.write(ruta, contenido) do
      :ok
    end
  end
  defp ruta(nombre), do: Path.join([File.cwd!(), "data", "#{nombre}.txt"])
end
