#!/usr/bin/env bash
# Usa bash para ejecutar este script.

set -euo pipefail
# -e: si un comando falla, el script termina.
# -u: si usas una variable no definida, el script falla.
# -o pipefail: si falla un comando dentro de una tubería, se detecta el error.

#
# setup_syslog_server_v5.sh
#
# Propósito:
#   Desplegar un servidor syslog en Ubuntu Server en modo basic o tls.
#
# Modos:
#   basic -> recepción por UDP, TCP o ambos + filtrado UFW por IP
#   tls   -> recepción por TCP + TLS/mTLS + certificados
#
# Uso:
#   sudo bash scripts/setup_syslog_server_v5.sh basic --allowed-ips 172.16.3.3
#   sudo bash scripts/setup_syslog_server_v5.sh tls --allowed-ips 172.16.3.3 --server-ip 172.16.3.2 --tls-clients kali01
#
# Compatibilidad:
#   Ubuntu Server, Debian/Ubuntu recientes con systemd y rsyslog
#
# Notas:
#   - Hace backups de configuraciones previas
#   - Intenta ser idempotente
#   - No subas claves ni certificados al repositorio

MODE="${1:-}"
# Guarda el primer argumento del script.
# Será "basic" o "tls".

shift || true
# Elimina el primer argumento de la lista.
# "|| true" evita que falle si no hay más argumentos.

PORT=""
# Puerto del modo tls.

BASIC_PROTOCOL="udp"
# Protocolo del modo basic: udp, tcp o both.

BASIC_PORT=""
# Puerto genérico del modo basic cuando se usa un solo protocolo
# o cuando se quiere el mismo puerto para tcp y udp a la vez.

BASIC_TCP_PORT=""
# Puerto TCP del modo basic.

BASIC_UDP_PORT=""
# Puerto UDP del modo basic.

BASIC_PROTOCOL_EXPLICIT="false"
# Indica si el usuario ha especificado --protocol.

ALLOWED_IPS=""
# Lista de IPs permitidas por firewall, separadas por comas.

SERVER_NAME="syslog.local"
# Nombre principal del certificado del servidor (CN).

SERVER_IP=""
# IP del servidor.
# Se usa para meterla como SAN en el certificado TLS.

SERVER_SANS=""
# Nombres DNS extra para SAN del certificado del servidor.

TLS_CLIENTS=""
# Lista de nombres de clientes TLS permitidos, separados por comas.

LOG_DIR="/var/log/remote"
# Directorio donde se guardarán los logs remotos.

CERT_DIR="/etc/rsyslog-certs"
# Directorio donde se guardan certificados y claves.

EXPORT_DIR="/root/syslog-client-bundles"
# Directorio donde se exportan bundles TLS por cliente.

BACKUP_DIR="/root/syslog_setup_backups"
# Directorio para copias de seguridad de configuraciones.

REMOTE_CONF="/etc/rsyslog.d/10-remote.conf"
# Fichero de configuración rsyslog para modo basic.

TLS_CONF="/etc/rsyslog.d/10-tls.conf"
# Fichero de configuración rsyslog para modo tls.

LOGROTATE_CONF="/etc/logrotate.d/syslog-remote"
# Fichero de rotación de logs remotos.

REGENERATE_CERTS="false"
# Si vale true, se regeneran certificados.

RUN_TEST="false"
# Si vale true, se lanza una prueba local con logger.

KEEP_UFW_RULES="false"
# Si vale true, conserva reglas ALLOW antiguas de UFW y solo añade las nuevas.

UFW_RULE_COMMENT="syslog-server-v5"
# Comentario usado en reglas UFW creadas por este script.

UFW_CLEANUP_TARGETS=()
# Lista de puerto/protocolo sobre los que se limpiarán reglas ALLOW antiguas.

info()  { echo "[INFO]  $*"; }
# Función para mostrar mensajes informativos.

ok()    { echo "[OK]    $*"; }
# Función para mostrar mensajes de éxito.

warn()  { echo "[WARN]  $*"; }
# Función para mostrar avisos.

error() { echo "[ERROR] $*" >&2; }
# Función para mostrar errores por stderr.

die() {
  error "$*"
  # Muestra el error recibido.
  exit 1
  # Sale del script con código de error.
}

usage() {
  cat <<'EOF'
Uso:

  Modo basic con valores por defecto:
    sudo bash scripts/setup_syslog_server_v5.sh basic \
      --allowed-ips 172.16.3.3,172.16.3.11

    Si no indicas --protocol ni --port:
      - se usa udp
      - se usa el puerto 10514

  Modo basic indicando protocolo:
    sudo bash scripts/setup_syslog_server_v5.sh basic \
      --allowed-ips 172.16.3.3,172.16.3.11 \
      --protocol tcp \
      [--port 10514] \
      [--keep] \
      [--run-test]

    Protocolos válidos:
      --protocol udp
      --protocol tcp
      --protocol both

  Modo basic con ambos protocolos y mismo puerto:
    sudo bash scripts/setup_syslog_server_v5.sh basic \
      --allowed-ips 172.16.3.3,172.16.3.11 \
      --protocol both \
      --port 10514 \
      [--keep] \
      [--run-test]

  Modo basic con ambos protocolos y puertos distintos:
    sudo bash scripts/setup_syslog_server_v5.sh basic \
      --allowed-ips 172.16.3.3,172.16.3.11 \
      --protocol both \
      --tcp-port 10514 \
      --udp-port 5514 \
      [--keep] \
      [--run-test]

  Modo tls:
    sudo bash scripts/setup_syslog_server_v5.sh tls \
      --allowed-ips 172.16.3.3,172.16.3.11 \
      --port 6514 \
      --server-name syslog.local \
      --server-ip 172.16.3.2 \
      --server-sans syslog01.empresa.local,logs.local \
      --tls-clients kali01,ubuntu01 \
      [--export-dir /root/syslog-client-bundles] \
      [--regenerate-certs] \
      [--keep] \
      [--run-test]

  Firewall:
    Por defecto, antes de aplicar reglas nuevas, el script limpia reglas ALLOW
    antiguas relacionadas con este servicio syslog para los puertos/protocolos
    detectados. Usa --keep si quieres conservar reglas antiguas.
EOF
}
# Función que muestra cómo usar el script.

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Ejecuta este script con sudo o como root."
  # Comprueba que el usuario actual sea root.
  # EUID=0 significa root.
}

