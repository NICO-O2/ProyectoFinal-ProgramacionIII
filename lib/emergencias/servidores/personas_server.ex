defmodule Emergencias.Servidores.PersonasServer do
  use GenServer
  alias Emergencias.Persistencia

  @estados [:sin_informacion, :reportada, :localizada, :trasladada, :en_albergue, :reunificada]
  @transiciones %{
    sin_informacion: [:reportada, :localizada],
    reportada: [:localizada, :trasladada],
    localizada: [:trasladada, :en_albergue, :reunificada],
    trasladada: [:en_albergue, :reunificada],
    en_albergue: [:trasladada, :reunificada],
    reunificada: []
  }

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def registrar(documento, nombre, edad, zona, estado \\ :reportada), do: GenServer.call(__MODULE__, {:registrar, documento, nombre, edad, zona, estado})
  def buscar(filtros), do: GenServer.call(__MODULE__, {:buscar, filtros})
  def cambiar_estado(documento, estado), do: GenServer.call(__MODULE__, {:estado, documento, estado})
  def enviar_mensaje(documento, remitente, destinatario, contenido), do: GenServer.call(__MODULE__, {:mensaje, documento, remitente, destinatario, contenido})
  def mensajes(documento), do: GenServer.call(__MODULE__, {:mensajes, documento})
  def mensajes_todos_pendientes, do: GenServer.call(__MODULE__, :mensajes_pendientes)
  def marcar_mensaje(documento, mensaje_id, estado), do: GenServer.call(__MODULE__, {:marcar_mensaje, documento, mensaje_id, estado})

  @impl true
  def init(_opts), do: {:ok, Persistencia.cargar("personas", %{personas: %{}, mensajes: []})}

  @impl true
  def handle_call({:registrar, doc, nombre, edad, zona, estado}, _from, estado_sistema)
      when is_binary(doc) and doc != "" and is_binary(nombre) and is_integer(edad) and edad >= 0 and estado in @estados do
    if Map.has_key?(estado_sistema.personas, doc) do
      {:reply, {:error, :id_repetido}, estado_sistema}
    else
      persona = %{
        documento: doc,
        nombre: nombre,
        edad: edad,
        zona: zona,
        estado: estado,
        historial: [%{estado: estado, fecha: DateTime.utc_now()}]
      }
      nuevo = put_in(estado_sistema.personas[doc], persona)
      guardar(nuevo)
      {:reply, {:ok, persona}, nuevo}
    end
  end

  def handle_call({:registrar, _, _, _, _, _}, _from, estado),
    do: {:reply, {:error, :datos_invalidos}, estado}

  def handle_call({:buscar, filtros}, _from, estado) do
    encontrados = estado.personas
      |> Map.values()
      |> Enum.filter(fn persona ->
        Enum.all?(filtros, fn {clave, valor} -> Map.get(persona, clave) == valor end)
      end)
    {:reply, encontrados, estado}
  end

  def handle_call({:estado, doc, nuevo_estado}, _from, estado) when nuevo_estado in @estados do
    case Map.fetch(estado.personas, doc) do
      {:ok, persona} ->
        if nuevo_estado in Map.get(@transiciones, persona.estado, []) do
          actualizado = %{persona |
            estado: nuevo_estado,
            historial: [%{estado: nuevo_estado, fecha: DateTime.utc_now()} | persona.historial]
          }
          nuevo = put_in(estado.personas[doc], actualizado)
          guardar(nuevo)
          {:reply, {:ok, actualizado}, nuevo}
        else
          {:reply, {:error, {:transicion_invalida, persona.estado, nuevo_estado}}, estado}
        end
      :error -> {:reply, {:error, :no_existe}, estado}
    end
  end

  def handle_call({:estado, _, _}, _from, estado),
    do: {:reply, {:error, :estado_invalido}, estado}

  def handle_call({:mensaje, doc, remitente, destinatario, contenido}, _from, estado)
      when is_binary(contenido) and contenido != "" do
    if Map.has_key?(estado.personas, doc) do
      mensaje = %{
        id: Base.encode16(:crypto.strong_rand_bytes(8)),
        documento: doc,
        remitente: remitente,
        destinatario: destinatario,
        contenido: contenido,
        fecha: DateTime.utc_now(),
        estado: :pendiente
      }
      nuevo = %{estado | mensajes: [mensaje | estado.mensajes]}
      guardar(nuevo)
      {:reply, {:ok, mensaje}, nuevo}
    else
      {:reply, {:error, :persona_no_existe}, estado}
    end
  end

  def handle_call({:mensaje, _, _, _, _}, _from, estado),
    do: {:reply, {:error, :datos_invalidos}, estado}

  def handle_call({:mensajes, doc}, _from, estado) do
    {:reply, Enum.filter(estado.mensajes, &(&1.documento == doc)), estado}
  end

  def handle_call(:mensajes_pendientes, _from, estado) do
    {:reply, Enum.filter(estado.mensajes, &(&1.estado == :pendiente)), estado}
  end

  def handle_call({:marcar_mensaje, doc, id, nuevo_estado}, _from, estado)
      when nuevo_estado in [:pendiente, :entregado] do
    case Enum.find_index(estado.mensajes, &(&1.documento == doc and &1.id == id)) do
      nil -> {:reply, {:error, :mensaje_no_existe}, estado}
      indice ->
        mensaje = estado.mensajes |> Enum.at(indice) |> Map.put(:estado, nuevo_estado)
        mensajes = List.replace_at(estado.mensajes, indice, mensaje)
        nuevo = %{estado | mensajes: mensajes}
        guardar(nuevo)
        {:reply, {:ok, mensaje}, nuevo}
    end
  end

  def handle_call({:marcar_mensaje, _, _, _}, _from, estado),
    do: {:reply, {:error, :estado_invalido}, estado}

  defp guardar(estado), do: Persistencia.guardar("personas", estado)
end
