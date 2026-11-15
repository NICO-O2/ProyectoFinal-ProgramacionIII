defmodule Emergencias.Servidores.MascotasServer do
  use GenServer
  alias Emergencias.Persistencia
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def reportar(tipo, especie, nombre, caracteristicas, color, tamano, zona, contacto), do: GenServer.call(__MODULE__, {:reportar, tipo, especie, nombre, caracteristicas, color, tamano, zona, contacto})
  def listar(filtros \\ %{}), do: GenServer.call(__MODULE__, {:listar, filtros})
  def coincidencias, do: GenServer.call(__MODULE__, :coincidencias)
  def confirmar(perdida_id, encontrada_id), do: GenServer.call(__MODULE__, {:confirmar, perdida_id, encontrada_id})
  @tipos [:perdida, :encontrada]
  @estados [:activa, :posible_coincidencia, :resuelta]
  @impl true
  def init(_), do: {:ok, Persistencia.cargar("mascotas", %{reportes: %{}, coincidencias: []})}
  @impl true
  def handle_call({:reportar, tipo, especie, nombre, caract, color, tamano, zona, contacto}, _f, s)
      when tipo in @tipos and is_binary(especie) and especie != "" do
    id = "M" <> Base.encode16(:crypto.strong_rand_bytes(8))
    reporte = %{id: id, tipo: tipo, especie: especie, nombre: nombre, caracteristicas: caract, color: color, tamano: tamano, zona: zona, contacto: contacto, estado: :activa, fecha: DateTime.utc_now()}
    nuevo = put_in(s.reportes[id], reporte); guardar(nuevo); {:reply, {:ok, reporte}, nuevo}
  end
  def handle_call({:reportar, _, _, _, _, _, _, _, _}, _f, s), do: {:reply, {:error, :datos_invalidos}, s}
  def handle_call({:listar, filtros}, _f, s) do
    lista = s.reportes |> Map.values() |> Enum.filter(fn r -> Enum.all?(filtros, fn {k, v} -> Map.get(r, k) == v end) end)
    {:reply, lista, s}
  end
  def handle_call(:coincidencias, _f, s) do
    perdidas = Enum.filter(Map.values(s.reportes), &(&1.tipo == :perdida and &1.estado != :resuelta))
    encontradas = Enum.filter(Map.values(s.reportes), &(&1.tipo == :encontrada and &1.estado != :resuelta))
    pares = for p <- perdidas, e <- encontradas, puntaje(p, e) >= 2, do: %{perdida: p.id, encontrada: e.id, puntaje: puntaje(p, e)}
    nuevo = Enum.reduce(pares, s, fn par, acc -> acc |> update_in([:reportes, par.perdida, :estado], fn _ -> :posible_coincidencia end) |> update_in([:reportes, par.encontrada, :estado], fn _ -> :posible_coincidencia end) end)
    guardar(nuevo); {:reply, Enum.sort_by(pares, & &1.puntaje, :desc), nuevo}
  end
  def handle_call({:confirmar, pid, eid}, _f, s) do
    with {:ok, p} <- fetch(s.reportes, pid), {:ok, e} <- fetch(s.reportes, eid),
         true <- p.tipo == :perdida and e.tipo == :encontrada and p.estado != :resuelta and e.estado != :resuelta do
      nuevo = s |> update_in([:reportes, pid, :estado], fn _ -> :resuelta end) |> update_in([:reportes, eid, :estado], fn _ -> :resuelta end)
      nuevo = %{nuevo | coincidencias: [%{perdida: pid, encontrada: eid, confirmada: true, fecha: DateTime.utc_now()} | nuevo.coincidencias]}
      guardar(nuevo); {:reply, {:ok, :coincidencia_confirmada}, nuevo}
    else false -> {:reply, {:error, :reportes_invalidos}, s}; error -> {:reply, error, s} end
  end
  # Puntaje de similitud: especie 2 puntos; color, tamaño, zona y nombre 1 punto cada uno.
  defp puntaje(a, b) do
    atributos = [{a.especie, b.especie, 2}, {a.color, b.color, 1}, {a.tamano, b.tamano, 1}, {a.zona, b.zona, 1}, {a.nombre, b.nombre, 1}]
    Enum.reduce(atributos, 0, fn {x, y, peso}, total -> if coincide?(x, y), do: total + peso, else: total end)
  end
  defp coincide?(x, y), do: not is_nil(x) and x != "" and x == y
  defp fetch(map, id), do: case Map.fetch(map, id) do {:ok, x} -> {:ok, x}; :error -> {:error, :no_existe} end
  defp guardar(s), do: Persistencia.guardar("mascotas", s)
end