is_valid_port() {
  local port="$1"
  [[ "${port}" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
}

resolve_basic_transport() {
  [[ "${MODE}" == "basic" ]] || return 0

  case "${BASIC_PROTOCOL}" in
    udp|tcp|both) ;;
    *)
      die "En modo basic, --protocol debe ser udp, tcp o both"
      ;;
  esac

  if [[ -n "${BASIC_PORT}" ]] && ! is_valid_port "${BASIC_PORT}"; then
    die "Puerto no válido en --port: ${BASIC_PORT}"
  fi

  if [[ -n "${BASIC_TCP_PORT}" ]] && ! is_valid_port "${BASIC_TCP_PORT}"; then
    die "Puerto no válido en --tcp-port: ${BASIC_TCP_PORT}"
  fi

  if [[ -n "${BASIC_UDP_PORT}" ]] && ! is_valid_port "${BASIC_UDP_PORT}"; then
    die "Puerto no válido en --udp-port: ${BASIC_UDP_PORT}"
  fi

  if [[ "${BASIC_PROTOCOL}" != "both" ]] && [[ -n "${BASIC_TCP_PORT}" || -n "${BASIC_UDP_PORT}" ]]; then
    die "Los parámetros --tcp-port y --udp-port solo pueden usarse con --protocol both"
  fi

  case "${BASIC_PROTOCOL}" in
    udp)
      if [[ -z "${BASIC_PORT}" ]]; then
        BASIC_PORT="10514"
        if [[ "${BASIC_PROTOCOL_EXPLICIT}" == "true" ]]; then
          warn "No se indicó --port en modo basic con protocolo udp. Se usará UDP en el puerto 10514."
        else
          warn "No se indicó --protocol ni --port en modo basic. Se usará UDP en el puerto 10514."
        fi
      elif [[ "${BASIC_PROTOCOL_EXPLICIT}" == "false" ]]; then
        warn "No se indicó --protocol en modo basic. Se usará UDP en el puerto ${BASIC_PORT}."
      fi

      BASIC_UDP_PORT="${BASIC_PORT}"
      BASIC_TCP_PORT=""
      ;;
    tcp)
      if [[ -z "${BASIC_PORT}" ]]; then
        BASIC_PORT="10514"
        warn "No se indicó --port en modo basic con protocolo tcp. Se usará TCP en el puerto 10514."
      fi

      BASIC_TCP_PORT="${BASIC_PORT}"
      BASIC_UDP_PORT=""
      ;;
    both)
      if [[ -z "${BASIC_PORT}" && -z "${BASIC_TCP_PORT}" && -z "${BASIC_UDP_PORT}" ]]; then
        BASIC_TCP_PORT="10514"
        BASIC_UDP_PORT="10514"
        warn "No se indicaron puertos en modo basic con protocolo both. Se usarán TCP 10514 y UDP 10514."
      else
        if [[ -z "${BASIC_TCP_PORT}" ]]; then
          if [[ -n "${BASIC_PORT}" ]]; then
            BASIC_TCP_PORT="${BASIC_PORT}"
          else
            BASIC_TCP_PORT="10514"
            warn "No se indicó --tcp-port en modo basic con protocolo both. Se usará TCP en el puerto 10514."
          fi
        fi

        if [[ -z "${BASIC_UDP_PORT}" ]]; then
          if [[ -n "${BASIC_PORT}" ]]; then
            BASIC_UDP_PORT="${BASIC_PORT}"
          else
            BASIC_UDP_PORT="10514"
            warn "No se indicó --udp-port en modo basic con protocolo both. Se usará UDP en el puerto 10514."
          fi
        fi
      fi
      ;;
  esac

  ok "Modo basic configurado con protocolo ${BASIC_PROTOCOL}."
  case "${BASIC_PROTOCOL}" in
    udp)
      info "Puerto UDP: ${BASIC_UDP_PORT}"
      ;;
    tcp)
      info "Puerto TCP: ${BASIC_TCP_PORT}"
      ;;
    both)
      info "Puerto TCP: ${BASIC_TCP_PORT}"
      info "Puerto UDP: ${BASIC_UDP_PORT}"
      ;;
  esac
}

show_listening_sockets() {
  if [[ "${MODE}" == "basic" ]]; then
    case "${BASIC_PROTOCOL}" in
      udp)
        ss -ulpn | grep -E ":${BASIC_UDP_PORT}\b"
        ;;
      tcp)
        ss -tlpn | grep -E ":${BASIC_TCP_PORT}\b"
        ;;
      both)
        ss -tulpn | grep -E ":(${BASIC_TCP_PORT}|${BASIC_UDP_PORT})\b"
        ;;
    esac
  else
    ss -tulpn | grep -E ":${PORT}\b"
  fi
}

add_ufw_cleanup_target() {
  local port="$1"
  # Puerto que queremos revisar o limpiar en UFW.
  local proto="$2"
  # Protocolo asociado al puerto: tcp o udp.
  local target="${port}/${proto}"
  # Normaliza el objetivo como "puerto/protocolo", igual que lo muestra UFW.

  [[ -n "${port}" && -n "${proto}" ]] || return 0
  # Si falta algún valor, no añadimos nada. Esto evita targets incompletos.

  for existing in "${UFW_CLEANUP_TARGETS[@]}"; do
    # Evita duplicados cuando el puerto actual coincide con uno antiguo.
    [[ "${existing}" == "${target}" ]] && return 0
  done

  UFW_CLEANUP_TARGETS+=("${target}")
  # Añade el objetivo final a la lista global de limpieza.
}

