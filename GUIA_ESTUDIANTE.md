# Laboratorio DevSecOps: seguridad de una API contenerizada

> Asignatura: Sistema Operativo · Duración estimada: 90 minutos ·
> Entrega: informe individual o en parejas · Entorno: Ubuntu 24.04 o Kali Linux
> con Docker

## Presentación

Este laboratorio es independiente de los anteriores. Vas a levantar AuditHub, una
API de auditoría con tres servicios en Docker Compose sobre un host Ubuntu 24.04
o Kali Linux. Un proxy nginx recibe las peticiones y las pasa a la API. Hay un
incidente de seguridad: parte de la configuración interna de la API se puede
consultar sin autenticación.

Tu trabajo es reproducir la fuga, medir qué información se expone y reunir
evidencia. Un par de comprobaciones sobre el host Ubuntu 24.04 te ayudarán a
entender de dónde sale el dato. Las pistas al final orientan el diagnóstico, pero
no contienen la corrección.

## Objetivos

Al terminar el laboratorio deberías poder:

- comprobar el estado de un stack con healthchecks;
- buscar la superficie expuesta con comprobaciones dirigidas;
- consultar una API HTTP con `curl` e interpretar su respuesta;
- leer los logs de un contenedor y relacionarlos con una petición;
- comparar el access log del proxy con el log de la API para seguir una petición;
- inspeccionar las variables de entorno efectivas de un contenedor;
- comprobar en Ubuntu 24.04 el usuario del proceso y dónde queda el log;
- distinguir entre cerrar una fuga y rotar una credencial expuesta;
- describir el impacto de un secreto filtrado;
- localizar marcas ocultas en el stack como ejercicio ofensivo controlado.

## Antes de empezar

- Trabajás sobre Ubuntu 24.04 o Kali Linux. Si te faltan Docker, Compose v2 o
  `curl`, corré una vez `sudo sh scripts/install-tools.sh` desde la carpeta del
  laboratorio.
- Necesitás alrededor de 700 MB libres para las imágenes y acceso a `docker.io`
  y `registry.npmjs.org` la primera vez.
- Trabajá sobre una copia del laboratorio. Primero reproducí, después analizá.
- Guardá las salidas completas, con el comando que las produjo.
- Los puertos publicados escuchan solo en `127.0.0.1`.

Los comandos son los mismos en Ubuntu y en Kali. El laboratorio se validó en
Ubuntu 24.04.5 y en Kali GNU/Linux Rolling, con Compose v5.8.0 en ambos.

## Flujo de trabajo sugerido

1. 10 min. Levantá el stack y guardá el estado normal: los tres servicios
   `healthy`, `/health`, `/events` y la interfaz.
2. 10 min. Buscá la superficie expuesta: enumerá lo publicado, probá rutas
   con `curl` y cruzá las respuestas con los logs de la API y del proxy.
3. 20 min. Reproducí la ruta reportada y las dos fugas: la respuesta de
   depuración, el log de arranque y el access log del proxy.
4. 15 min. Medí el alcance: entorno efectivo, credenciales por red, UID del
   proceso, ruta del log en Ubuntu y las cinco marcas.
5. 15 min. Corregí y rotá: cerrá la ruta, quitá el log con el secreto y
   rotá las credenciales expuestas.
6. 10 min. Verificá: la ruta debe dar 404, los servicios seguir vivos, los
   logs limpios y la clave vieja rechazada. Dos marcas dejan de verse.
7. 10 min. Escribí el informe con evidencia enmascarada y defendé el orden
   del análisis.

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

El proxy publica el puerto 3100 en `127.0.0.1` y reenvía todo a `api:3000`. La
API corre como usuario `node`, con el sistema de archivos de solo lectura y sin
capacidades del kernel. Ni la API ni PostgreSQL publican puertos en el host.

## Puesta en marcha

Ubicate en la carpeta del laboratorio y levantá el stack:

```bash
docker compose up -d --build
docker compose ps
```

Esperá a que los tres servicios figuren como `healthy`. El proxy es la entrada,
así que si `api` no está listo, las peticiones van a fallar aunque el proxy
esté arriba.

```bash
curl -s http://localhost:3100/health
curl -s http://localhost:3100/events
```

Guardá esas salidas como referencia de funcionamiento normal. La interfaz web
está en `http://localhost:3100`.

## Comprobación rápida de sistema operativo

Dos comandos sobre el host, Ubuntu 24.04 o Kali Linux, completan la evidencia:

```bash
docker compose exec -T api id
docker inspect audithub-api --format '{{.LogPath}}'
```

Anotá el UID del proceso y la ruta del log. Para el informe: ¿por qué la API no
corre como root y dónde queda escrita la master key aunque después borres la
ruta?

## Búsqueda dirigida de vulnerabilidades

La búsqueda no es un escaneo masivo. Primero enumerá lo que se publica, después
probá rutas y cabeceras con `curl`, y por último cruzá cada respuesta con los
logs de la API y del proxy. Con `docker compose ps` y `docker inspect` alcanza
para saber qué servicios existen y con qué entorno arrancaron.

