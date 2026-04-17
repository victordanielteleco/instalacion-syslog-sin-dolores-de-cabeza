# 🧾 Instalación Syslog sin Dolores de Cabeza

![Platform](https://img.shields.io/badge/platform-Ubuntu%20Server%20%2F%20Kali-blue)
![Shell](https://img.shields.io/badge/shell-bash-informational)
![Syslog](https://img.shields.io/badge/syslog-rsyslog-success)
![Security](https://img.shields.io/badge/security-TLS%20%2F%20mTLS-orange)
![CI](https://img.shields.io/badge/CI-GitHub%20Actions-black)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

Despliegue rápido, reproducible y entendible de un sistema syslog para laboratorio, demo o preproducción.

Este repositorio está pensado para que cualquier persona del equipo pueda:

- montar un servidor syslog en minutos
- conectar clientes sin romper nada
- entender qué está pasando
- hacer demos sin improvisar
- solucionar problemas típicos sin volverse loco

## 📚 Índice rápido

- [✨ Qué incluye](#que-incluye)
- [📦 Estructura del repositorio](#estructura-del-repositorio)
- [✅ Requisitos](#requisitos)
- [⚙️ Modos disponibles](#modos-disponibles)
- [🚀 Instalación recomendada](#instalacion-recomendada)
- [🔔 Aviso sobre almacenamiento de logs](#aviso-sobre-almacenamiento-de-logs)
- [🔑 Habilitar SSH en la VM](#habilitar-ssh-en-la-vm)
- [💽 Preparar disco de logs en Ubuntu Server](#preparar-disco-de-logs-en-ubuntu-server)
- [⚡ Despliegue rápido](#despliegue-rapido)
- [📂 Dónde están los logs](#donde-estan-los-logs)
- [🧾 Despliegue básico de syslog](#despliegue-basico-de-syslog)
- [🔐 Modo TLS (seguro)](#modo-tls-seguro)
- [🧪 DEMO](#demo)
- [📄 Archivos importantes](#archivos-importantes)
- [🛠️ Troubleshooting](#troubleshooting)
- [❓ FAQ](#faq)
- [⚠️ Seguridad](#seguridad)
- [⚙️ Integración continua](#integracion-continua)
- [📌 Recomendación práctica](#recomendacion-practica)

---

<a id="que-incluye"></a>
## ✨ Qué incluye

- Configuración automática de `rsyslog`
- Modo `basic` en servidor con:
  - `udp`
  - `tcp`
  - `both`
- Modo `basic` en cliente con:
  - `udp`
  - `tcp`
- Modo `tls` con TLS/mTLS
- Separación de logs locales y remotos
- Firewall con `UFW`
- Generación automática de certificados
- Export de certificados por cliente
- Scripts idempotentes para máquinas nuevas y máquinas ya tocadas
- Backups automáticos
- Informes finales
- Validación automática en GitHub Actions
- Recomendación para administrar la VM por SSH
- Guía para preparar un segundo disco para logs en Ubuntu Server

---

<a id="estructura-del-repositorio"></a>
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

<a id="requisitos"></a>
<details>
<summary><strong>✅ Requisitos</strong></summary>

### Servidor

- Ubuntu Server
- acceso con sudo
- conectividad con los clientes
- systemd funcionando
- segundo disco recomendado para guardar logs remotos
- acceso inicial por consola o posibilidad de habilitar SSH

### Cliente

- Kali Linux o Debian/Ubuntu
- acceso con sudo
- conectividad con el servidor

</details>

---

<a id="modos-disponibles"></a>
<details>
<summary><strong>⚙️ Modos disponibles</strong></summary>

### Servidor

#### `basic`
Recepción syslog sin TLS.

Permite elegir:

- `udp`
- `tcp`
- `both`

Y además:

- puerto por defecto si no indicas nada: `10514`
- si no indicas `--protocol` ni `--port`, se usa `udp` en `10514`
- si indicas `--protocol` pero no puerto, se usa `10514`
- si usas `both`, puedes:
  - usar el mismo puerto para ambos con `--port`
  - o usar puertos distintos con `--tcp-port` y `--udp-port`

#### `tls`
Recepción por TCP + TLS/mTLS + certificados.

- puerto por defecto: `6514`

### Cliente

#### `basic`
Reenvío sin TLS.

Permite elegir:

- `udp`
- `tcp`

Y además:

- puerto por defecto si no indicas nada: `10514`
- si no indicas `--protocol` ni `--port`, se usa `udp` en `10514`
- si indicas `--protocol` pero no puerto, se usa `10514`

#### `tls`
Reenvío por TCP + TLS.

- puerto por defecto: `6514`

#### `disable`
Elimina el reenvío remoto sin apagar el syslog local.

</details>

---

<a id="instalacion-recomendada"></a>
<details open>
<summary><strong>🚀 Instalación recomendada</strong></summary>

Orden recomendado para dejar la VM bien preparada:

1. instala Ubuntu Server en el disco del sistema
2. habilita SSH para administrar la VM cómodamente
3. prepara y monta el disco de logs en `/var/log/remote`
4. clona el repositorio
5. ejecuta los scripts

```bash
git clone https://github.com/victordanielteleco/instalacion-syslog-sin-dolores-de-cabeza.git
cd instalacion-syslog-sin-dolores-de-cabeza
chmod +x scripts/*.sh
```

> Recomendación práctica: en el servidor, no ejecutes el script hasta haber dejado listo el disco de logs si quieres que los logs remotos vayan al disco secundario desde el primer momento.

</details>

---

<a id="aviso-sobre-almacenamiento-de-logs"></a>
<details open>
<summary><strong>🔔 Aviso sobre almacenamiento de logs</strong></summary>

> **Importante**
>
> El script está preparado para usar un disco aparte, pero solo indirectamente:
>
> - no monta el disco
> - no lo detecta
> - no comprueba que sea un mountpoint independiente
>
> Simplemente escribe en:
>
> ```text
> /var/log/remote
> ```

### Qué significa esto en la práctica

- si montas un segundo disco en `/var/log/remote`, los logs remotos se guardarán en ese disco
- si no montas nada ahí, los logs se guardarán en el disco del sistema
- si ejecutas el script antes de montar el disco, puede empezar a escribir en el disco del sistema

### Recomendación

Para una VM bien montada:

- instala Ubuntu Server en el disco del sistema
- habilita SSH
- prepara el segundo disco
- móntalo en `/var/log/remote`
- y **después** ejecuta `setup_syslog_server_v5.sh`

</details>

---

<a id="habilitar-ssh-en-la-vm"></a>
<details open>
<summary><strong>🔑 Habilitar SSH en la VM</strong></summary>

Se recomienda habilitar SSH justo después de terminar la instalación base de Ubuntu Server. Así puedes seguir la configuración cómodamente desde tu equipo y no depender de la consola de Proxmox para cada ajuste.

### 1. Instalar OpenSSH Server

```bash
sudo apt update
sudo apt install openssh-server -y
```

#### Qué hace cada comando

- `sudo` → ejecuta el comando como administrador
- `apt` → gestor de paquetes de Ubuntu
- `update` → actualiza la lista de paquetes disponibles
- `install` → instala el paquete indicado
- `openssh-server` → servicio SSH del sistema
- `-y` → acepta automáticamente la confirmación

### 2. Habilitar y arrancar SSH

```bash
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

#### Qué hace cada comando y opción

- `systemctl` → gestiona servicios con systemd
- `enable` → hace que el servicio arranque automáticamente al iniciar la VM
- `--now` → además de habilitarlo, lo arranca en este momento
- `status` → muestra el estado actual del servicio

### 3. Ver la IP de la VM

```bash
hostname -I
```

#### Qué hace

- `hostname` → muestra información del sistema
- `-I` → enseña las IPs asignadas al equipo

### 4. Conectarte desde tu equipo

```bash
ssh usuario@IP_DE_LA_VM
```

#### Qué hace

- `ssh` → abre una conexión remota segura
- `usuario` → usuario de Ubuntu Server
- `IP_DE_LA_VM` → dirección IP de la máquina virtual

### 5. Si usas UFW manualmente antes del script

```bash
sudo ufw allow OpenSSH
```

#### Qué hace

- `ufw` → firewall sencillo de Ubuntu
- `allow` → permite tráfico entrante
- `OpenSSH` → perfil predefinido para SSH

> Recomendación: haz el resto del montaje y despliegue del servidor por SSH. Es más cómodo para copiar comandos, editar `/etc/fstab` y verificar el sistema.

</details>

---

<a id="preparar-disco-de-logs-en-ubuntu-server"></a>
<details open>
<summary><strong>💽 Preparar disco de logs en Ubuntu Server</strong></summary>

Esta sección deja listo el segundo disco de la VM para guardar los logs remotos en:

```text
/var/log/remote
```

> En los ejemplos usaré `/dev/sdb`.  
> Si tu segundo disco aparece como `/dev/vdb` o similar, cambia el nombre en los comandos.

### 1. Identificar el disco de logs

```bash
lsblk
```

#### Qué hace

- `lsblk` → muestra discos y particiones en formato árbol

Busca algo como esto:

- `/dev/sda` o `/dev/vda` → disco del sistema
- `/dev/sdb` o `/dev/vdb` → disco de logs

### 2. Crear una partición en el segundo disco

```bash
sudo fdisk /dev/sdb
```

#### Qué hace

- `fdisk` → herramienta para crear y modificar particiones
- `/dev/sdb` → disco sobre el que vas a trabajar

#### Dentro de `fdisk`

Pulsa estas teclas en este orden:

- `n` → nueva partición
- `p` → primaria
- `1` → partición número 1
- Enter → primer sector por defecto
- Enter → último sector por defecto
- `w` → guardar y salir

Después comprueba el resultado:

```bash
lsblk
```

Ahora deberías ver algo como:

```text
/dev/sdb1
```

### 3. Formatear la partición en ext4

```bash
sudo mkfs.ext4 /dev/sdb1
```

#### Qué hace

- `mkfs.ext4` → crea un sistema de archivos ext4
- `/dev/sdb1` → partición del disco de logs

> Este paso borra el contenido previo de esa partición.

### 4. Crear el punto de montaje

```bash
sudo mkdir -p /var/log/remote
```

#### Qué hace

- `mkdir` → crea directorios
- `-p` → crea directorios padre si faltan y no falla si ya existen

### 5. Obtener el UUID de la partición

```bash
sudo blkid /dev/sdb1
```

#### Qué hace

- `blkid` → muestra identificadores de discos y particiones
- `/dev/sdb1` → partición que quieres identificar

Verás algo parecido a:

```text
/dev/sdb1: UUID="1234-5678-ABCD" TYPE="ext4"
```

Guarda ese UUID.

### 6. Configurar el montaje automático en `/etc/fstab`

```bash
sudo nano /etc/fstab
```

Añade al final una línea como esta:

```fstab
UUID=1234-5678-ABCD /var/log/remote ext4 defaults,nofail 0 2
```

Cambiando `1234-5678-ABCD` por tu UUID real.

#### Qué significa cada campo

- `UUID=...` → identifica la partición concreta
- `/var/log/remote` → punto de montaje
- `ext4` → tipo de sistema de archivos
- `defaults,nofail`
  - `defaults` → opciones de montaje estándar
  - `nofail` → el sistema puede seguir arrancando aunque falle ese disco
- `0` → no usar `dump`
- `2` → orden de chequeo del sistema de archivos al arrancar

### 7. Montar el disco sin reiniciar

```bash
sudo mount -a
```

#### Qué hace

- `mount` → monta sistemas de archivos
- `-a` → monta todo lo definido en `/etc/fstab`

### 8. Verificar que ha quedado bien montado

```bash
df -h
mountpoint /var/log/remote
```

#### Qué hace cada comando

- `df` → muestra uso de espacio en disco
- `-h` → formato legible para personas
- `mountpoint` → comprueba si una ruta es un punto de montaje real

Si todo está bien, `/var/log/remote` debería aparecer usando el tamaño del segundo disco.

### 9. Solo después ejecuta el script del servidor

Modo `basic`:

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --run-test
```

Modo `tls`:

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.10 \
  --server-ip 172.16.3.2 \
  --tls-clients kali01 \
  --run-test
```

### 10. Cómo ampliar el disco más adelante

#### En Proxmox

Amplía el disco desde **Hardware → Disk → Resize**

o por consola del host:

```bash
qm resize 101 scsi1 +20G
```

#### Dentro de Ubuntu Server

```bash
lsblk
sudo growpart /dev/sdb 1
sudo resize2fs /dev/sdb1
```

#### Qué hace cada comando

- `growpart` → amplía la partición para ocupar el nuevo espacio disponible
- `/dev/sdb` → disco
- `1` → partición número 1
- `resize2fs` → amplía el sistema de archivos ext4 para usar el espacio nuevo

</details>

---

<a id="despliegue-rapido"></a>
<details open>
<summary><strong>⚡ Despliegue rápido</strong></summary>

### 🖥️ Servidor (modo basic, default)

Si no indicas nada más:

- protocolo por defecto: `udp`
- puerto por defecto: `10514`

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --run-test
```

### 💻 Cliente (modo basic, default)

Si no indicas nada más:

- protocolo por defecto: `udp`
- puerto por defecto: `10514`

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

<a id="donde-estan-los-logs"></a>
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

### Importante

- si `/var/log/remote` está montado sobre un segundo disco, los logs irán a ese disco
- si `/var/log/remote` es solo una carpeta normal, los logs irán al disco del sistema

</details>

---

<a id="despliegue-basico-de-syslog"></a>
<details open>
<summary><strong>🧾 Despliegue básico de syslog</strong></summary>

Este modo permite enviar logs sin cifrado. Es ideal para laboratorio, pruebas rápidas o demos internas donde todavía no necesites TLS.

### 🧱 Arquitectura

#### Opción 1: UDP por defecto

```text
Cliente → Servidor syslog (UDP 10514)
```

#### Opción 2: TCP

```text
Cliente → Servidor syslog (TCP 10514)
```

#### Opción 3: Servidor escuchando en ambos

```text
Cliente → Servidor syslog (UDP y TCP)
```

> El cliente elige un único protocolo por ejecución (`udp` o `tcp`).  
> El servidor puede escuchar en `udp`, en `tcp` o en `both`.

### 🖥️ Paso 1: preparar la VM del servidor

Antes de ejecutar el script:

- habilita SSH
- monta el disco de logs en `/var/log/remote`

### 🖥️ Paso 2: servidor

#### Caso A: default absoluto

Si no indicas `--protocol` ni `--port`:

- se usa `udp`
- se usa `10514`

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --run-test
```

#### Caso B: TCP con puerto por defecto

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --protocol tcp \
  --run-test
```

#### Caso C: UDP con puerto personalizado

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --protocol udp \
  --port 5514 \
  --run-test
```

#### Caso D: ambos protocolos con el mismo puerto

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --protocol both \
  --port 10514 \
  --run-test
```

#### Caso E: ambos protocolos con puertos distintos

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --protocol both \
  --tcp-port 10514 \
  --udp-port 5514 \
  --run-test
```

#### Qué hace el script del servidor

- instala rsyslog
- prepara el directorio `/var/log/remote`
- comprueba si `/var/log/remote` es un mountpoint independiente y avisa si no lo es
- configura recepción `udp`, `tcp` o `both` según lo indicado
- usa puerto por defecto `10514` en modo basic cuando no se especifica otro
- separa logs remotos usando un ruleset
- crea directorios remotos automáticamente por IP
- configura logrotate
- crea backups de configuraciones previas
- restringe acceso con UFW según las IPs permitidas y el protocolo usado
- genera un informe final

### 💻 Paso 3: cliente

#### Caso A: default absoluto

Si no indicas `--protocol` ni `--port`:

- se usa `udp`
- se usa `10514`

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --run-test
```

#### Caso B: TCP con puerto por defecto

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --protocol tcp \
  --run-test
```

#### Caso C: UDP con puerto personalizado

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --protocol udp \
  --port 5514 \
  --run-test
```

#### Qué hace el script del cliente

- instala rsyslog si hace falta
- configura forwarding por `udp` o `tcp` al servidor
- usa puerto por defecto `10514` en modo basic cuando no se especifica otro
- mantiene logs locales
- hace backup de configuraciones previas
- genera un informe final

### 🧪 Paso 4: verificación

En el cliente:

```bash
logger "TEST BASICO"
```

En el servidor:

```bash
tail -f /var/log/remote/*/*.log
```

### 📌 Reglas importantes en modo basic

- si el servidor está en `udp`, el cliente debe enviar por `udp`
- si el servidor está en `tcp`, el cliente debe enviar por `tcp`
- si el servidor está en `both`, el cliente puede usar cualquiera de los dos
- si cambias el puerto en un lado, debes usar el mismo en el otro

### 📌 Cuándo usar este modo

Úsalo para:

- laboratorio
- pruebas rápidas
- demos técnicas internas

No lo uses como modo final de producción. Para eso, usa TLS.

</details>

---

<a id="modo-tls-seguro"></a>
<details>
<summary><strong>🔐 Modo TLS (seguro)</strong></summary>

Este modo añade cifrado y autenticación mutua. Es la opción recomendada para demos serias, preproducción y producción.

### 🧱 Arquitectura

```text
Cliente ⇄ Servidor syslog (TLS sobre TCP, puerto 6514 por defecto)
```

### 🖥️ Preparación previa del servidor

Antes de ejecutar el script:

- habilita SSH
- monta el disco de logs en `/var/log/remote`

### 🖥️ Servidor

Puerto por defecto en `tls`: `6514`

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.10 \
  --server-ip 172.16.3.2 \
  --tls-clients kali01 \
  --run-test
```

Si quieres cambiar el puerto TLS:

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.10 \
  --port 6515 \
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

Puerto por defecto en `tls`: `6514`

```bash
sudo bash scripts/setup_syslog_client_v5.sh tls \
  --server 172.16.3.2 \
  --ca ca.crt \
  --cert client.crt \
  --key client.key \
  --peer syslog.local \
  --run-test
```

Si quieres cambiar el puerto TLS:

```bash
sudo bash scripts/setup_syslog_client_v5.sh tls \
  --server 172.16.3.2 \
  --port 6515 \
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

<a id="demo"></a>
<details>
<summary><strong>🧪 DEMO</strong></summary>

Esta es una DEMO rápida que suele funcionar muy bien.

### Demo básica por defecto

Asegúrate de que `/var/log/remote` ya está montado si quieres usar el segundo disco.

Arranca el servidor en basic por defecto:

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --run-test
```

Arranca el cliente en basic por defecto:

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --run-test
```

En el cliente:

```bash
logger "PRUEBA DEMO"
```

En el servidor:

```bash
tail -f /var/log/remote/*/*.log
```

### Demo básica por TCP

Servidor:

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --protocol tcp \
  --run-test
```

Cliente:

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --protocol tcp \
  --run-test
```

### Demo más potente orientada a seguridad

Asegúrate de que `/var/log/remote` ya está montado si quieres usar el segundo disco.

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

<a id="archivos-importantes"></a>
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
| `/var/log/remote/` | Ruta donde el servidor guarda los logs remotos |

</details>

---

<a id="troubleshooting"></a>
<details>
<summary><strong>🛠️ Troubleshooting</strong></summary>

### ❌ No llegan logs

Comprueba en el servidor:

```bash
sudo systemctl status rsyslog
sudo ufw status
mountpoint /var/log/remote
df -h
sudo cat /root/syslog_server_report.txt
```

Comprueba puertos en escucha:

```bash
sudo ss -tulpn | grep -E '10514|5514|6514'
```

Comprueba en el cliente:

```bash
sudo systemctl status rsyslog
sudo cat /root/syslog_client_report.txt
```

Revisa también:

- IP correcta del servidor
- IP del cliente incluida en `--allowed-ips`
- conectividad entre máquinas
- que `/var/log/remote` esté montado si quieres usar el segundo disco
- que cliente y servidor usen el **mismo protocolo**
- que cliente y servidor usen el **mismo puerto**

### ❌ El servidor escucha en UDP y el cliente está enviando por TCP

Ejemplo de error típico:

- servidor: `basic` por defecto → `udp 10514`
- cliente: `basic --protocol tcp`

Así no funcionará.

Solución: hacer coincidir ambos lados.

### ❌ El servidor escucha en ambos, pero no en el puerto esperado

Si usas:

```bash
--protocol both --tcp-port 10514 --udp-port 5514
```

entonces:

- TCP escucha en `10514`
- UDP escucha en `5514`

No asumas que ambos usan el mismo puerto si has separado `--tcp-port` y `--udp-port`.

### ❌ Los logs se están yendo al disco del sistema

Comprueba:

```bash
mountpoint /var/log/remote
df -h
lsblk
```

Si `/var/log/remote` no está montado sobre el segundo disco, el script seguirá escribiendo en el disco del sistema.

### ❌ TLS no funciona

Revisa:

- que `--peer` coincide con el nombre esperado del certificado del servidor
- que el cliente está usando la CA correcta
- que `client.crt` y `client.key` corresponden entre sí
- que el servidor incluye el cliente en `--tls-clients`
- que el SAN del servidor incluye el nombre o IP usados
- que cliente y servidor usan el mismo puerto TLS

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

<a id="faq"></a>
<details>
<summary><strong>❓ FAQ</strong></summary>

### ¿Cuál es el protocolo por defecto en modo basic?

- servidor: `udp`
- cliente: `udp`

### ¿Cuál es el puerto por defecto en modo basic?

- servidor: `10514`
- cliente: `10514`

### ¿Qué pasa si indico protocolo pero no puerto?

En modo `basic`, se usa `10514`.

### ¿Qué pasa si no indico ni protocolo ni puerto?

En modo `basic`, se usa `udp` en `10514`.

### ¿Puede el servidor escuchar en TCP y UDP a la vez?

Sí. Usa:

```bash
--protocol both
```

Y además puedes:

- usar el mismo puerto para ambos con `--port`
- usar puertos distintos con `--tcp-port` y `--udp-port`

### ¿Puede el cliente enviar a la vez por TCP y UDP?

No. El cliente elige uno por ejecución:

- `--protocol udp`
- `--protocol tcp`

### ¿Se pierden logs locales del cliente?

No. El cliente sigue manteniendo sus logs locales. El modo `disable` solo quita el envío remoto.

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

### ¿Es obligatorio usar un segundo disco?

No es obligatorio, pero sí recomendable. Si no montas un segundo disco en `/var/log/remote`, los logs remotos se guardarán en el disco del sistema.

### ¿Se puede administrar la VM sin SSH?

Sí, pero no es lo más cómodo. Se recomienda habilitar SSH para hacer el montaje del disco, editar `/etc/fstab` y ejecutar los scripts con más facilidad.

</details>

---

<a id="seguridad"></a>
<details>
<summary><strong>⚠️ Seguridad</strong></summary>

- no subas certificados ni claves al repositorio
- restringe siempre IPs con `--allowed-ips`
- usa TLS en producción
- protege el acceso al servidor syslog
- no reutilices claves privadas entre máquinas
- no expongas SSH a redes no confiables sin controles adicionales
- usa contraseñas robustas o, mejor aún, claves SSH

</details>

---

<a id="integracion-continua"></a>
<details>
<summary><strong>⚙️ Integración continua</strong></summary>

El repositorio incluye:

- validación de scripts con `bash -n`
- análisis con `shellcheck`
- test de instalación simulada en Ubuntu 24.04

Esto ayuda a detectar errores antes de usar los scripts en laboratorio o preproducción.

</details>

---

<a id="recomendacion-practica"></a>
<details open>
<summary><strong>📌 Recomendación práctica</strong></summary>

Usa este orden:

- instala Ubuntu Server en el disco del sistema
- habilita SSH
- monta el segundo disco en `/var/log/remote`
- valida primero `basic` por defecto (`udp 10514`)
- si quieres validar `tcp`, cámbialo explícitamente en cliente y servidor
- usa `both` en el servidor solo cuando de verdad necesites aceptar ambos transportes
- pasa a `tls` para endurecer el despliegue
- añade más clientes

</details>