collect_current_ufw_cleanup_targets() {
  # Recoge los puertos/protocolos que el usuario quiere dejar activos
  # en esta ejecución del script.
  if [[ "${MODE}" == "basic" ]]; then
    case "${BASIC_PROTOCOL}" in
      udp)
        add_ufw_cleanup_target "${BASIC_UDP_PORT}" "udp"
        ;;
      tcp)
        add_ufw_cleanup_target "${BASIC_TCP_PORT}" "tcp"
        ;;
      both)
        add_ufw_cleanup_target "${BASIC_TCP_PORT}" "tcp"
        add_ufw_cleanup_target "${BASIC_UDP_PORT}" "udp"
        ;;
    esac
  else
    add_ufw_cleanup_target "${PORT}" "tcp"
    # TLS siempre escucha sobre TCP.
  fi
}

collect_existing_ufw_cleanup_targets() {
  local port
  # Puerto encontrado al leer configuraciones rsyslog anteriores.

  if [[ -f "${REMOTE_CONF}" ]]; then
    # Si existe una configuración basic anterior, extraemos los puertos UDP
    # y TCP que quedaron configurados en rsyslog antes de sobrescribirla.
    while IFS= read -r port; do
      add_ufw_cleanup_target "${port}" "udp"
    done < <(sed -n 's/.*input(type="imudp".*port="\([0-9][0-9]*\)".*/\1/p' "${REMOTE_CONF}")

    while IFS= read -r port; do
      add_ufw_cleanup_target "${port}" "tcp"
    done < <(sed -n 's/.*input(type="imtcp".*port="\([0-9][0-9]*\)".*/\1/p' "${REMOTE_CONF}")
  fi

  if [[ -f "${TLS_CONF}" ]]; then
    # Si existe una configuración TLS anterior, extraemos su puerto TCP.
    # Esto cubre cambios de tls a basic, cambios de puerto o reinstalaciones.
    while IFS= read -r port; do
      add_ufw_cleanup_target "${port}" "tcp"
    done < <(sed -n 's/.*port="\([0-9][0-9]*\)".*/\1/p' "${TLS_CONF}")
  fi
}

collect_ufw_cleanup_targets() {
  UFW_CLEANUP_TARGETS=()

  collect_current_ufw_cleanup_targets
  # Añade los puertos/protocolos que se van a dejar configurados.

  collect_existing_ufw_cleanup_targets
  # Añade puertos/protocolos de configuraciones anteriores para poder retirar
  # reglas ALLOW obsoletas cuando cambia el protocolo, el puerto o el modo.
}

collect_ufw_allow_rule_numbers_for_cleanup() {
  local status
  # Salida completa de "ufw status numbered".
  local target
  # Objetivo "puerto/protocolo" que se está evaluando.
  local port
  local proto
  local line
  # Línea individual del estado numerado de UFW.
  local number
  # Número de regla UFW que luego se puede borrar de forma segura.

  status="$(ufw status numbered 2>/dev/null || true)"
  # Si UFW no está activo o no puede listar reglas, no abortamos aquí.
  # La creación de reglas nuevas se intenta más adelante.

  for target in "${UFW_CLEANUP_TARGETS[@]}"; do
    port="${target%/*}"
    proto="${target#*/}"

    while IFS= read -r line; do
      if [[ "${line}" =~ ^\[\ *([0-9]+)\]\ +${port}/${proto}([[:space:]]|$) ]]; then
        number="${BASH_REMATCH[1]}"
        # Guardamos el número antes de otra regex porque Bash sobrescribe
        # BASH_REMATCH en cada comparación.

        if [[ "${line}" =~ [[:space:]]ALLOW([[:space:]]|$) ]]; then
          echo "${number}"
          # Sólo devolvemos reglas ALLOW. Las DENY, SSH u otros servicios
          # no deben borrarse durante esta limpieza.
        fi
      fi
    done <<< "${status}"
  done
}

confirm_ufw_cleanup() {
  local answer
  # Respuesta interactiva del usuario.

  warn "Se van a eliminar reglas UFW antiguas relacionadas con este servicio syslog para dejar solo las IPs actuales definidas en --allowed-ips."
  warn "Si quieres conservar reglas antiguas, vuelve a ejecutar el script con --keep."
  printf "¿Deseas continuar? [y/N] "

  if ! read -r answer; then
    # En ejecución no interactiva, fallar es más seguro que borrar reglas sin
    # confirmación explícita.
    die "No se pudo leer confirmación. Limpieza UFW cancelada."
  fi

  case "${answer}" in
    y|Y|yes|YES|s|S|si|SI|sí|SÍ)
      ;;
    *)
      die "Limpieza UFW cancelada por el usuario."
      ;;
  esac
}

cleanup_old_ufw_allow_rules() {
  local rule_numbers=()
  # Números de reglas UFW antiguas que se van a eliminar.
  local number
  # Número individual procesado en el bucle de borrado.

  if [[ "${KEEP_UFW_RULES}" == "true" ]]; then
    info "Opción --keep detectada: se conservarán reglas ALLOW antiguas de UFW."
    return 0
  fi

  warn "Se comprobarán reglas ALLOW antiguas de UFW para los puertos/protocolos syslog gestionados por este script."

  mapfile -t rule_numbers < <(collect_ufw_allow_rule_numbers_for_cleanup | sort -n -u)
  # Ordena y elimina duplicados antes de borrar. Un mismo puerto/protocolo puede
  # aparecer como objetivo actual y como objetivo heredado de una configuración previa.

  if [[ "${#rule_numbers[@]}" -eq 0 ]]; then
    ok "No se encontraron reglas ALLOW antiguas de UFW que limpiar."
    return 0
  fi

  confirm_ufw_cleanup

  while IFS= read -r number; do
    [[ -n "${number}" ]] || continue

    if ufw --force delete "${number}" >/dev/null 2>&1; then
      ok "Regla UFW antigua eliminada: número ${number}"
    else
      die "No se pudo eliminar la regla UFW antigua número ${number}."
    fi
  done < <(printf '%s\n' "${rule_numbers[@]}" | sort -rn)
  # Borramos en orden descendente porque UFW renumera las reglas después de
  # cada delete. Si borrásemos de menor a mayor, podríamos eliminar otra regla.
}

