#!/usr/bin/env bash
# Usa bash para ejecutar este script.

set -euo pipefail
# -e: termina si un comando falla.
# -u: falla si usas variables no definidas.
# -o pipefail: detecta fallos dentro de tuberías.

#
# setup_syslog_client_v5.sh
#
# Propósito:
#   Configurar un cliente Kali/Debian/Ubuntu para reenviar logs a un servidor syslog.
#
# Modos:
#   basic   -> forwarding TCP
#   tls     -> forwarding TCP + TLS
#   disable -> elimina forwarding remoto manteniendo logs locales
#
# Uso:
#   sudo bash scripts/setup_syslog_client_v5.sh basic --server 172.16.3.2
#   sudo bash scripts/setup_syslog_client_v5.sh tls --server 172.16.3.2 --ca /ruta/ca.crt --cert /ruta/client.crt --key /ruta/client.key --peer syslog.local
#
# Compatibilidad:
#   Kali Linux, Debian, Ubuntu con systemd y rsyslog
#
# Notas:
#   - Hace backups de configuraciones previas
#   - Mantiene rsyslog local activo en modo disable
#   - No subas claves ni certificados al repositorio

MODE="${1:-}"
# Guarda el primer argumento: basic, tls o disable.

shift || true
# Quita el primer argumento de la lista.

SERVER=""
# Servidor syslog destino.

PORT=""
# Puerto remoto destino.

BASIC_PROTOCOL="udp"
# Protocolo del modo basic: udp o tcp.

BASIC_PROTOCOL_EXPLICIT="false"
# Indica si el usuario ha especificado --protocol.

CA_FILE=""
# Ruta local al certificado CA que copiaremos al cliente.

CERT_FILE=""
# Ruta local al certificado del cliente.

KEY_FILE=""
# Ruta local a la clave privada del cliente.

PEER_NAME=""
# Nombre esperado del certificado del servidor.

CERT_DIR="/etc/rsyslog-certs"
# Directorio local donde se guardarán los certificados.

BACKUP_DIR="/root/syslog_setup_backups"
# Directorio de backups de configuraciones previas.

FORWARD_CONF="/etc/rsyslog.d/20-forward.conf"
# Configuración del forwarding básico.

TLS_CONF="/etc/rsyslog.d/20-tls.conf"
# Configuración del forwarding TLS.

RUN_TEST="false"
# Si vale true, genera un logger al final.

info()  { echo "[INFO]  $*"; }
# Mensajes informativos.

ok()    { echo "[OK]    $*"; }
# Mensajes de éxito.

warn()  { echo "[WARN]  $*"; }
# Mensajes de advertencia.

error() { echo "[ERROR] $*" >&2; }
# Mensajes de error por stderr.

die() {
  error "$*"
  # Muestra el error.
  exit 1
  # Sale con error.
}

usage() {
  cat <<'EOF'
Uso:

  Modo basic con valores por defecto:
    sudo bash scripts/setup_syslog_client_v5.sh basic \
      --server 172.16.3.2

    Si no indicas --protocol ni --port:
      - se usa udp
      - se usa el puerto 10514

  Modo basic indicando protocolo:
    sudo bash scripts/setup_syslog_client_v5.sh basic \
      --server 172.16.3.2 \
      --protocol tcp \
      [--port 10514] \
      [--run-test]

    Protocolos válidos:
      --protocol udp
      --protocol tcp

  Modo tls:
    sudo bash scripts/setup_syslog_client_v5.sh tls \
      --server 172.16.3.2 \
      --port 6514 \
      --ca ./ca.crt \
      --cert ./client.crt \
      --key ./client.key \
      --peer syslog.local \
      [--run-test]

  Desactivar forwarding:
    sudo bash scripts/setup_syslog_client_v5.sh disable
EOF
}
# Muestra ayuda.

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Ejecuta este script con sudo o como root."
  # Obliga a ejecutar como root.
}

