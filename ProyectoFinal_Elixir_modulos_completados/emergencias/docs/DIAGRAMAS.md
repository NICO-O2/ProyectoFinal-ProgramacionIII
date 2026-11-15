# Diagramas iniciales del sistema

Estos diagramas describen la arquitectura implementada en `lib/`. Deben revisarse si el equipo modifica los módulos.

## Arquitectura de módulos

```mermaid
flowchart TD
  APP[Emergencias.Application] --> SUP[Emergencias.Supervisor]
  SUP --> US[UsuariosServer]
  SUP --> ZS[ZonasServer]
  SUP --> NS[NecesidadesServer]
  SUP --> RS[RecursosServer]
  SUP --> PS[PersonasServer]
  SUP --> MS[MascotasServer]
  SUP --> AS[AlberguesServer]
  NS --> RS
  SEC[Emergencias.Seguridad] --> US
  SEC --> NS
  SEC --> ZS
  SEC --> RS
  SEC --> PS
  SEC --> MS
  SEC --> AS
  US --> PER[Persistencia]
  ZS --> PER
  NS --> PER
  RS --> PER
  PS --> PER
  MS --> PER
  AS --> PER
```

## Modelo de datos conceptual

```mermaid
erDiagram
  USUARIO {
    string username PK
    string password_hash
    string tipo
    string zona
  }
  ZONA {
    string codigo PK
    string nombre
    string nivel
    int afectados
  }
  SECTOR {
    string codigo PK
    string nombre
    string nivel
    int afectados
  }
  PUNTO_ATENCION {
    string codigo PK
    string nombre
    int afectados
  }
  NECESIDAD {
    string id PK
    string tipo
    float cantidad
    string prioridad
    string estado
    string zona
  }
  RECURSO {
    string codigo PK
    string nombre
    string categoria
    float cantidad
    string unidad
    string ubicacion
  }
  PERSONA {
    string documento PK
    string nombre
    int edad
    string estado
    string zona
  }
  MENSAJE {
    string id PK
    string remitente
    string destinatario
    string contenido
    string estado
  }
  MASCOTA {
    string id PK
    string tipo_reporte
    string especie
    string color
    string tamano
    string estado
  }
  ALBERGUE {
    string codigo PK
    string nombre
    int capacidad
    int ocupacion
    string zona
  }
  ZONA ||--o{ SECTOR : contiene
  SECTOR ||--o{ PUNTO_ATENCION : contiene
  ZONA ||--o{ NECESIDAD : registra
  ZONA ||--o{ PERSONA : ubica
  PERSONA ||--o{ MENSAJE : recibe
  ZONA ||--o{ ALBERGUE : tiene
  NECESIDAD }o--o{ RECURSO : requiere
```

## Secuencia de asignación de recursos

```mermaid
sequenceDiagram
  actor Usuario
  participant N as NecesidadesServer
  participant R as RecursosServer
  participant P as Persistencia
  Usuario->>N: asignar_recurso(id, codigo, cantidad)
  N->>N: comprobar que la necesidad esté pendiente
  N->>R: consultar(codigo)
  R-->>N: recurso y categoría
  N->>N: validar categoría y cantidad exacta
  N->>R: retirar(codigo, cantidad)
  R->>R: validar inventario y actualizar estado
  R->>P: guardar inventario
  R-->>N: retiro exitoso
  N->>N: cambiar estado a asignada
  N->>P: guardar necesidad
  N-->>Usuario: asignación confirmada
```

## Árbol OTP

```mermaid
flowchart TD
  A[Emergencias.Application] --> S[Emergencias.Supervisor<br/>strategy: one_for_one]
  S --> U[UsuariosServer]
  S --> Z[ZonasServer]
  S --> N[NecesidadesServer]
  S --> R[RecursosServer]
  S --> P[PersonasServer]
  S --> M[MascotasServer]
  S --> AL[AlberguesServer]
```