first_ufw_deny_rule_number_for_target() {
  local port="$1"
  # Puerto syslog que se está configurando.
  local proto="$2"
  # Protocolo asociado al puerto.
  local line
  # Línea individual de "ufw status numbered".
  local number
  # Número de la primera regla DENY encontrada para ese puerto/protocolo.

  while IFS= read -r line; do
    if [[ "${line}" =~ ^\[\ *([0-9]+)\]\ +${port}/${proto}([[:space:]]|$) ]]; then
      number="${BASH_REMATCH[1]}"
      # Guardamos el número antes de evaluar otra expresión regular.

      if [[ "${line}" =~ [[:space:]]DENY([[:space:]]|$) ]]; then
        echo "${number}"
        return 0
      fi
    fi
  done < <(ufw status numbered 2>/dev/null || true)
}

apply_ufw_allow_rule() {
  local ip="$1"
  # IP cliente que se va a permitir.
  local port="$2"
  # Puerto syslog que se va a permitir.
  local proto="$3"
  # Protocolo asociado al puerto.
  local insert_at
  # Posición de la primera regla DENY general para insertar antes.

  insert_at="$(first_ufw_deny_rule_number_for_target "${port}" "${proto}")"

  if [[ -n "${insert_at}" ]]; then
    # UFW evalúa reglas en orden. Si ya existe un DENY general, el ALLOW
    # específico debe insertarse antes para que tenga efecto.
    if ufw insert "${insert_at}" allow from "${ip}" to any port "${port}" proto "${proto}" comment "${UFW_RULE_COMMENT}" >/dev/null 2>&1; then
      return 0
    fi

    ufw insert "${insert_at}" allow from "${ip}" to any port "${port}" proto "${proto}" >/dev/null 2>&1
    return $?
  fi

  if ufw allow from "${ip}" to any port "${port}" proto "${proto}" comment "${UFW_RULE_COMMENT}" >/dev/null 2>&1; then
    return 0
  fi

  ufw allow from "${ip}" to any port "${port}" proto "${proto}" >/dev/null 2>&1
}

ensure_ufw_rules_for_port() {
  local port="$1"
  # Puerto syslog que se va a permitir.
  local proto="$2"
  # Protocolo asociado al puerto.
  local ips=()
  # IPs permitidas convertidas desde el CSV recibido por --allowed-ips.

  csv_to_array "${ALLOWED_IPS}" ips

  for ip in "${ips[@]}"; do
    if ! apply_ufw_allow_rule "${ip}" "${port}" "${proto}"; then
      die "No se pudo aplicar la regla UFW para ${ip}:${port}/${proto}"
    fi

    ok "Regla UFW aplicada para ${ip}:${port}/${proto}"
  done

  ufw deny "${port}/${proto}" >/dev/null 2>&1 || true
  # Mantiene una regla DENY general para el puerto/protocolo. Se añade después
  # de los ALLOW específicos, o los ALLOW se insertan delante si ya existía.
}

parse_args() {
  case "${MODE}" in
    basic)
      BASIC_PROTOCOL="udp"
      ;;
    tls)
      PORT="6514"
      ;;
    *)
      usage
      die "Modo no válido: ${MODE:-<vacío>}"
      ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --allowed-ips)
        ALLOWED_IPS="${2:-}"
        shift 2
        ;;
      --protocol)
        [[ "${MODE}" == "basic" ]] || die "--protocol solo puede usarse en modo basic"
        BASIC_PROTOCOL="${2:-}"
        BASIC_PROTOCOL_EXPLICIT="true"
        shift 2
        ;;
      --port)
        if [[ "${MODE}" == "basic" ]]; then
          BASIC_PORT="${2:-}"
        else
          PORT="${2:-}"
        fi
        shift 2
        ;;
      --tcp-port)
        [[ "${MODE}" == "basic" ]] || die "--tcp-port solo puede usarse en modo basic"
        BASIC_TCP_PORT="${2:-}"
        shift 2
        ;;
      --udp-port)
        [[ "${MODE}" == "basic" ]] || die "--udp-port solo puede usarse en modo basic"
        BASIC_UDP_PORT="${2:-}"
        shift 2
        ;;
      --server-name)
        SERVER_NAME="${2:-}"
        shift 2
        ;;
      --server-ip)
        SERVER_IP="${2:-}"
        shift 2
        ;;
      --server-sans)
        SERVER_SANS="${2:-}"
        shift 2
        ;;
      --tls-clients)
        TLS_CLIENTS="${2:-}"
        shift 2
        ;;
      --export-dir)
        EXPORT_DIR="${2:-}"
        shift 2
        ;;
      --regenerate-certs)
        REGENERATE_CERTS="true"
        shift
        ;;
      --keep)
        KEEP_UFW_RULES="true"
        shift
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

  [[ -n "${ALLOWED_IPS}" ]] || die "Debes indicar --allowed-ips"

  if [[ "${MODE}" == "basic" ]]; then
    resolve_basic_transport
  fi

  if [[ "${MODE}" == "tls" ]]; then
    [[ -n "${SERVER_IP}" ]] || die "En modo tls debes indicar --server-ip"
    [[ -n "${TLS_CLIENTS}" ]] || die "En modo tls debes indicar --tls-clients"

    if ! is_valid_port "${PORT}"; then
      die "Puerto no válido en modo tls: ${PORT}"
    fi
  fi
}