is_valid_port() {
  local port="$1"
  [[ "${port}" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
}

resolve_basic_transport() {
  [[ "${MODE}" == "basic" ]] || return 0

  case "${BASIC_PROTOCOL}" in
    udp|tcp) ;;
    *)
      die "En modo basic, --protocol debe ser udp o tcp"
      ;;
  esac

  if [[ -n "${PORT}" ]] && ! is_valid_port "${PORT}"; then
    die "Puerto no válido en modo basic: ${PORT}"
  fi

  if [[ -z "${PORT}" ]]; then
    PORT="10514"
    if [[ "${BASIC_PROTOCOL_EXPLICIT}" == "true" ]]; then
      warn "No se indicó --port en modo basic con protocolo ${BASIC_PROTOCOL}. Se usará el puerto 10514."
    else
      warn "No se indicó --protocol ni --port en modo basic. Se usará UDP en el puerto 10514."
    fi
  elif [[ "${BASIC_PROTOCOL_EXPLICIT}" == "false" ]]; then
    warn "No se indicó --protocol en modo basic. Se usará UDP en el puerto ${PORT}."
  fi

  ok "Modo basic configurado con protocolo ${BASIC_PROTOCOL}."
  info "Puerto destino: ${PORT}"
}

parse_args() {
  case "${MODE}" in
    basic)
      BASIC_PROTOCOL="udp"
      PORT=""
      ;;
    tls)
      PORT="6514"
      ;;
    disable)
      ;;
    *)
      usage
      die "Modo no válido: ${MODE:-<vacío>}"
      ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --server)
        SERVER="${2:-}"
        shift 2
        ;;
      --protocol)
        [[ "${MODE}" == "basic" ]] || die "--protocol solo puede usarse en modo basic"
        BASIC_PROTOCOL="${2:-}"
        BASIC_PROTOCOL_EXPLICIT="true"
        shift 2
        ;;
      --port)
        PORT="${2:-}"
        shift 2
        ;;
      --ca)
        CA_FILE="${2:-}"
        shift 2
        ;;
      --cert)
        CERT_FILE="${2:-}"
        shift 2
        ;;
      --key)
        KEY_FILE="${2:-}"
        shift 2
        ;;
      --peer)
        PEER_NAME="${2:-}"
        shift 2
        ;;
      --run-test)
        RUN_TEST="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Opción no reconocida: $1"
        ;;
    esac
  done

  if [[ "${MODE}" == "basic" ]]; then
    [[ -n "${SERVER}" ]] || die "En modo basic debes indicar --server"
    resolve_basic_transport
  fi

  if [[ "${MODE}" == "tls" ]]; then
    [[ -n "${SERVER}" ]]    || die "En modo tls debes indicar --server"
    [[ -n "${CA_FILE}" ]]   || die "En modo tls debes indicar --ca"
    [[ -n "${CERT_FILE}" ]] || die "En modo tls debes indicar --cert"
    [[ -n "${KEY_FILE}" ]]  || die "En modo tls debes indicar --key"
    [[ -n "${PEER_NAME}" ]] || die "En modo tls debes indicar --peer"

    if ! is_valid_port "${PORT}"; then
      die "Puerto no válido en modo tls: ${PORT}"
    fi
  fi
}

timestamp() {
  date +%Y%m%d_%H%M%S
  # Devuelve marca temporal compacta para backups.
}

backup_file_if_exists() {
  local file="$1"
  # Guarda la ruta recibida.

  mkdir -p "${BACKUP_DIR}"
  # Crea directorio de backups si no existe.

  if [[ -f "${file}" ]]; then
    # Si el fichero existe...
    local dst
    dst="${BACKUP_DIR}/$(basename "${file}").$(timestamp).bak"
    # Construye nombre del backup.
    cp -a "${file}" "${dst}"
    # Hace copia conservando atributos.
    ok "Backup creado: ${dst}"
    # Informa del backup.
  fi
}

