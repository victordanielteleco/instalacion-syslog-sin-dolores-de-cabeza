# Changelog

Todos los cambios importantes de este proyecto se documentan en este archivo.

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
