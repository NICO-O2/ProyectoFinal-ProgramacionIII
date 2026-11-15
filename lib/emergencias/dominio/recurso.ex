defmodule Emergencias.Dominio.Recurso do
  @moduledoc "Estructura y reglas puras para un recurso del inventario."
  defstruct [:codigo, :nombre, :categoria, :cantidad, :unidad, :ubicacion, historial: []]

  def nuevo(codigo, nombre, categoria, cantidad, unidad, ubicacion)
      when is_binary(codigo) and byte_size(codigo) > 0 and is_binary(nombre) and
             is_number(cantidad) and cantidad >= 0 do
    {:ok, %__MODULE__{codigo: codigo, nombre: nombre, categoria: categoria,
      cantidad: cantidad, unidad: unidad, ubicacion: ubicacion}}
  end

  def nuevo(_, _, _, _, _, _), do: {:error, :datos_invalidos}

  def retirar(%__MODULE__{cantidad: actual} = recurso, cantidad)
      when is_number(cantidad) and cantidad > 0 and cantidad <= actual do
    movimiento = %{tipo: :salida, cantidad: cantidad, fecha: DateTime.utc_now()}
    {:ok, %{recurso | cantidad: actual - cantidad, historial: [movimiento | recurso.historial]}}
  end
  def retirar(%__MODULE__{cantidad: actual}, cantidad) when is_number(cantidad) and cantidad > actual,
    do: {:error, :insuficiente}
  def retirar(_, _), do: {:error, :cantidad_invalida}

  def agregar(%__MODULE__{cantidad: actual} = recurso, cantidad)
      when is_number(cantidad) and cantidad > 0 do
    movimiento = %{tipo: :entrada, cantidad: cantidad, fecha: DateTime.utc_now()}
    {:ok, %{recurso | cantidad: actual + cantidad, historial: [movimiento | recurso.historial]}}
  end
  def agregar(_, _), do: {:error, :cantidad_invalida}

  def transferir(%__MODULE__{} = recurso, destino, cantidad)
      when is_binary(destino) and byte_size(destino) > 0 and is_number(cantidad) and cantidad > 0 do
    case retirar(recurso, cantidad) do
      {:ok, actualizado} ->
        movimiento = %{tipo: :transferencia, destino: destino, cantidad: cantidad, fecha: DateTime.utc_now()}
        {:ok, %{actualizado | historial: [movimiento | actualizado.historial]}}
      error -> error
    end
  end

  def transferir(_, _, _), do: {:error, :datos_invalidos}
end