install_packages() {
  info "Actualizando índice de paquetes..."
  apt-get update -y
  # Actualiza lista de paquetes.

  info "Instalando dependencias si faltan..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    rsyslog openssl ca-certificates coreutils grep sed gawk findutils
  # Instala rsyslog y utilidades necesarias.

  ok "Dependencias instaladas o ya presentes."
}

prepare_cert_dir() {
  mkdir -p "${CERT_DIR}" "${BACKUP_DIR}" /etc/rsyslog.d
  # Crea directorio de certificados, backups y /etc/rsyslog.d si no existen.
  # Esto evita fallos en entornos mínimos o simulados.

  chmod 700 "${CERT_DIR}"
  # Permite acceso solo a root.
}

write_basic_config() {
  info "Escribiendo configuración basic de forwarding..."
  backup_file_if_exists "${FORWARD_CONF}"
  backup_file_if_exists "${TLS_CONF}"

  rm -f "${TLS_CONF}"

  local target_prefix=""
  local protocol_label=""

  case "${BASIC_PROTOCOL}" in
    tcp)
      target_prefix="@@"
      protocol_label="TCP"
      ;;
    udp)
      target_prefix="@"
      protocol_label="UDP"
      ;;
  esac

  cat > "${FORWARD_CONF}" <<EOF
# Reenvía todos los logs al servidor por ${protocol_label}.
*.* ${target_prefix}${SERVER}:${PORT}
EOF

  ok "Configuración basic escrita."
}

validate_tls_files() {
  [[ -f "${CA_FILE}" ]]   || die "No existe la CA: ${CA_FILE}"
  # Comprueba existencia de la CA.

  [[ -f "${CERT_FILE}" ]] || die "No existe el certificado cliente: ${CERT_FILE}"
  # Comprueba existencia del cert cliente.

  [[ -f "${KEY_FILE}" ]]  || die "No existe la clave cliente: ${KEY_FILE}"
  # Comprueba existencia de la clave cliente.
}

install_tls_material() {
  info "Copiando material TLS del cliente..."
  validate_tls_files
  # Verifica que los tres archivos existen.

  prepare_cert_dir
  # Prepara directorio de certificados.

  cp "${CA_FILE}"   "${CERT_DIR}/ca.crt"
  # Copia CA al directorio local.
  cp "${CERT_FILE}" "${CERT_DIR}/client.crt"
  # Copia certificado cliente.
  cp "${KEY_FILE}"  "${CERT_DIR}/client.key"
  # Copia clave privada cliente.

  chmod 644 "${CERT_DIR}/ca.crt" "${CERT_DIR}/client.crt"
  # Permisos normales para ficheros públicos.
  chmod 600 "${CERT_DIR}/client.key"
  # Permisos restringidos para la clave.

  ok "Material TLS copiado en ${CERT_DIR}"
}

write_tls_config() {
  info "Escribiendo configuración TLS de forwarding..."
  backup_file_if_exists "${TLS_CONF}"
  # Hace backup de config TLS previa si existía.
  backup_file_if_exists "${FORWARD_CONF}"
  # Hace backup de config basic previa si existía.

  rm -f "${FORWARD_CONF}"
  # Borra config basic para evitar conflicto.

  cat > "${TLS_CONF}" <<EOF
# Carga el módulo de reenvío.
module(load="omfwd")
# Carga soporte TLS.
module(load="gtls")

# Define certificados y CA a usar por rsyslog.
global(
  DefaultNetstreamDriver="gtls"
  DefaultNetstreamDriverCAFile="${CERT_DIR}/ca.crt"
  DefaultNetstreamDriverCertFile="${CERT_DIR}/client.crt"
  DefaultNetstreamDriverKeyFile="${CERT_DIR}/client.key"
)

# Define la acción de envío al servidor por TCP+TLS.
action(
  type="omfwd"
  target="${SERVER}"
  port="${PORT}"
  protocol="tcp"
  StreamDriver="gtls"
  StreamDriverMode="1"
  StreamDriverAuthMode="x509/name"
  StreamDriverPermittedPeers=["${PEER_NAME}"]
)
EOF
  # Escribe configuración TLS.

  ok "Configuración TLS escrita."
}

