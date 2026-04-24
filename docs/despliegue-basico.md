# 🧾 Despliegue básico de syslog

Modo rápido sin TLS para validar conectividad, recepción de logs y funcionamiento general del sistema.

---

## 🧱 Arquitectura

### Opción 1: UDP por defecto

```text
Cliente → Servidor syslog (UDP 10514)
```

### Opción 2: TCP

```text
Cliente → Servidor syslog (TCP 10514)
```

### Opción 3: Servidor escuchando en ambos

```text
Cliente → Servidor syslog (UDP y TCP)
```

> El cliente elige un único protocolo por ejecución (`udp` o `tcp`).  
> El servidor puede escuchar en `udp`, en `tcp` o en `both`.

---

## 🖥️ 1. Servidor

### Caso A: valores por defecto

Si no indicas `--protocol` ni `--port`:

- se usa `udp`
- se usa el puerto `10514`

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.3 \
  --run-test
```

### Caso B: TCP con puerto por defecto

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.3 \
  --protocol tcp \
  --run-test
```

### Caso C: UDP con puerto personalizado

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.3 \
  --protocol udp \
  --port 5514 \
  --run-test
```

### Caso D: ambos protocolos con el mismo puerto

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.3 \
  --protocol both \
  --port 10514 \
  --run-test
```

### Caso E: ambos protocolos con puertos distintos

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.3 \
  --protocol both \
  --tcp-port 10514 \
  --udp-port 5514 \
  --run-test
```

### 🔍 Qué hace

- instala rsyslog
- prepara `/var/log/remote`
- comprueba si `/var/log/remote` es un mountpoint independiente y avisa si no lo es
- configura recepción `udp`, `tcp` o `both`
- usa puerto por defecto `10514` en modo `basic` cuando no se especifica otro
- separa logs remotos por IP y programa
- crea directorios remotos automáticamente
- configura logrotate
- crea backups de configuración
- limpia reglas `ALLOW` antiguas de UFW relacionadas con syslog, salvo que uses `--keep`
- restringe acceso con UFW
- genera informe final

### Firewall e idempotencia

Cuando reejecutas el script del servidor, UFW se trata como estado deseado para el servicio syslog.

Por defecto, antes de crear reglas nuevas, el script:

- detecta el puerto y protocolo syslog configurados ahora
- detecta puertos y protocolos syslog de una configuración anterior
- avisa de que va a limpiar reglas `ALLOW` antiguas
- pide confirmación interactiva
- vuelve a crear sólo las reglas actuales de `--allowed-ips`
- coloca las reglas `ALLOW` específicas antes del `DENY` general del puerto/protocolo

Ejemplo de reconfiguración de IPs permitidas:

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.11 \
  --protocol udp \
  --port 10514
```

Si quieres conservar reglas anteriores y sólo añadir las nuevas, usa `--keep`:

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.11 \
  --protocol udp \
  --port 10514 \
  --keep
```

---

## 💻 2. Cliente

### Caso A: valores por defecto

Si no indicas `--protocol` ni `--port`:

- se usa `udp`
- se usa el puerto `10514`

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --run-test
```

### Caso B: TCP con puerto por defecto

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --protocol tcp \
  --run-test
```

### Caso C: UDP con puerto personalizado

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --protocol udp \
  --port 5514 \
  --run-test
```

### 🔍 Qué hace

- instala rsyslog si hace falta
- configura forwarding por `udp` o `tcp`
- usa puerto por defecto `10514` en modo `basic` cuando no se especifica otro
- mantiene logs locales
- hace backup de configuraciones previas
- genera informe final

---

## 🧪 3. Verificación

En el cliente:

```bash
logger "TEST BASICO"
```

En el servidor:

```bash
tail -f /var/log/remote/*/*.log
```

---

## 📂 4. Logs generados

```text
/var/log/remote/<IP>/<programa>.log
```

Ejemplo:

```text
/var/log/remote/172.16.3.3/sudo.log
```

Si un emisor no envía `programname`, el servidor guardará el evento en:

```text
/var/log/remote/<IP>/unknown-program.log
```

---

## 🛠️ 5. Problemas comunes

### ❌ No llegan logs

Comprobar en el servidor:

```bash
sudo systemctl status rsyslog
sudo ufw status
sudo cat /root/syslog_server_report.txt
mountpoint /var/log/remote
df -h
```

Comprobar puertos en escucha:

```bash
sudo ss -tulpn | grep -E '10514|5514'
```

Comprobar en el cliente:

```bash
sudo systemctl status rsyslog
sudo cat /root/syslog_client_report.txt
```

Revisar también:

- IP correcta del servidor
- IP cliente incluida en `--allowed-ips`
- conectividad entre ambas máquinas
- que cliente y servidor usan el mismo protocolo
- que cliente y servidor usan el mismo puerto
- que `/var/log/remote` esté montado si quieres usar el segundo disco

### ❌ UFW sigue mostrando IPs antiguas

Por defecto, el script limpia reglas `ALLOW` antiguas del servicio syslog antes de aplicar las actuales.

Si ves IPs antiguas tras reconfigurar:

- confirma la limpieza cuando el script pregunte
- comprueba que no hayas usado `--keep`
- revisa si la regla antigua es una regla manual más amplia que no pertenece al puerto/protocolo syslog configurado

### ❌ Servidor por defecto en UDP y cliente por TCP

Ejemplo típico:

- servidor: `basic` sin opciones extra
- cliente: `basic --protocol tcp`

Así no funcionará.

Solución: hacer coincidir ambos lados.

### ❌ Servidor en `both` con puertos distintos

Si usas:

```bash
--protocol both --tcp-port 10514 --udp-port 5514
```

entonces:

- TCP escucha en `10514`
- UDP escucha en `5514`

El cliente debe apuntar al puerto correcto según el protocolo que uses.

### ❌ Hay configuraciones raras o mezcladas

Revisar:

```bash
ls -l /etc/rsyslog.d/
```

Puede haber configuraciones antiguas interfiriendo.

### ❌ Quiero dejar de enviar logs

En el cliente:

```bash
sudo bash scripts/setup_syslog_client_v5.sh disable
```

El modo `disable` no acepta opciones adicionales; sólo elimina el forwarding remoto y mantiene rsyslog local.

---

## 📌 6. Cuándo usar este modo

- ✔ Laboratorio
- ✔ Pruebas
- ✔ DEMO rápida
- ✔ Validación inicial de conectividad

- ❌ Producción final, donde se recomienda `tls`

---

## 📄 Archivos relevantes

### Servidor

- `/etc/rsyslog.d/10-remote.conf`
- `/var/log/remote/`
- `/root/syslog_setup_backups/`
- `/root/syslog_server_report.txt`

### Cliente

- `/etc/rsyslog.d/20-forward.conf`
- `/root/syslog_setup_backups/`
- `/root/syslog_client_report.txt`

---

## ✅ Resumen

El modo `basic` es la forma más rápida de validar:

- conectividad
- recepción de logs
- separación por IP
- funcionamiento general del sistema
- compatibilidad entre `udp` y `tcp`

Cuando eso esté validado, el siguiente paso recomendado es pasar a `tls`.
