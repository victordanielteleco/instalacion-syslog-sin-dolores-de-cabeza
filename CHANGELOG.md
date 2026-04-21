# Changelog

Todos los cambios importantes de este proyecto se documentan en este archivo.

## [1.0.5] - 2026-04-21

### Added
- Opción `--keep` en `setup_syslog_server_v5.sh` para conservar reglas antiguas de UFW de forma explícita
- Confirmación interactiva antes de eliminar reglas `ALLOW` antiguas de UFW relacionadas con syslog
- Documentación en `README.md`, `docs/despliegue-basico.md` y `docs/despliegue-tls.md` sobre la limpieza por defecto de UFW y el uso de `--keep`
- Caso de prueba en `test-installation.yml` para validar una reconfiguración del servidor que limpia reglas UFW antiguas
- Casos de prueba en `test-installation.yml` para cliente `basic` por UDP con puerto personalizado y cliente `tls` con puerto personalizado
- Entrada `.codex` en `.gitignore` para evitar subir artefactos locales del entorno por accidente

### Changed
- `setup_syslog_server_v5.sh` ahora trata UFW como estado deseado por defecto: limpia reglas `ALLOW` antiguas del servicio syslog y recrea sólo las reglas actuales de `--allowed-ips`
- La limpieza UFW del servidor tiene en cuenta puertos/protocolos actuales y también configuraciones previas de `rsyslog`, cubriendo cambios de IPs, protocolo, puerto o modo
- `setup_syslog_client_v5.sh` documenta correctamente que el modo `basic` reenvía por UDP o TCP
- `setup_syslog_client_v5.sh` valida de forma estricta las opciones permitidas por modo para evitar parámetros aceptados pero ignorados
- Comentarios internos ampliados en las funciones sensibles de UFW y en la validación de opciones del cliente para facilitar revisión por el equipo
- La documentación aclara que el modo `disable` del cliente no acepta opciones adicionales

### Fixed
- Corregida la falsa idempotencia de UFW en el servidor: las IPs antiguas ya no permanecen permitidas por defecto tras reejecutar el script con otra lista en `--allowed-ips`
- Mejorada la detección de reglas UFW a eliminar para borrar sólo reglas `ALLOW` relacionadas con syslog y no reglas `DENY`, SSH u otros servicios
- Corregida la ayuda/comentario del cliente que describía `basic` como TCP aunque el comportamiento real y documentado permite UDP o TCP

### Notes
- `--keep` conserva el comportamiento anterior de sólo añadir reglas nuevas sin borrar reglas antiguas
- El modo `disable` del cliente elimina forwarding remoto, mantiene `rsyslog` local y no ejecuta pruebas con `logger`
- Las pruebas funcionales se validaron con rutas temporales y mocks para no modificar UFW real, `/etc` real ni servicios del sistema

## [1.0.4] - 2026-04-16

### Added
- Soporte en `setup_syslog_server_v5.sh` para elegir en modo `basic` entre `udp`, `tcp` o `both`
- Soporte en `setup_syslog_server_v5.sh` para usar un puerto común con `--port` o puertos separados con `--tcp-port` y `--udp-port` en modo `basic`
- Soporte en `setup_syslog_client_v5.sh` para elegir en modo `basic` entre `udp` y `tcp`
- Avisos informativos en servidor y cliente cuando en modo `basic` se aplican valores por defecto de protocolo o puerto
- Documentación ampliada en `README.md` y `docs/despliegue-basico.md` para reflejar el nuevo comportamiento de `basic`
- Casos de prueba nuevos en GitHub Actions para validar `basic` por defecto, `basic` por `tcp` y `basic` con `both`

### Changed
- En `setup_syslog_server_v5.sh`, el modo `basic` pasa a usar por defecto `udp` en el puerto `10514` cuando no se indica ni protocolo ni puerto
- En `setup_syslog_client_v5.sh`, el modo `basic` pasa a usar por defecto `udp` en el puerto `10514` cuando no se indica ni protocolo ni puerto
- `README.md` reorganizado para explicar de forma más clara cómo deben coincidir protocolo y puerto entre cliente y servidor
- `docs/despliegue-tls.md` actualizado para reflejar que el puerto TLS también puede personalizarse con `--port`
- `validate.yml` ampliado para comprobar referencias nuevas sobre `basic`, protocolos y puertos en la documentación
- `test-installation.yml` ampliado para probar los nuevos casos de `udp`, `tcp` y `both` en modo `basic`

