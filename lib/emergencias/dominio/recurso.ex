defmodule Emergencias.Dominio.Recurso do
  @moduledoc "Lógica pura de un recurso: sin procesos, sin estado externo."

  defstruct [:codigo, :nombre, :categoria, :cantidad, :unidad, :ubicacion, historial: []]

  def nuevo(codigo, nombre, categoria, cantidad, unidad, ubicacion)
      when is_number(cantidad) and cantidad >= 0 do
    {:ok,
     %__MODULE__{
       codigo: codigo,
       nombre: nombre,
       categoria: categoria,
       cantidad: cantidad,
       unidad: unidad,
       ubicacion: ubicacion
     }}
  end

  def nuevo(_, _, _, _, _, _), do: {:error, :cantidad_invalida}

  def retirar(%__MODULE__{cantidad: actual} = recurso, pedido)
      when is_number(pedido) and pedido > 0 do
    if pedido <= actual do
      {:ok,
       %{recurso | cantidad: actual - pedido, historial: [{:salida, pedido} | recurso.historial]}}
    else
      {:error, :insuficiente}
    end
  end

  def retirar(_recurso, _pedido), do: {:error, :cantidad_invalida}

  def agregar(%__MODULE__{cantidad: actual} = recurso, ingreso)
      when is_number(ingreso) and ingreso > 0 do
    {:ok,
     %{recurso | cantidad: actual + ingreso, historial: [{:entrada, ingreso} | recurso.historial]}}
  end

  def agregar(_recurso, _ingreso), do: {:error, :cantidad_invalida}
end