timestamp() {
  date +%Y%m%d_%H%M%S
  # Devuelve fecha y hora compacta para nombres de backup.
}

backup_file_if_exists() {
  local file="$1"
  # Guarda la ruta del fichero recibido.

  mkdir -p "${BACKUP_DIR}"
  # Crea el directorio de backups si no existe.

  if [[ -f "${file}" ]]; then
    # Comprueba si el fichero existe.
    local dst
    dst="${BACKUP_DIR}/$(basename "${file}").$(timestamp).bak"
    # Construye el nombre del backup.
    cp -a "${file}" "${dst}"
    # Copia conservando atributos.
    ok "Backup creado: ${dst}"
    # Informa del backup creado.
  fi
}

csv_to_array() {
  local csv="$1"
  # Guarda el CSV recibido.
  local out_arr_name="$2"
  # Guarda el nombre del array de salida.
  local -n result_array_ref="${out_arr_name}"
  # Crea una referencia al array de salida.

  IFS=',' read -r -a raw <<< "${csv}"
  # Divide el CSV por comas y lo mete en el array raw.

  result_array_ref=()
  # Inicializa el array de salida vacío.

  for item in "${raw[@]}"; do
    # Recorre cada elemento del CSV.
    item="$(echo "${item}" | xargs)"
    # Elimina espacios al principio y al final.
    [[ -n "${item}" ]] && result_array_ref+=("${item}")
    # Si no está vacío, lo añade al array final.
  done
}

install_packages() {
  info "Actualizando índice de paquetes..."
  apt-get update -y
  # Actualiza la lista de paquetes disponibles.

  info "Instalando dependencias si faltan..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    rsyslog ufw openssl ca-certificates coreutils grep sed gawk findutils util-linux
  # Instala:
  # rsyslog: servicio syslog.
  # ufw: firewall sencillo.
  # openssl: generación de certificados.
  # ca-certificates: soporte de certificados del sistema.
  # coreutils, grep, sed, gawk, findutils: utilidades usadas por el script.

  ok "Dependencias instaladas o ya presentes."
}

prepare_directories() {
  info "Preparando directorios..."
  mkdir -p "${LOG_DIR}" "${CERT_DIR}" "${EXPORT_DIR}" "${BACKUP_DIR}" /etc/rsyslog.d /etc/logrotate.d
  # Crea directorios necesarios si no existen.
  # Añade también /etc/rsyslog.d y /etc/logrotate.d para entornos mínimos o simulados.

  if getent passwd syslog >/dev/null 2>&1 && getent group adm >/dev/null 2>&1; then
    # Comprueba que existen el usuario syslog y el grupo adm.
    chown syslog:adm "${LOG_DIR}"
    # Pone como dueño syslog y grupo adm al directorio de logs remotos.
  else
    warn "No se encontró syslog:adm todavía; se dejan permisos del directorio sin chown específico."
    # Avisa si por algún motivo no existe aún el usuario/grupo esperado.
  fi

  chmod 750 "${LOG_DIR}"
  # Permisos 750:
  # dueño rwx, grupo r-x, otros sin permisos.

  chmod 700 "${CERT_DIR}"
  # Permisos 700:
  # solo root puede acceder a certificados.

  chmod 700 "${EXPORT_DIR}"
  # Solo root accede al directorio de bundles exportados.

  ok "Directorios preparados."
}

check_log_mountpoint() {
  if ! mountpoint -q "${LOG_DIR}"; then
    warn "${LOG_DIR} no es un punto de montaje independiente. Los logs se guardarán en el disco del sistema."
  else
    ok "${LOG_DIR} está montado como punto de montaje independiente."
  fi
}