Anotá qué miraste en cada paso. Si tenés Kali a mano, `nmap`, `ffuf` o
`gobuster` y `gitleaks` pueden ayudar, pero siguen siendo opcionales y no
forman parte de la evidencia obligatoria.

| Superficie | Qué observar | Ayuda opcional |
|---|---|---|
| Puertos publicados | qué escucha en `127.0.0.1` | `nmap` |
| Rutas HTTP | código, cabeceras y cuerpo de cada respuesta | `ffuf` o `gobuster` |
| Código y configuración | valores escritos en el repositorio | `gitleaks` |
| Imagen | etiquetas y capas del build | `trivy`, `docker-bench-security` |

## Incidente: configuración expuesta

### Síntoma

Un analista reportó que la API responde a una ruta de depuración sin pedir
credenciales y que esa respuesta contiene datos internos. También aparece una
línea sospechosa en los logs al iniciar el servicio.

### Reproducción

Consultá la ruta reportada:

```bash
curl -i http://localhost:3100/debug/config
```

Para leerla con más comodidad:

```bash
curl -s http://localhost:3100/debug/config | python3 -m json.tool
```

Revisá los logs de la API:

```bash
docker compose logs api --tail 30
```

Después mirá el access log del proxy. Ahí debería aparecer la misma petición con
su hora, ruta y código de respuesta:

```bash
docker compose logs proxy --tail 20
```

Compará con la configuración efectiva que Docker inyectó en el contenedor:

```bash
docker inspect audithub-api --format '{{range .Config.Env}}{{println .}}{{end}}'
```

Comprobá que las credenciales que aparecen son utilizables dentro del stack, por
red y no por el socket local:

```bash
docker compose exec -T -e PGPASSWORD=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2) db \
  psql -h db -U audit -d audithub -c '\dt'
```

### Qué registrar

- código HTTP y cuerpo completo de la respuesta de depuración;
- lista de variables sensibles que se pueden leer, sin copiar los valores al
  informe;
- línea del log que contiene la master key, con el valor enmascarado;
- línea del access log del proxy para la misma petición, con hora, ruta y código;
- configuración efectiva del contenedor;
- UID del proceso API y ruta del log en el host;
- consecuencia de que esos valores sean reales;
- hora y servicio en que se produce cada hallazgo.

Usá esta tabla como diario de hallazgos mientras avanzás:

| Hora | Servicio | Comando | Salida enmascarada | Qué demuestra |
|---|---|---|---|---|
|  |  |  |  |  |

No pegues el JSON completo de la respuesta de depuración en el informe: alcanza
con la lista de nombres de variables sensibles.

### Preguntas para la defensa

- ¿Qué información revela la respuesta y por qué es sensible?
- ¿La ruta requiere autenticación o algún encabezado especial?
- ¿Qué aporta el access log del proxy si la respuesta la generó la API?
- ¿Qué diferencia hay entre eliminar la ruta y rotar las credenciales?
- ¿Qué pasa con el secreto que ya quedó en los logs?
- ¿En qué etapa del ciclo de vida del software se debió detectar esto?

### Criterio de aceptación

La configuración interna deja de ser consultable, los secretos no aparecen en
los logs y las credenciales que se expusieron dejan de ser válidas. El proxy
sigue sirviendo la interfaz, `/health` y `/events`, y registra la ruta cerrada con
código 404. En el informe explicá qué hiciste en cada uno de esos puntos y cómo
lo verificaste.

## Entregable

Un informe técnico en Markdown o PDF con esta estructura:

1. Portada con nombre, fecha y versión del laboratorio.
2. Síntoma, evidencia (comando y salida con valores enmascarados), alcance del
   incidente y verificación posterior.
3. Una sección sobre qué controles automáticos habría que agregar antes del
   despliegue para detectar este tipo de fallo. Justificá cada uno con lo que
   observaste.
4. Un párrafo sobre el orden en que analizaste la fuga.

Plantilla mínima para el informe:

```markdown
# Informe: exposición de secretos en AuditHub

Nombre:
Fecha:

## 1. Síntoma
## 2. Evidencia
| Comando | Salida con valores enmascarados | Hallazgo |
|---|---|---|
## 3. Alcance e impacto
## 4. Corrección y rotación
## 5. Verificación posterior
## 6. Controles de pipeline propuestos
## 7. Orden del análisis
```

No incluyas secretos reales ni credenciales de otros entornos. Enmascar los
valores que encontraste en este laboratorio.

Tabla mínima de evidencias:

| Hallazgo | Evidencia indispensable | Verificación |
|---|---|---|
| Ruta de depuración | respuesta HTTP y lista de variables expuestas | la ruta deja de responder con datos internos |
| Petición en el proxy | línea del access log con hora, ruta y código | la misma ruta aparece cerrada con 404 |
| Secreto en logs | línea del log con el valor enmascarado | no aparece en los logs nuevos |
| Credenciales válidas | consulta a la base por red (`-h db`) con esos valores | las credenciales viejas son rechazadas |
| Proceso y log en el host | UID del proceso y ruta del log | se explica dónde quedó escrito el secreto |

