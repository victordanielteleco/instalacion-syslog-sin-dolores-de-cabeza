## 🖥️ 1. Servidor

```bash
sudo bash scripts/setup_syslog_server_v5.sh basic \
  --allowed-ips 172.16.3.10 \
  --run-test
```

### 🔍 Qué hace

- instala rsyslog
- prepara /var/log/remote
- configura recepción TCP
- separa logs remotos por IP y programa
- configura logrotate
- crea backups de configuración
- restringe acceso con UFW
- genera informe final

## 💻 2. Cliente

```bash
sudo bash scripts/setup_syslog_client_v5.sh basic \
  --server 172.16.3.2 \
  --run-test
```

### 🔍 Qué hace

- instala rsyslog si hace falta
- configura forwarding por TCP al servidor
- mantiene logs locales
- hace backup de configuraciones previas
- genera informe final

## 🧪 3. Verificación

En el cliente:

```bash
logger "TEST BASICO"
```

En el servidor:

```bash
tail -f /var/log/remote/*/*.log
```

## 📂 4. Logs generados

`/var/log/remote/<IP>/<programa>.log`

Ejemplo:

`/var/log/remote/172.16.3.10/sudo.log`

## 🛠️ 5. Problemas comunes

### ❌ No llegan logs

Comprobar en el servidor:

```bash
ss -tulpn | grep 10514
sudo systemctl status rsyslog
sudo ufw status
```

Comprobar en el cliente:

```bash
sudo systemctl status rsyslog
```

Revisar también:

- IP correcta del servidor
- IP cliente incluida en --allowed-ips
- conectividad entre ambas máquinas

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

## 📌 6. Cuándo usar este modo

- ✔ Laboratorio
- ✔ Pruebas
- ✔ Demo rápida

- ❌ Producción final, donde se recomienda tls

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

## ✅ Resumen

El modo basic es la forma más rápida de validar:

- conectividad
- recepción de logs
- separación por IP
- funcionamiento general del sistema

Cuando eso esté validado, el siguiente paso recomendado es pasar a tls.
