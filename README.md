
# 🧾 Instalación Syslog sin Dolores de Cabeza

![Platform](https://img.shields.io/badge/platform-Ubuntu%20Server%20%2F%20Kali-blue)
![Shell](https://img.shields.io/badge/shell-bash-informational)
![Syslog](https://img.shields.io/badge/syslog-rsyslog-success)
![Security](https://img.shields.io/badge/security-TLS%20%2F%20mTLS-orange)
![CI](https://img.shields.io/badge/CI-GitHub%20Actions-black)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

Despliegue rápido, reproducible y entendible de un sistema syslog para laboratorio, demo o preproducción.

Despliegue rápido, reproducible y entendible de un sistema syslog para laboratorio, demo o preproducción.

Este repositorio está pensado para que cualquier persona del equipo pueda:

- montar un servidor syslog en minutos
- conectar clientes sin romper nada
- entender qué está pasando
- hacer demos sin improvisar
- solucionar problemas típicos sin volverse loco

## 📚 Índice rápido

- [✨ Qué incluye](#-qué-incluye)
- [📦 Estructura del repositorio](#-estructura-del-repositorio)
- [✅ Requisitos](#-requisitos)
- [⚙️ Modos disponibles](#️-modos-disponibles)
- [🚀 Instalación recomendada](#-instalación-recomendada)
- [⚡ Despliegue rápido](#-despliegue-rápido)
- [📂 Dónde están los logs](#-dónde-están-los-logs)
- [🧾 Despliegue básico de syslog](#-despliegue-básico-de-syslog)
- [🔐 Modo TLS (seguro)](#-modo-tls-seguro)
- [🧪 DEMO PARA JEFE / CLIENTE](#-demo-para-jefe--cliente)
- [📄 Archivos importantes](#-archivos-importantes)
- [🛠️ Troubleshooting](#️-troubleshooting)
- [❓ FAQ](#-faq)
- [⚠️ Seguridad](#️-seguridad)
- [⚙️ Integración continua](#️-integración-continua)
- [📌 Recomendación práctica](#-recomendación-práctica)

---

## ✨ Qué incluye

- Configuración automática de `rsyslog`
- Modo `basic` por TCP
- Modo `tls` con TLS/mTLS
- Separación de logs locales y remotos
- Firewall con `UFW`
- Generación automática de certificados
- Export de certificados por cliente
- Scripts idempotentes para máquinas nuevas y máquinas ya tocadas
- Backups automáticos
- Informes finales
- Validación automática en GitHub Actions

---

<details open>
<summary><strong>📦 Estructura del repositorio</strong></summary>

```text
instalacion-syslog-sin-dolores-de-cabeza/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── .gitignore
├── scripts/
│   ├── setup_syslog_server_v5.sh
│   └── setup_syslog_client_v5.sh
├── docs/
│   ├── despliegue-basico.md
│   └── despliegue-tls.md
└── .github/
    └── workflows/
        ├── validate.yml
        └── test-installation.yml
```

</details>

---

<details>
<summary><strong>✅ Requisitos</strong></summary>

### Servidor

- Ubuntu Server
- acceso con sudo
- conectividad con los clientes
- systemd funcionando

### Cliente

- Kali Linux o Debian/Ubuntu
- acceso con sudo
- conectividad con el servidor

</details>

---

<details>
<summary><strong>⚙️ Modos disponibles</strong></summary>

### Servidor

- `basic` → TCP + firewall por IP
- `tls` → TCP + TLS + autenticación mutua + SAN

### Cliente

- `basic` → envío por TCP
- `tls` → envío por TCP + TLS
- `disable` → deja de enviar logs sin apagar el syslog local

</details>

---

<details open>
<summary><strong>🚀 Instalación recomendada</strong></summary>

Clona el repositorio y ejecuta los scripts directamente.

```bash
git clone https://github.com/victordanielteleco/instalacion-syslog-sin-dolores-de-cabeza.git
cd instalacion-syslog-sin-dolores-de-cabeza
chmod +x scripts/*.sh
```

</details>

---

<details open>
<summary><strong>⚡ Despliegue rápido</strong></summary>

### 🖥️ Servidor (modo basic)

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --run-test
```

### 💻 Cliente (modo basic)

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --run-test
```

### 🧪 Probar

En el cliente:

```bash
logger "PRUEBA RAPIDA"
```

En el servidor:

```bash
tail -f /var/log/remote/*/*.log
```

</details>

---

<details>
<summary><strong>📂 Dónde están los logs</strong></summary>

Los logs remotos se guardan con esta estructura:

```text
/var/log/remote/<IP>/<programa>.log
```

Ejemplo:

```text
/var/log/remote/172.16.3.10/sudo.log
```

Esto facilita mucho localizar qué equipo generó cada evento y qué servicio lo produjo.

</details>

---

<details>
<summary><strong>🧾 Despliegue básico de syslog</strong></summary>

Este modo permite enviar logs sin cifrado. Es ideal para laboratorio, pruebas rápidas o demos internas donde todavía no necesites TLS.

### 🧱 Arquitectura

```text
Cliente → Servidor syslog (TCP 10514)
```

### 🖥️ Paso 1: servidor

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --run-test
```

#### Qué hace el script del servidor

- instala rsyslog
- prepara el directorio /var/log/remote
- configura recepción TCP en el puerto 10514 por defecto
- separa logs remotos usando un ruleset
- configura logrotate
- crea backups de configuraciones previas
- restringe acceso con UFW
- genera un informe final

### 💻 Paso 2: cliente

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --run-test
```

#### Qué hace el script del cliente

- instala rsyslog si hace falta
- configura forwarding por TCP al servidor
- mantiene logs locales
- hace backup de configuraciones previas
- genera un informe final

### 🧪 Paso 3: verificación

En el cliente:

```bash
logger "TEST BASICO"
```

En el servidor:

```bash
tail -f /var/log/remote/*/*.log
```

### 📌 Cuándo usar este modo

Úsalo para:

- laboratorio
- pruebas rápidas
- demos técnicas internas

No lo uses como modo final de producción. Para eso, usa TLS.

</details>

---

<details>
<summary><strong>🔐 Modo TLS (seguro)</strong></summary>

Este modo añade cifrado y autenticación mutua. Es la opción recomendada para demos serias, preproducción y producción.

### 🧱 Arquitectura

```text
Cliente ⇄ Servidor syslog (TLS 6514)
```

### 🖥️ Servidor

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.10 \
  --server-ip 172.16.3.2 \
  --tls-clients kali01 \
  --run-test
```

#### Qué hace el servidor en TLS

- genera una CA propia
- genera certificado del servidor con SAN
- genera certificados por cliente
- configura rsyslog con TLS/mTLS
- exporta bundles por cliente
- aplica filtrado por IP en UFW
- genera informe final

### 📦 Bundles TLS generados

En el servidor:

```text
/root/syslog-client-bundles/<cliente>/
```

Contiene:

- `ca.crt`
- `client.crt`
- `client.key`

### 💻 Cliente

Copia al cliente los tres archivos del bundle correspondiente y luego ejecuta:

```bash
sudo bash scripts/setup_syslog_client_v5.sh tls \
  --server 172.16.3.2 \
  --ca ca.crt \
  --cert client.crt \
  --key client.key \
  --peer syslog.local \
  --run-test
```

### 🧪 Verificación TLS

En el cliente:

```bash
logger "TEST TLS"
```

En el servidor:

```bash
tail -f /var/log/remote/*/*.log
```

### 📌 Cuándo usar este modo

Úsalo para:

- producción
- redes sensibles
- auditoría
- entornos donde quieras control de acceso real

### 🧾 Qué añade TLS

- cifrado
- autenticación
- control de acceso más fuerte
- mejor base para cumplimiento y trazabilidad

</details>

---

<details>
<summary><strong>🧪 DEMO PARA JEFE / CLIENTE</strong></summary>

Esta es una demo rápida que suele funcionar muy bien.

### Demo básica

Arranca el servidor en basic  
Arranca el cliente en basic

En el cliente:

```bash
logger "PRUEBA DEMO"
```

En el servidor:

```bash
tail -f /var/log/remote/*/*.log
```

### Demo más potente orientada a seguridad

En el cliente, lanza un intento fallido de SSH:

```bash
ssh usuario_falso@172.16.3.2
```

Introduce una contraseña incorrecta cuando la pida.

Luego, en el servidor:

```bash
grep -R "Failed password" /var/log/remote
```

Esto demuestra muy bien la centralización de logs y la detección de actividad sospechosa.

</details>

---

<details>
<summary><strong>📄 Archivos importantes</strong></summary>

| Archivo o ruta | Descripción |
|---|---|
| `/etc/rsyslog.d/10-remote.conf` | Configuración basic del servidor |
| `/etc/rsyslog.d/10-tls.conf` | Configuración TLS del servidor |
| `/etc/rsyslog.d/20-forward.conf` | Configuración basic del cliente |
| `/etc/rsyslog.d/20-tls.conf` | Configuración TLS del cliente |
| `/etc/rsyslog-certs/` | Certificados en servidor o cliente |
| `/root/syslog_setup_backups/` | Backups automáticos |
| `/root/syslog_server_report.txt` | Informe final del servidor |
| `/root/syslog_client_report.txt` | Informe final del cliente |
| `/root/syslog-client-bundles/` | Bundles TLS exportados por cliente |

</details>

---

<details>
<summary><strong>🛠️ Troubleshooting</strong></summary>

### ❌ No llegan logs

Comprueba en el servidor:

```bash
ss -tulpn | grep 10514
sudo systemctl status rsyslog
sudo ufw status
```

Comprueba en el cliente:

```bash
sudo systemctl status rsyslog
```

Revisa también:

- IP correcta del servidor
- IP del cliente incluida en `--allowed-ips`
- conectividad entre máquinas

### ❌ TLS no funciona

Revisa:

- que `--peer` coincide con el nombre esperado del certificado del servidor
- que el cliente está usando la CA correcta
- que `client.crt` y `client.key` corresponden entre sí
- que el servidor incluye el cliente en `--tls-clients`
- que el SAN del servidor incluye el nombre o IP usados

Para inspeccionar un certificado:

```bash
openssl x509 -in client.crt -text -noout
```

### ❌ Cambié IP o nombres y TLS ya no cuadra

Esto es bastante común.

La recomendación es regenerar certificados:

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.10 \
  --server-ip NUEVA_IP \
  --tls-clients kali01 \
  --regenerate-certs
```

Después, vuelve a copiar los nuevos bundles al cliente.

### ❌ Logs mezclados o raros

Revisa si tienes configuraciones antiguas adicionales en:

```bash
ls -l /etc/rsyslog.d/
```

Estos scripts usan ruleset separado para tráfico remoto, pero una config vieja puede interferir.

### ❌ Quiero dejar de enviar logs desde el cliente

Usa:

```bash
sudo bash scripts/setup_syslog_client_v5.sh disable
```

Esto elimina el forwarding remoto, pero mantiene el syslog local del sistema.

### ❌ Quiero volver atrás

Revisa los backups en:

```text
/root/syslog_setup_backups/
```

</details>

---

<details>
<summary><strong>❓ FAQ</strong></summary>

### ¿Se pierden logs locales del cliente?

No. El cliente sigue manteniendo sus logs locales. El modo disable solo quita el envío remoto.

### ¿Puedo usar varias IPs permitidas?

Sí. Ejemplo:

```bash
--allowed-ips 172.16.3.10,172.16.3.11
```

### ¿Puedo usar varios clientes TLS?

Sí. Ejemplo:

```bash
--tls-clients kali01,ubuntu01,fw01
```

### ¿Qué pasa si rsyslog ya está instalado?

El script lo reutiliza y continúa.

### ¿Es obligatorio usar TLS?

No. Para pruebas rápidas, basic va muy bien. Para producción o demos serias, mejor tls.

### ¿Un cliente puede compartir certificado con otro?

No es recomendable. Mejor 1 cliente = 1 certificado.

### ¿Dónde están los certificados exportados?

En el servidor, dentro de:

```text
/root/syslog-client-bundles/<cliente>/
```

</details>

---

<details>
<summary><strong>⚠️ Seguridad</strong></summary>

- no subas certificados ni claves al repositorio
- restringe siempre IPs con `--allowed-ips`
- usa TLS en producción
- protege el acceso al servidor syslog
- no reutilices claves privadas entre máquinas

</details>

---

<details>
<summary><strong>⚙️ Integración continua</strong></summary>

El repositorio incluye:

- validación de scripts con `bash -n`
- análisis con `shellcheck`
- test de instalación simulada en Ubuntu 24.04

Esto ayuda a detectar errores antes de usar los scripts en laboratorio o preproducción.

</details>

---

<details open>
<summary><strong>📌 Recomendación práctica</strong></summary>

Usa este orden:

- basic para validar conectividad y flujo
- tls para endurecer el despliegue
- añadir más clientes

</details>
