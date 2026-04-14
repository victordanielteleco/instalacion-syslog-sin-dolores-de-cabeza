# 🔐 Despliegue syslog con TLS

Modo seguro con cifrado y autenticación mutua (mTLS).

---

## 🧱 Arquitectura

```text
Cliente ⇄ Servidor syslog (TLS 6514)
```

## 🖥️ 1. Servidor

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.10 \
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
- restringe acceso con UFW
- genera informe final

## 📦 2. Bundles TLS generados

En el servidor, para cada cliente:

```text
/root/syslog-client-bundles/<cliente>/
```

Contiene:

- ca.crt
- client.crt
- client.key

Ejemplo:

```text
/root/syslog-client-bundles/kali01/
```

## 💻 3. Cliente

Copiar al cliente los archivos del bundle correspondiente y ejecutar:

```bash
sudo bash scripts/setup_syslog_client_v5.sh tls \
  --server 172.16.3.2 \
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
ss -tulpn | grep 6514
```

## 🛠️ 5. Problemas comunes

### ❌ TLS no conecta

Revisar:

- --peer correcto
- CA correcta
- client.crt y client.key correctos
- cliente incluido en --tls-clients
- SAN del servidor correcto

### ❌ Quiero revisar un certificado

```bash
openssl x509 -in client.crt -text -noout
```

### ❌ Cambié IP o nombres

Esto suele romper la validación TLS.

La solución recomendada es regenerar certificados:

```bash
sudo bash scripts/setup_syslog_server_v5.sh tls \
  --allowed-ips 172.16.3.10 \
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

## 🔐 7. Buenas prácticas

- 1 cliente = 1 certificado
- usar nombres coherentes para clientes
- proteger claves privadas
- restringir IPs con --allowed-ips aunque uses TLS
- rotar certificados periódicamente en entornos serios

## 📄 Archivos relevantes

### Servidor

- /etc/rsyslog.d/10-tls.conf
- /etc/rsyslog-certs/
- /root/syslog-client-bundles/
- /root/syslog_setup_backups/
- /root/syslog_server_report.txt

### Cliente

- /etc/rsyslog.d/20-tls.conf
- /etc/rsyslog-certs/
- /root/syslog_setup_backups/
- /root/syslog_client_report.txt

## 📌 8. Cuándo usar este modo

- ✔ Producción
- ✔ Redes sensibles
- ✔ Auditoría
- ✔ Cumplimiento
- ✔ Demos serias

## 🧾 Resumen

El modo tls añade:

- cifrado
- autenticación mutua
- control de acceso más fuerte
- mejor trazabilidad
- una base más sólida para producción