### Notes
- `tls` sigue usando TCP y mantiene como puerto por defecto `6514`
- El cliente en `basic` elige un único protocolo por ejecución
- El servidor en `basic` puede escuchar en ambos protocolos a la vez si se usa `--protocol both`

## [1.0.3] - 2026-04-15

### Fixed
- Corregida la generación de configuración `rsyslog` en `setup_syslog_server_v5.sh` para definir `template(name="RemoteLogs" ...)` fuera de los `ruleset`, evitando errores de validación en modo `basic` y `tls`
- Añadida creación automática de directorios remotos en `rsyslog` con `createDirs="on"` para que las rutas por IP se generen correctamente al recibir logs
- Ajustado el workflow `test-installation.yml` para instalar `util-linux` en el contenedor de pruebas, garantizando la disponibilidad de `mountpoint`

### Added
- Comprobación informativa en `setup_syslog_server_v5.sh` para avisar cuando `/var/log/remote` no está montado como punto de montaje independiente y los logs van al disco del sistema

### Notes
- No cambia el uso funcional de los modos `basic` y `tls`
- La mejora del script sigue siendo no destructiva: avisa del montaje, pero no bloquea la instalación

## [1.0.2] - 2026-04-15

### Added
- Aviso explícito en `README.md` indicando que el servidor escribe en `/var/log/remote` y que el uso de un segundo disco depende de que el usuario lo monte previamente
- Guía en `README.md` para habilitar SSH en la VM antes del despliegue
- Guía en `README.md` para preparar, montar y verificar un disco de logs en Ubuntu Server
- Recomendación operativa de administrar la VM por SSH para facilitar el despliegue y el mantenimiento

### Changed
- `README.md` reorganizado para reflejar el flujo recomendado real: instalar Ubuntu, habilitar SSH, montar el disco de logs y después ejecutar los scripts
- Ampliadas las secciones de troubleshooting y FAQ con comprobaciones relacionadas con `/var/log/remote` y el uso de un segundo disco
- Ajustado el workflow de instalación simulada para declarar explícitamente la herramienta necesaria para `mountpoint` en el contenedor de pruebas

### Fixed
- Mejora técnica en `setup_syslog_server_v5.sh` para avisar cuando `/var/log/remote` no está montado como punto de montaje independiente y los logs van a parar al disco del sistema

### Notes
- No cambia el modo de uso de los scripts `basic` y `tls`
- La mejora del script es informativa y no destructiva: avisa, pero no bloquea la instalación
- El workflow `validate.yml` no necesita cambios porque las comprobaciones del README siguen cumpliéndose

## [1.0.1] - 2026-04-14

### Fixed
- Creación explícita de `/etc/rsyslog.d` en los scripts para evitar fallos en entornos mínimos o simulados
- Creación explícita de `/etc/logrotate.d` en el script del servidor para evitar errores al escribir la configuración de rotación
- Mejora de compatibilidad con la validación en GitHub Actions y con contenedores Ubuntu mínimos
- Se añaden badges en README.md para facilitar lla lectura, haciendo más visual la repo, dejan claro de un vistazo para qué sirve

### Notes
- No cambia el uso funcional de los scripts en Ubuntu Server o Kali reales
- Corrige errores observados en el workflow de instalación simulada

## [1.0.0] - 2026-04-14

### Added
- Script de despliegue de servidor syslog en modo `basic`
- Script de despliegue de servidor syslog en modo `tls`
- Script de despliegue de cliente syslog en modo `basic`
- Script de despliegue de cliente syslog en modo `tls`
- Modo `disable` en cliente para dejar de reenviar logs sin apagar `rsyslog`
- Generación automática de CA y certificados
- Soporte para múltiples clientes TLS
- Soporte para múltiples IPs permitidas en servidor
- Soporte para SAN en certificados del servidor y clientes
- Export automático de bundles TLS por cliente
- Separación de logs locales y remotos mediante `ruleset`
- Configuración de `logrotate`
- Backups automáticos de configuraciones previas
- Informes finales de despliegue en servidor y cliente
- Documentación de despliegue básico
- Documentación de despliegue TLS
- README operativo con demo, FAQ, troubleshooting y rutas importantes
- Validación automática con GitHub Actions
- Test de instalación simulada en Ubuntu 24.04

### Notes
- Repositorio preparado para uso por equipo técnico interno
- Instalación pensada para ejecutarse desde `git clone` + scripts
