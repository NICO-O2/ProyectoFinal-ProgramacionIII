defmodule Emergencias.Resumen do
  @moduledoc "Consultas consolidadas para el comando conceptual `summary`."
  alias Emergencias.Servidores.{RecursosServer, NecesidadesServer, PersonasServer, MascotasServer, AlberguesServer}

  def general do
    recursos = RecursosServer.listar()
    necesidades = NecesidadesServer.listar()
    personas_localizadas = PersonasServer.buscar(%{estado: :localizada})
    mensajes_pendientes = PersonasServer.mensajes_todos_pendientes()
    mascotas_activas = MascotasServer.listar(%{estado: :activa})
    albergues = AlberguesServer.listar()

    %{
      recursos: recursos,
      disponibilidad_por_unidad: recursos
        |> Enum.group_by(& &1.unidad)
        |> Enum.map(fn {unidad, items} -> {unidad, Enum.reduce(items, 0, fn r, total -> total + r.cantidad end)} end)
        |> Map.new(),
      necesidades_pendientes: Enum.filter(necesidades, &(&1.estado == :pendiente)),
      personas_localizadas: personas_localizadas,
      mensajes_pendientes: mensajes_pendientes,
      reportes_mascotas_activos: mascotas_activas,
      albergues: albergues
    }
  end
end