disable_forwarding() {
  info "Desactivando forwarding remoto sin apagar rsyslog local..."
  backup_file_if_exists "${FORWARD_CONF}"
  # Hace backup si existía config básica.
  backup_file_if_exists "${TLS_CONF}"
  # Hace backup si existía config TLS.

  rm -f "${FORWARD_CONF}" "${TLS_CONF}"
  # Borra ambas configs remotas.

  ok "Forwarding remoto desactivado."
}

validate_and_restart() {
  info "Validando configuración de rsyslog..."
  rsyslogd -N1
  # Valida la config de rsyslog.
  ok "Configuración válida."

  info "Reiniciando rsyslog..."
  systemctl restart rsyslog
  # Reinicia rsyslog.

  info "Habilitando rsyslog al arranque..."
  systemctl enable rsyslog >/dev/null 2>&1 || true
  # Activa arranque automático.

  ok "rsyslog reiniciado y habilitado."
}

run_optional_test() {
  if [[ "${RUN_TEST}" == "true" && "${MODE}" != "disable" ]]; then
    # Solo prueba si se pidió y no estamos en disable.
    info "Lanzando prueba con logger..."
    logger "SYSLOG_CLIENT_V5_TEST $(date -Iseconds)"
    # Genera mensaje local que deberá reenviarse.
    ok "Prueba generada."
  fi
}

write_report() {
  local report="/root/syslog_client_report.txt"

  info "Generando informe final..."

  {
    echo "======== SYSLOG CLIENT REPORT ========"
    echo "Fecha:            $(date -Iseconds)"
    echo "Modo:             ${MODE}"
    echo "Destino:          ${SERVER:-N/A}"

    if [[ "${MODE}" == "basic" ]]; then
      echo "Protocol:         ${BASIC_PROTOCOL}"
    fi

    echo "Puerto:           ${PORT:-N/A}"
    echo "Backup dir:       ${BACKUP_DIR}"
    echo "Cert dir:         ${CERT_DIR}"
    echo "Prueba ejecutada: ${RUN_TEST}"
    echo
    echo "Estado rsyslog:"
    systemctl is-active rsyslog || true
    echo
    echo "Ficheros activos:"
    ls -l /etc/rsyslog.d/20-forward.conf /etc/rsyslog.d/20-tls.conf 2>/dev/null || true
  } > "${report}"

  ok "Informe generado en ${report}"
}

show_summary() {
  echo
  ok "Cliente configurado correctamente."
  echo "Resumen:"
  echo "  Modo:       ${MODE}"

  if [[ "${MODE}" == "basic" ]]; then
    echo "  Protocolo:  ${BASIC_PROTOCOL}"
  fi

  if [[ "${MODE}" != "disable" ]]; then
    echo "  Destino:    ${SERVER}:${PORT}"
  fi

  echo "  Backup dir: ${BACKUP_DIR}"
  echo
}
# Muestra resumen final.

main() {
  require_root
  # Verifica permisos de root.

  parse_args "$@"
  # Procesa argumentos.

  if [[ "${MODE}" == "disable" ]]; then
    # Si el modo es disable...
    disable_forwarding
    # Quita forwarding remoto.
    validate_and_restart
    # Valida y reinicia rsyslog.
    write_report
    # Genera informe final.
    show_summary
    # Muestra resumen.
    exit 0
    # Sale correctamente.
  fi

  install_packages
  # Instala dependencias.

  if [[ "${MODE}" == "basic" ]]; then
    # Si modo basic...
    write_basic_config
    # Escribe config básica.
  else
    # Si modo tls...
    install_tls_material
    # Copia certificados y claves.
    write_tls_config
    # Escribe config TLS.
  fi

  validate_and_restart
  # Valida y reinicia rsyslog.

  run_optional_test
  # Ejecuta prueba si se pidió.

  write_report
  # Genera informe.

  show_summary
  # Muestra resumen final.
}

main "$@"
# Ejecuta la función principal.
