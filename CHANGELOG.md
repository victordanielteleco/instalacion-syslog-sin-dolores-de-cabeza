# Changelog

Todos los cambios importantes de este proyecto se documentan en este archivo.

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
