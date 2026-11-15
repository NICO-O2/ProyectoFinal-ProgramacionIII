# Notas técnicas y decisiones de diseño

- Cada dominio con estado tiene un GenServer independiente.
- `Emergencias.Application` inicia todos los servidores bajo un Supervisor `:one_for_one`.
- Las llamadas `GenServer.call/2` serializan las modificaciones de cada estado compartido.
- El inventario se modifica exclusivamente a través de `RecursosServer`, evitando cantidades negativas por carreras entre procesos.
- La asignación de una necesidad se coordina desde `NecesidadesServer`: solo se acepta si sigue pendiente y se descuenta el inventario mediante `RecursosServer`.
- La persistencia usa archivos de texto plano con términos Erlang codificados en Base64, para conservar estructuras de datos sin dependencias externas.
- Funciones recursivas propias: `Necesidad.ordenar_por_prioridad/1`, `ZonasServer.contar_sectores/1` y `contar_puntos/1` (más `contar_afectados/1` como función recursiva de agregación sobre la jerarquía).
- La contraseña se guarda como hash SHA-256, nunca en texto plano.

## Alcance que requiere integración final

Los permisos por rol están disponibles en los datos de usuario, pero deben aplicarse en una capa de comandos/interfaz antes de permitir operaciones. La transferencia de inventario debe validarse contra el modelo físico de centros de apoyo que defina el equipo. El proyecto aún necesita diagramas UML/OTP actualizados y una demostración integrada.