write_logrotate() {
  info "Configurando rotación de logs remotos..."
  backup_file_if_exists "${LOGROTATE_CONF}"
  # Hace backup si ya existía una config previa.

  cat > "${LOGROTATE_CONF}" <<EOF
${LOG_DIR}/*/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    copytruncate
}
EOF
  # Escribe configuración de logrotate:
  # daily: rota cada día.
  # rotate 14: guarda 14 rotaciones.
  # compress: comprime logs antiguos.
  # missingok: no falla si faltan archivos.
  # notifempty: no rota si está vacío.
  # copytruncate: copia y trunca sin reiniciar procesos.

  ok "Logrotate configurado."
}

build_json_array_like() {
  local csv="$1"
  # Guarda CSV recibido.
  local result=""
  # Inicializa la salida.
  local items=()
  # Array temporal.
  csv_to_array "${csv}" items
  # Convierte CSV a array.

  for item in "${items[@]}"; do
    # Recorre cada elemento.
    if [[ -z "${result}" ]]; then
      result="\"${item}\""
      # Primer elemento.
    else
      result="${result},\"${item}\""
      # Resto de elementos.
    fi
  done

  echo "${result}"
  # Devuelve una cadena tipo:
  # "kali01","ubuntu01"
}

build_server_extfile() {
  local ext_file="${CERT_DIR}/server_ext.cnf"
  # Ruta del fichero de extensión OpenSSL del servidor.

  info "Generando extensión OpenSSL del servidor con SAN..."

  {
    echo "authorityKeyIdentifier=keyid,issuer"
    # Añade referencia a la CA emisora.

    echo "basicConstraints=CA:FALSE"
    # Indica que este certificado no es una CA.

    echo "keyUsage=digitalSignature,keyEncipherment"
    # Permite firma digital y cifrado de clave.

    echo "extendedKeyUsage=serverAuth"
    # Marca este certificado para autenticación de servidor.

    echo "subjectAltName=@alt_names"
    # Indica que SAN se define en el bloque alt_names.

    echo
    echo "[alt_names]"
    # Empieza el bloque SAN.

    echo "DNS.1=${SERVER_NAME}"
    # Mete el nombre principal del servidor como SAN DNS.

    local dns_idx=2
    # Índice para siguientes SAN DNS.

    local sans=()
    # Array temporal para SAN extra.
    csv_to_array "${SERVER_SANS}" sans
    # Convierte SANs extra a array.

    for san in "${sans[@]}"; do
      echo "DNS.${dns_idx}=${san}"
      # Añade cada SAN DNS extra.
      dns_idx=$((dns_idx + 1))
      # Incrementa índice.
    done

    echo "IP.1=${SERVER_IP}"
    # Añade la IP del servidor como SAN IP.
  } > "${ext_file}"
  # Redirige todo al fichero de extensión.

  ok "Extensión SAN del servidor generada."
}

build_client_extfile() {
  local client_name="$1"
  # Guarda el nombre del cliente.
  local ext_file="${CERT_DIR}/${client_name}_ext.cnf"
  # Ruta del fichero de extensión del cliente.

  {
    echo "authorityKeyIdentifier=keyid,issuer"
    # Referencia a la CA.
    echo "basicConstraints=CA:FALSE"
    # El cliente no es una CA.
    echo "keyUsage=digitalSignature,keyEncipherment"
    # Uso típico para TLS cliente.
    echo "extendedKeyUsage=clientAuth"
    # Marca el certificado para autenticación de cliente.
    echo "subjectAltName=@alt_names"
    # SAN definido en bloque siguiente.
    echo
    echo "[alt_names]"
    # Inicio del bloque SAN.
    echo "DNS.1=${client_name}"
    # Mete el nombre del cliente como SAN DNS.
  } > "${ext_file}"
  # Escribe el fichero.
}

remove_old_certs_if_requested() {
  if [[ "${REGENERATE_CERTS}" == "true" ]]; then
    # Solo actúa si se pidió regeneración.
    warn "Se ha solicitado regeneración de certificados."

    local cert_backup_dir
    cert_backup_dir="${BACKUP_DIR}/certs_$(timestamp)"
    # Crea nombre de backup para certificados.

    mkdir -p "${cert_backup_dir}"
    # Crea el directorio.

    cp -a "${CERT_DIR}/." "${cert_backup_dir}/" 2>/dev/null || true
    # Copia certificados antiguos si existen.

    find "${CERT_DIR}" -mindepth 1 -maxdepth 1 -type f -delete
    # Borra de forma robusta los archivos del directorio de certificados.

    ok "Certificados anteriores eliminados tras backup."
  fi
}

generate_ca() {
  if [[ ! -f "${CERT_DIR}/ca.key" || ! -f "${CERT_DIR}/ca.crt" ]]; then
    # Solo genera la CA si no existe.
    info "Generando CA..."

    openssl genrsa -out "${CERT_DIR}/ca.key" 2048
    # Genera clave privada RSA de 2048 bits para la CA.

    openssl req -x509 -new -nodes \
      -key "${CERT_DIR}/ca.key" \
      -sha256 -days 825 \
      -subj "/CN=Syslog-CA" \
      -out "${CERT_DIR}/ca.crt"
    # Genera certificado autofirmado de la CA.

    ok "CA generada."
  else
    ok "CA ya existente. Se reutiliza."
  fi
}

generate_server_cert() {
  build_server_extfile
  # Genera fichero de extensión SAN del servidor.

  if [[ ! -f "${CERT_DIR}/server.key" || ! -f "${CERT_DIR}/server.crt" ]]; then
    info "Generando certificado del servidor..."

    openssl genrsa -out "${CERT_DIR}/server.key" 2048
    # Genera clave privada del servidor.

    openssl req -new \
      -key "${CERT_DIR}/server.key" \
      -subj "/CN=${SERVER_NAME}" \
      -out "${CERT_DIR}/server.csr"
    # Genera CSR del servidor.

    openssl x509 -req \
      -in "${CERT_DIR}/server.csr" \
      -CA "${CERT_DIR}/ca.crt" \
      -CAkey "${CERT_DIR}/ca.key" \
      -CAcreateserial \
      -out "${CERT_DIR}/server.crt" \
      -days 825 -sha256 \
      -extfile "${CERT_DIR}/server_ext.cnf"
    # Firma el certificado del servidor con la CA usando SAN.

    ok "Certificado del servidor generado."
  else
    ok "Certificado del servidor ya existente. Se reutiliza."
  fi
}

generate_client_certs() {
  local clients=()
  # Array para clientes.
  csv_to_array "${TLS_CLIENTS}" clients
  # Convierte CSV de clientes a array.

  for client in "${clients[@]}"; do
    # Recorre cada cliente TLS permitido.
    build_client_extfile "${client}"
    # Genera su fichero de extensión SAN.

    if [[ ! -f "${CERT_DIR}/${client}.key" || ! -f "${CERT_DIR}/${client}.crt" ]]; then
      info "Generando certificado del cliente ${client}..."

      openssl genrsa -out "${CERT_DIR}/${client}.key" 2048
      # Genera clave privada del cliente.

      openssl req -new \
        -key "${CERT_DIR}/${client}.key" \
        -subj "/CN=${client}" \
        -out "${CERT_DIR}/${client}.csr"
      # Genera CSR del cliente.

      openssl x509 -req \
        -in "${CERT_DIR}/${client}.csr" \
        -CA "${CERT_DIR}/ca.crt" \
        -CAkey "${CERT_DIR}/ca.key" \
        -CAcreateserial \
        -out "${CERT_DIR}/${client}.crt" \
        -days 825 -sha256 \
        -extfile "${CERT_DIR}/${client}_ext.cnf"
      # Firma el certificado del cliente con la CA.

      ok "Certificado del cliente ${client} generado."
    else
      ok "Certificado del cliente ${client} ya existente. Se reutiliza."
    fi
  done

  chmod 600 "${CERT_DIR}"/*.key
  # Protege claves privadas.
  chmod 644 "${CERT_DIR}"/*.crt
  # Permisos normales para certificados públicos.
}

export_client_bundles() {
  local clients=()
  # Array temporal de clientes.
  csv_to_array "${TLS_CLIENTS}" clients
  # Convierte CSV a array.

  info "Exportando bundles TLS por cliente..."

  for client in "${clients[@]}"; do
    # Recorre clientes.
    local client_dir="${EXPORT_DIR}/${client}"
    # Directorio de exportación del cliente.

    mkdir -p "${client_dir}"
    # Lo crea si no existe.

    cp -f "${CERT_DIR}/ca.crt" "${client_dir}/ca.crt"
    # Copia CA.
    cp -f "${CERT_DIR}/${client}.crt" "${client_dir}/client.crt"
    # Copia cert cliente.
    cp -f "${CERT_DIR}/${client}.key" "${client_dir}/client.key"
    # Copia clave cliente.

    chmod 644 "${client_dir}/ca.crt" "${client_dir}/client.crt"
    # Permisos de lectura para archivos públicos.
    chmod 600 "${client_dir}/client.key"
    # Permiso restringido para la clave privada.

    ok "Bundle exportado para ${client}: ${client_dir}"
  done
}

write_basic_config() {
  info "Escribiendo configuración rsyslog en modo basic..."
  backup_file_if_exists "${REMOTE_CONF}"
  backup_file_if_exists "${TLS_CONF}"

  rm -f "${TLS_CONF}"

  {
    echo "# Configuración basic de recepción syslog."

    if [[ "${BASIC_PROTOCOL}" == "udp" || "${BASIC_PROTOCOL}" == "both" ]]; then
      echo 'module(load="imudp")'
    fi

    if [[ "${BASIC_PROTOCOL}" == "tcp" || "${BASIC_PROTOCOL}" == "both" ]]; then
      echo 'module(load="imtcp")'
    fi

    echo
    echo "# Plantilla dinámica basada en IP y programa."
    echo "template(name=\"RemoteLogs\" type=\"string\" string=\"${LOG_DIR}/%FROMHOST-IP%/%PROGRAMNAME%.log\")"
    echo
    echo "# Define un ruleset separado para logs remotos."
    echo 'ruleset(name="remote_store") {'
    echo '    action(type="omfile" DynaFile="RemoteLogs" createDirs="on" DirCreateMode="0750" FileCreateMode="0640")'
    echo '    stop'
    echo '}'
    echo

    if [[ "${BASIC_PROTOCOL}" == "udp" || "${BASIC_PROTOCOL}" == "both" ]]; then
      echo "# Input UDP asociado al ruleset remoto."
      echo "input(type=\"imudp\" port=\"${BASIC_UDP_PORT}\" ruleset=\"remote_store\")"
      echo
    fi

    if [[ "${BASIC_PROTOCOL}" == "tcp" || "${BASIC_PROTOCOL}" == "both" ]]; then
      echo "# Input TCP asociado al ruleset remoto."
      echo "input(type=\"imtcp\" port=\"${BASIC_TCP_PORT}\" ruleset=\"remote_store\")"
    fi
  } > "${REMOTE_CONF}"

  ok "Configuración basic escrita."
}

write_tls_config() {
  info "Escribiendo configuración rsyslog en modo tls..."
  backup_file_if_exists "${TLS_CONF}"
  # Hace backup de config TLS previa si existe.
  backup_file_if_exists "${REMOTE_CONF}"
  # Hace backup de config basic previa si existe, por si vienes de ese modo.

  rm -f "${REMOTE_CONF}"
  # Elimina config basic para evitar conflictos.

  local permitted_peers
  permitted_peers="$(build_json_array_like "${TLS_CLIENTS}")"
  # Construye lista permitida de peers TLS.

  cat > "${TLS_CONF}" <<EOF
# Carga módulo de entrada TCP.
module(load="imtcp")
# Carga soporte TLS para rsyslog.
module(load="gtls")

# Configuración global del driver TLS.
global(
  DefaultNetstreamDriver="gtls"
  DefaultNetstreamDriverCAFile="${CERT_DIR}/ca.crt"
  DefaultNetstreamDriverCertFile="${CERT_DIR}/server.crt"
  DefaultNetstreamDriverKeyFile="${CERT_DIR}/server.key"
)

# Plantilla dinámica por IP y programa.
template(name="RemoteLogs" type="string" string="${LOG_DIR}/%FROMHOST-IP%/%PROGRAMNAME%.log")

# Ruleset separado para logs remotos recibidos por TLS.
ruleset(name="remote_store_tls") {
    # Escritura en fichero con creación automática de directorios.
    action(type="omfile" DynaFile="RemoteLogs" createDirs="on" DirCreateMode="0750" FileCreateMode="0640")
    # Para el procesamiento dentro del ruleset.
    stop
}

# Input TCP con TLS/mTLS.
input(
    type="imtcp"
    port="${PORT}"
    StreamDriver="gtls"
    StreamDriverMode="1"
    StreamDriverAuthMode="x509/name"
    PermittedPeer=[${permitted_peers}]
    ruleset="remote_store_tls"
)
EOF

  ok "Configuración TLS escrita."
}

configure_firewall() {
  info "Configurando UFW..."

  ufw allow OpenSSH >/dev/null 2>&1 || true

  cleanup_old_ufw_allow_rules
  # Por defecto deja el firewall en estado deseado antes de recrear reglas.

  if [[ "${MODE}" == "basic" ]]; then
    case "${BASIC_PROTOCOL}" in
      udp)
        ensure_ufw_rules_for_port "${BASIC_UDP_PORT}" "udp"
        ;;
      tcp)
        ensure_ufw_rules_for_port "${BASIC_TCP_PORT}" "tcp"
        ;;
      both)
        ensure_ufw_rules_for_port "${BASIC_TCP_PORT}" "tcp"
        ensure_ufw_rules_for_port "${BASIC_UDP_PORT}" "udp"
        ;;
    esac
  else
    ensure_ufw_rules_for_port "${PORT}" "tcp"
  fi

  ufw --force enable >/dev/null 2>&1 || true

  ok "UFW configurado."
}

validate_and_restart() {
  info "Validando configuración de rsyslog..."
  rsyslogd -N1
  # Valida la configuración sin arrancar el daemon.
  ok "Configuración válida."

  info "Reiniciando rsyslog..."
  systemctl restart rsyslog
  # Reinicia rsyslog para aplicar cambios.

  info "Habilitando rsyslog al arranque..."
  systemctl enable rsyslog >/dev/null 2>&1 || true
  # Activa arranque automático.

  ok "rsyslog reiniciado y habilitado."
}

run_optional_test() {
  if [[ "${RUN_TEST}" == "true" ]]; then
    # Solo ejecuta si se pidió.
    info "Lanzando prueba local con logger..."
    logger "SYSLOG_SERVER_V5_TEST $(date -Iseconds)"
    # Genera un evento local.
    ok "Prueba local generada."
  fi
}

write_report() {
  local report="/root/syslog_server_report.txt"

  info "Generando informe final..."

  {
    echo "======== SYSLOG SERVER REPORT ========"
    echo "Fecha:            $(date -Iseconds)"
    echo "Modo:             ${MODE}"

    if [[ "${MODE}" == "basic" ]]; then
      echo "Protocol:         ${BASIC_PROTOCOL}"
      echo "TCP port:         ${BASIC_TCP_PORT:-N/A}"
      echo "UDP port:         ${BASIC_UDP_PORT:-N/A}"
    else
      echo "Puerto:           ${PORT}"
    fi

    echo "IPs permitidas:   ${ALLOWED_IPS}"
    echo "Log dir:          ${LOG_DIR}"
    echo "Backup dir:       ${BACKUP_DIR}"
    echo "Cert dir:         ${CERT_DIR}"
    echo "Export dir:       ${EXPORT_DIR}"
    echo "Prueba ejecutada: ${RUN_TEST}"
    echo
    echo "Escucha actual:"
    show_listening_sockets || true
    echo
    echo "Estado rsyslog:"
    systemctl is-active rsyslog || true
    echo
    echo "Estado UFW:"
    ufw status || true
    echo
    if [[ "${MODE}" == "tls" ]]; then
      echo "TLS clients:      ${TLS_CLIENTS}"
      echo "Server name:      ${SERVER_NAME}"
      echo "Server IP:        ${SERVER_IP}"
      echo "Server SAN extra: ${SERVER_SANS}"
    fi
  } > "${report}"

  ok "Informe generado en ${report}"
}

show_summary() {
  echo
  ok "Servidor configurado correctamente."
  echo "Resumen:"
  echo "  Modo:             ${MODE}"

  if [[ "${MODE}" == "basic" ]]; then
    echo "  Protocolo basic:  ${BASIC_PROTOCOL}"
    echo "  Puerto TCP:       ${BASIC_TCP_PORT:-N/A}"
    echo "  Puerto UDP:       ${BASIC_UDP_PORT:-N/A}"
  else
    echo "  Puerto TLS:       ${PORT}"
  fi

  echo "  Log dir:          ${LOG_DIR}"
  echo "  IPs permitidas:   ${ALLOWED_IPS}"
  echo "  Backup dir:       ${BACKUP_DIR}"
  echo

  if [[ "${MODE}" == "tls" ]]; then
    echo "  Cert dir:         ${CERT_DIR}"
    echo "  Export dir:       ${EXPORT_DIR}"
    echo "  Clientes TLS:     ${TLS_CLIENTS}"
    echo
    echo "Bundles exportados por cliente:"
    echo "  ${EXPORT_DIR}/<cliente>/ca.crt"
    echo "  ${EXPORT_DIR}/<cliente>/client.crt"
    echo "  ${EXPORT_DIR}/<cliente>/client.key"
    echo
  fi

  echo "Comprobación de escucha:"
  show_listening_sockets || warn "No se pudo verificar la escucha configurada"
  echo
}
# Muestra resumen legible al final.

main() {
  require_root
  # Verifica que se ejecuta como root.

  parse_args "$@"
  # Procesa todos los argumentos.

  collect_ufw_cleanup_targets
  # Captura objetivos UFW actuales y anteriores antes de sobrescribir configs.

  install_packages
  # Instala dependencias.

  prepare_directories
  # Prepara directorios de trabajo.

  check_log_mountpoint
  # Avisa si /var/log/remote no está montado en un disco independiente.

  write_logrotate
  # Configura rotación de logs.

  if [[ "${MODE}" == "basic" ]]; then
    # Si es modo basic...
    write_basic_config
    # Escribe configuración TCP simple.
  else
    # Si es modo tls...
    remove_old_certs_if_requested
    # Regenera certificados si se pidió.
    generate_ca
    # Genera o reutiliza CA.
    generate_server_cert
    # Genera o reutiliza certificado servidor.
    generate_client_certs
    # Genera o reutiliza certificados cliente.
    export_client_bundles
    # Exporta bundles de clientes.
    write_tls_config
    # Escribe configuración TLS.
  fi

  configure_firewall
  # Configura firewall.

  validate_and_restart
  # Valida rsyslog y reinicia servicio.

  run_optional_test
  # Lanza prueba opcional.

  write_report
  # Genera informe final.

  show_summary
  # Muestra resumen final.
}

main "$@"
# Ejecuta la función principal pasando todos los argumentos.
