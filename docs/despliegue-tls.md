# 🔐 Despliegue syslog con TLS

Modo seguro con cifrado y autenticación mutua (mTLS).

---

## 🧱 Arquitectura

```text
Cliente ⇄ Servidor syslog (TLS sobre TCP, puerto 6514 por defecto)
```

---

## 🖥️ 1. Servidor

### Puerto por defecto

Si no indicas `--port`, el modo `tls` usa `6514`.

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.3 \
  --server-ip 172.16.3.2 \
  --tls-clients kali01 \
  --run-test
```

### Puerto TLS personalizado

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.3 \
  --port 6515 \
  --server-ip 172.16.3.2 \
  --tls-clients kali01 \
  --run-test
```

### 🔍 Qué hace

- genera una CA propia
- genera certificado del servidor con SAN
- genera certificados por cliente
- configura rsyslog con TLS/mTLS
- exporta bundles por cliente
- limpia reglas `ALLOW` antiguas de UFW relacionadas con syslog, salvo que uses `--keep`
- restringe acceso con UFW
- genera informe final

### Firewall e idempotencia

Aunque TLS autentica clientes con certificado, UFW sigue limitando qué IPs pueden llegar al puerto del servidor.

Por defecto, al reejecutar el servidor en modo `tls`, el script:

- detecta el puerto TCP actual de TLS
- detecta puertos syslog de configuraciones anteriores
- avisa de que va a limpiar reglas `ALLOW` antiguas
- pide confirmación interactiva
- recrea sólo las reglas actuales de `--allowed-ips`

Ejemplo de reconfiguración de IPs permitidas:

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.11 \
  --port 6514 \
  --server-ip 172.16.3.2 \
  --tls-clients kali01
```

Si necesitas conservar reglas anteriores:

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.11 \
  --port 6514 \
  --server-ip 172.16.3.2 \
  --tls-clients kali01 \
  --keep
```

---

## 📦 2. Bundles TLS generados

En el servidor, para cada cliente:

```text
/root/syslog-client-bundles/<cliente>/
```

Contiene:

- `ca.crt`
- `client.crt`
- `client.key`

Ejemplo:

```text
/root/syslog-client-bundles/kali01/
```

---

## 💻 3. Cliente

### Puerto por defecto

Si no indicas `--port`, el modo `tls` usa `6514`.

```bash
sudo bash scripts/setup_syslog_client_v5.sh tls \
  --server 172.16.3.2 \
  --ca ca.crt \
  --cert client.crt \
  --key client.key \
  --peer syslog.local \
  --run-test
```

### Puerto TLS personalizado

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

### 🔍 Qué hace

- copia CA, certificado y clave al directorio local
- configura forwarding por TCP + TLS
- valida la configuración
- mantiene rsyslog local activo
- genera informe final

---

## 🧪 4. Verificación

En el cliente:

```bash
logger "TEST TLS"
```

En el servidor:

```bash
tail -f /var/log/remote/*/*.log
```

También puedes comprobar el puerto TLS en el servidor:

```bash
sudo ss -tulpn | grep 6514
```

o, si usaste un puerto distinto:

```bash
sudo ss -tulpn | grep 6515
```

---

## 🛠️ 5. Problemas comunes

### ❌ TLS no conecta

Revisar:

- `--peer` correcto
- CA correcta
- `client.crt` y `client.key` correctos
- cliente incluido en `--tls-clients`
- SAN del servidor correcto
- mismo puerto TLS en cliente y servidor

### ❌ Quiero revisar un certificado

```bash
openssl x509 -in client.crt -text -noout
```

### ❌ Cambié IP o nombres

Esto suele romper la validación TLS.

La solución recomendada es regenerar certificados:

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.3 \
  --server-ip NUEVA_IP \
  --tls-clients kali01 \
  --regenerate-certs
```

Después, hay que volver a copiar los nuevos bundles al cliente.

### ❌ Quiero dejar de enviar logs

En el cliente:

```bash
sudo bash scripts/setup_syslog_client_v5.sh disable
```

El modo `disable` no acepta opciones adicionales; sólo elimina el forwarding remoto y mantiene rsyslog local.

---

## 🔄 6. Regenerar certificados

Usa la opción:

```text
--regenerate-certs
```

Sirve cuando:

- cambiaste IPs
- cambiaste nombres
- quieres reiniciar la PKI
- hiciste pruebas y quieres limpiar material anterior

---

## 🔐 7. Buenas prácticas

- 1 cliente = 1 certificado
- usar nombres coherentes para clientes
- proteger claves privadas
- restringir IPs con `--allowed-ips` aunque uses TLS
- no usar `--keep` salvo que quieras conservar reglas UFW antiguas de forma explícita
- rotar certificados periódicamente en entornos serios
- usar el mismo puerto TLS en cliente y servidor

---

## 📄 Archivos relevantes

### Servidor

- `/etc/rsyslog.d/10-tls.conf`
- `/etc/rsyslog-certs/`
- `/root/syslog-client-bundles/`
- `/root/syslog_setup_backups/`
- `/root/syslog_server_report.txt`

### Cliente

- `/etc/rsyslog.d/20-tls.conf`
- `/etc/rsyslog-certs/`
- `/root/syslog_setup_backups/`
- `/root/syslog_client_report.txt`

---

## 📌 8. Cuándo usar este modo

- ✔ Producción
- ✔ Redes sensibles
- ✔ Auditoría
- ✔ Cumplimiento
- ✔ DEMOs serias

---

## 🧾 Resumen

El modo `tls` añade:

- cifrado
- autenticación mutua
- control de acceso más fuerte
- mejor trazabilidad
- una base más sólida para producción
