defmodule Emergencias.Dominio.Necesidad do
  defstruct [
    :id,
    :tipo,
    :descripcion,
    :cantidad,
    :zona,
    :prioridad,
    :responsable,
    estado: :pendiente
  ]

  @tipos [
    :agua,
    :alimentos,
    :medicamentos,
    :primeros_auxilios,
    :refugio,
    :transporte,
    :rescate,
    :otra
  ]
  @prioridades [:critica, :alta, :media, :baja]

  @transiciones %{
    pendiente: [:asignada, :cancelada],
    asignada: [:en_atencion, :cancelada],
    en_atencion: [:atendida, :cancelada],
    atendida: [],
    cancelada: []
  }

  def nueva(id, tipo, descripcion, cantidad, zona, prioridad, responsable)
      when tipo in @tipos and prioridad in @prioridades and is_number(cantidad) and cantidad > 0 do
    {:ok,
     %__MODULE__{
       id: id,
       tipo: tipo,
       descripcion: descripcion,
       cantidad: cantidad,
       zona: zona,
       prioridad: prioridad,
       responsable: responsable
     }}
  end

  def nueva(_, _, _, _, _, _, _), do: {:error, :datos_invalidos}

  def cambiar_estado(%__MODULE__{estado: actual} = necesidad, nuevo) do
    if nuevo in Map.get(@transiciones, actual, []) do
      {:ok, %{necesidad | estado: nuevo}}
    else
      {:error, {:transicion_invalida, actual, nuevo}}
    end
  end

  def peso(:critica), do: 1
  def peso(:alta), do: 2
  def peso(:media), do: 3
  def peso(:baja), do: 4

  def ordenar_por_prioridad([]), do: []

  def ordenar_por_prioridad([cabeza | resto]) do
    insertar(cabeza, ordenar_por_prioridad(resto))
  end

  defp insertar(necesidad, []), do: [necesidad]

  defp insertar(necesidad, [primera | demas] = ordenadas) do
    if peso(necesidad.prioridad) <= peso(primera.prioridad) do
      [necesidad | ordenadas]
    else
      [primera | insertar(necesidad, demas)]
    end
  end
end
