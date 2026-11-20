# AuditHub · Laboratorio DevSecOps

> Asignatura: Sistema Operativo, módulo DevSecOps · Duración estimada: 90 minutos ·
> Entrega: informe individual o en parejas · Entorno: Ubuntu 24.04 o Kali Linux con
> Docker Engine y Compose v2 · Nivel: intermedio

AuditHub es una API de auditoría con interfaz web, PostgreSQL 15 y un proxy
inverso nginx, todo en Docker Compose. El laboratorio parte de un incidente:
parte de la configuración interna de la API se puede consultar sin
autenticación. Hay un defecto deliberado en el stack y el objetivo es
reproducirlo, medir su alcance, documentarlo con evidencia y proponer una
corrección.

**Este repositorio conserva el estado original del laboratorio, con el defecto
intacto.** La corrección y su justificación se entregan por separado. La guía
de trabajo está en [`GUIA_ESTUDIANTE.md`](GUIA_ESTUDIANTE.md).

> Las credenciales de este laboratorio son fijas y de uso exclusivo del aula.
> No las reutilices fuera de ella ni publiques el puerto en una red abierta.
> `MASTER_KEY` es un valor ficticio propio del laboratorio, no una credencial
> de ningún proveedor.

## Arquitectura

```
navegador / curl --HTTP:3100--> proxy (nginx)
                                  |
                                  +-- HTTP:3000 --> api (Express)
                                  |                  |-- SQL --> db:5432 (red interna)
                                  |                  `-- logs -> json-file con rotación
                                  `-- access.log -> json-file con rotación

db:5432  base audithub, tabla events creada por initdb.sql
```

## Estructura

```
devsecops/
├── docker-compose.yml   # servicios, red, healthchecks y endurecimiento
├── .env                 # credenciales y clave maestra del laboratorio
├── initdb.sql           # esquema y datos iniciales
├── proxy/
│   └── default.conf     # virtual host del proxy inverso
├── README.md            # este documento
├── GUIA_ESTUDIANTE.md   # guía de trabajo, sin corrección
└── app/
    ├── .dockerignore
    ├── Dockerfile       # Node 22, usuario node, npm ci
    ├── package.json
    ├── package-lock.json
    ├── public/          # interfaz web
    │   ├── app.js
    │   ├── favicon.svg
    │   ├── index.html
    │   └── styles.css
    └── server.js        # API de eventos y estado del servicio
```

## Requisitos

- Host Ubuntu 24.04 o Kali Linux con Docker Engine y Compose v2 (`docker compose`)
- `curl`
- ~700 MB libres para las imágenes

Los comandos son los mismos en Ubuntu y en Kali. La validación registrada se
hizo en Ubuntu 24.04; en Kali no se ejecutó el laboratorio.

## Servicios

| Servicio | Imagen | Función | Acceso |
|---|---|---|---|
| `proxy` | `nginx:1.27-alpine` | entrada HTTP y access log | `http://localhost:3100` |
| `api` | build local con Node.js | interfaz web y API de eventos | solo desde la red del stack |
| `db` | `postgres:15-alpine` | base de datos de eventos | solo desde la red del stack |

Rutas de uso normal de la API:

| Ruta | Método | Función |
|---|---|---|
| `/` | GET | interfaz web |
| `/health` | GET | estado del servicio |
| `/events` | GET | últimos eventos registrados |

El proxy publica el puerto 3100 solo en `127.0.0.1` y reenvía todo a
`api:3000`. Ni la API ni PostgreSQL publican puertos en el host. La API corre
como usuario `node`, con rootfs de solo lectura, sin capacidades del kernel y
con `/tmp` como tmpfs.

## Puesta en marcha

```bash
cd devsecops
docker compose up -d --build
docker compose ps
```

Esperá a que `audithub-db`, `audithub-api` y `audithub-proxy` figuren como
`healthy`. Los datos iniciales se crean una sola vez, cuando PostgreSQL
inicializa el volumen.

```bash
curl -s http://localhost:3100/health
curl -s http://localhost:3100/events
```

La interfaz web queda en `http://localhost:3100` y muestra los eventos de la
tabla `events`. Guardá esas salidas como referencia de funcionamiento normal.

## Trabajo a realizar

Seguí [`GUIA_ESTUDIANTE.md`](GUIA_ESTUDIANTE.md). El recorrido es dirigido:
primero se enumera lo publicado, después se prueban rutas con `curl` y se
cruzan las respuestas con los logs de la API y del proxy, y por último se
comprueba dentro del stack qué quedó expuesto. Cada paso debe apoyarse en una
salida guardada, no solo en una lista de herramientas.

Dos comprobaciones sobre el host ayudan a explicar de dónde sale el dato:

```bash
docker compose exec -T api id
docker inspect audithub-api --format '{{.LogPath}}'
```

### Herramientas de Kali Linux (opcional)

`nmap`, `ffuf`/`gobuster`, `gitleaks`, `trivy`, `docker-bench-security`, `lynis`
y `netcat` pueden ayudar en la fase de búsqueda, pero **no forman parte de la
evidencia obligatoria** y no fueron probadas en el aula. La evidencia
indispensable sale de `curl`, `docker compose` y `docker inspect`. Un escáner
encuentra rutas; no determina si lo devuelto es válido ni qué hay que rotar.

### Marcas del ejercicio

En el stack hay cinco cadenas con formato `FLAG{...}`. No están todas en el
mismo lugar y dos dejan de verse cuando se aplica la corrección. La guía del
estudiante da una pista por cada una. Anotá las que encuentres, el comando
usado y una frase sobre qué demuestra cada una. No son secretos reales.

## Entrega

Informe técnico en Markdown o PDF con portada, síntoma, tabla de evidencia
(comando + salida con valores **enmascarados** + hallazgo), alcance e impacto,
corrección y rotación, verificación posterior, controles de pipeline propuestos
y orden del análisis. No incluyas secretos reales ni credenciales de otros
entornos. El formato detallado y el criterio de evaluación están en la guía.

## Problemas frecuentes

- `docker: 'compose' is not a docker command`: falta Compose v2.
- `port is already allocated`: otro proceso ocupa el puerto 3100.
- Un servicio no llega a `healthy`: esperá unos segundos; los healthchecks tienen
  periodo de gracia.
- El proxy devuelve 502: `api` todavía no está lista.
- `psql` conecta aunque la clave sea incorrecta: el socket local usa `trust`.
  Usá `-h db` para probar la contraseña por red.

## Limpieza

```bash
docker compose down -v
```

Eso elimina la base, el volumen y la red del laboratorio. Los archivos del
proyecto no se modifican.