## Pistas

Estas pistas orientan el análisis. No incluyen los pasos de corrección: la
solución y su justificación quedan a tu cargo.

- Una ruta pensada para depurar no debería comportarse igual en producción.
- El proxy registra la petición aunque la respuesta la produzca otro contenedor.
- `docker inspect` muestra lo que el contenedor recibió al arrancar.
- La rotación de credenciales y el borrado de una ruta resuelven problemas
  distintos.
- La rotación de logs limita el tamaño de los archivos, no su contenido previo.
- Lo que `process.env` expone es el entorno con el que el kernel arrancó el proceso.
- Los controles automáticos se pueden ejecutar antes del despliegue, no solo
  después del incidente.

## Cinco marcas para comprobar el recorrido

En el stack hay cinco cadenas con formato `FLAG{...}`. No están todas en el
mismo lugar y dos dejan de verse cuando se aplica la corrección. No hay una lista
de ubicaciones: cada pista apunta a una superficie que ya estuviste mirando.

Anotá en el informe las que encuentres, el comando que usaste y una frase sobre
qué demuestra cada una. No copies secretos reales ni valores de otros entornos.

| Marca | Pista |
|---|---|
| 1 | Viaja en la misma respuesta que motivó el reporte del analista. |
| 2 | Se escribe antes de que llegue la primera petición. |
| 3 | La dejó quien configuró la entrada del stack, no la API. |
| 4 | Aparece mezclada con actividad que la API muestra como normal. |
| 5 | No está en el proceso en marcha: pertenece a la imagen que lo creó. |

Recordatorio de Kali, solo como ayuda: para la pista 1 puede servir un
descubridor de rutas como `ffuf` o `gobuster`; para la pista 2, `gitleaks` sobre
el código; para la pista 5, `trivy` o `docker-bench-security`. Siguen siendo
opcionales y no probadas en el aula. Ninguna reemplaza el análisis.

Si al verificar la corrección dejás de ver dos marcas, es el resultado esperado.

## Herramientas de Kali Linux (opcional)

Es una extensión fuera de la entrega. El arranque del laboratorio y la instalación
de estas herramientas se probaron en Ubuntu 24.04 y en Kali GNU/Linux Rolling con
`sudo sh scripts/install-tools.sh`, que no reinstala lo que ya está presente.
Siguen siendo opcionales: podés omitirlas sin consecuencias y la evidencia
obligatoria no depende de ellas.

| Herramienta | Uso propuesto | Observación buscada |
|---|---|---|
| `nmap` | `nmap -sV -p- 127.0.0.1` | puertos abiertos en el host |
| `ffuf` / `gobuster` | `ffuf -u http://127.0.0.1:3100/FUZZ -w /usr/share/wordlists/dirb/common.txt` | rutas descubiertas |
| `gitleaks` | `gitleaks detect --source . --verbose` | secretos en el repositorio |
| `trivy` | `trivy image audithub-api` | vulnerabilidades de la imagen |
| `docker-bench-security` | ejecutar el script en el host | endurecimiento del runtime |
| `lynis` | `lynis audit system` | endurecimiento del SO anfitrión |

Si las usás, aclaralo en el informe y adjuntá la salida como evidencia adicional.
No reemplazan a `curl`, `docker inspect` ni al análisis del impacto.

## Evaluación

| Criterio | Puntos |
|---|---|
| Reproducción del incidente con evidencia clara | 30 |
| Medición correcta del alcance y del impacto | 30 |
| Corrección y rotación verificadas | 25 |
| Explicación y propuestas de control | 15 |

## Problemas frecuentes

- `docker: 'compose' is not a docker command`: falta Compose v2; corré
  `sudo sh scripts/install-tools.sh`.
- `apt-get update` falla en Kali con `download.docker.com/linux/debian ...
  kali-rolling 404`: desactivá ese repo con
  `sudo mv /etc/apt/sources.list.d/docker.sources{,.disabled}` y volvé a correr
  el script.
- `docker compose version` muestra otra versión: revisá
  `~/.docker/cli-plugins/docker-compose`, que puede tener prioridad.
- `port is already allocated`: otro proceso ocupa el puerto 3100. Revisá con
  `docker compose ps` antes de levantar.
- Un servicio no llega a `healthy`: esperá unos segundos y volvé a consultar
  `docker compose ps`, los healthchecks tienen un periodo de gracia.
- El proxy devuelve 502: `api` todavía no está lista. Esperá a que figure como
  `healthy` y volvé a probar.
- `psql` conecta aunque la clave sea incorrecta: el socket local usa `trust`.
  Usá `-h db` para probar la contraseña por red.

## Limpieza

Al terminar, apagá el stack y borrá sus volúmenes:

```bash
docker compose down -v
```

Eso elimina la base, el volumen y la red del laboratorio. Los archivos del
proyecto no se modifican.
