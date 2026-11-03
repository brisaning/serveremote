# serveremote — servidor de encuentro (rendezvous) + relay de anyremote

Servidor **`anyremote-rdv-v1`** del proyecto [anyremote](https://github.com/brisaning/anyremote)
(diseño D-04 / C-17, `specs/02` §10 de ese repo): permite conectar dos
equipos de anyremote **a través de internet** aunque estén detrás de NAT y sin
reenvío de puertos.

| Función | Descripción |
|---|---|
| **Registro** | El anfitrión (modo «Escuchar») registra su `ID + clave pública` **firmados** (imposible reclamar un ID ajeno: el ID se deriva de la clave) con su puerto de escucha; el servidor recuerda la **IP observada**. Keepalive `hb` cada 30 s. |
| **Resolución** | El visor consulta «¿dónde está este ID?» → recibe `ip:puerto` + un **ticket** de relay. Throttling por IP. |
| **Relay** | Si la conexión directa no llega (sin reenvío en el router), ambos extremos se conectan al servidor con el ticket y este enlaza una **tubería ciega**: la sesión es TLS/QUIC de extremo a extremo — **el servidor solo transporta cifrado**. |

- **Estado**: en memoria y sin volumen: tras un reinicio los hosts vuelven a
  registrarse solos en ≤30 s.
- **Límites por defecto**:60 parejas relay simultáneas (4 h máx. por par),
  tickets de60 s y usables una vez,30 registros/min y60 resoluciones/min por IP
  (`--max-pairs` ajusta el cupo).

## Construir la imagen Docker

```bash
git clone https://github.com/brisaning/serveremote.git
cd serveremote
docker build -t serveremote:latest .
```

## Desplegar (VPS)

```bash
docker run -d --name serveremote \
  -p 21120:21120/tcp \
  --restart unless-stopped \
  serveremote:latest
```

- **Firewall**: solo **TCP 21120** (registro, resolución y relay comparten
  puerto).
- Logs: `docker logs -f serveremote` (mensaje de arranque con el puerto).
- Sin volúmenes (estado efímero por diseño).

Con systemd (opcional, para arranque automático del daemon de Docker):

```ini
# /etc/systemd/system/serveremote.service
[Unit]
Description=serveremote (anyremote rendezvous + relay)
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker start -a serveremote
ExecStop=/usr/bin/docker stop -t 10 serveremote

[Install]
WantedBy=multi-user.target
```

## Configurar los clientes anyremote

En la app de anyremote, en el campo **«servidor de encuentro (ip:puerto)»**
poner `<ip-del-vps>:21120` (en los DOS equipos), o en el CLI:
`anyremoted listen|connect --rdv <ip-del-vps>:21120` — también vale el
fichero `rdv` (una línea con `ip:puerto`) en el directorio de configuración.

Luego: en el anfitrión «Escuchar (red)» (su registro debe verse como
`rdv: registrado en …`) y desde el visor **conectar por ID**. Sin reenvío de
puertos la sesión irá por relay (`relay_fallback` en el visor); con TCP+UDP
21118 reenviados, conexión directa.

## Compilar sin Docker

```bash
cargo build --release            # → target/release/serveremote
./target/release/serveremote --bind 0.0.0.0:21120
```

## Notas

- **`src/identity.rs` es copia verbatim** de `core/identity` de anyremote: el
  transcript de firma debe ser byte-idéntico al de los clientes. Si cambia la
  identidad allí, sincronizar aquí.
- Consumidores: anyremote usa este paquete como dependencia git con alias
  (`anyremote-rendezvous = { package = "serveremote", git = … }`), así que su
  código no distingue el origen.
- Licencia: Apache-2.0 (misma que anyremote).
