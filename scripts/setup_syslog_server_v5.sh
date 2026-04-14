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
#   basic -> recepción por TCP + filtrado UFW por IP
#   tls   -> recepción por TCP + TLS/mTLS + certificados
#
# Uso:
#   sudo bash scripts/setup_syslog_server_v5.sh basic --allowed-ips 172.16.3.10
#   sudo bash scripts/setup_syslog_server_v5.sh tls --allowed-ips 172.16.3.10 --server-ip 172.16.3.2 --tls-clients kali01
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
# Puerto donde escuchará el servidor syslog.
# Se asignará más adelante según el modo.

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

  Modo basic:
    sudo bash scripts/setup_syslog_server_v5.sh basic \
      --allowed-ips 172.16.3.10,172.16.3.11 \
      --port 10514 \
      [--run-test]

  Modo tls:
    sudo bash scripts/setup_syslog_server_v5.sh tls \
      --allowed-ips 172.16.3.10,172.16.3.11 \
      --port 6514 \
      --server-name syslog.local \
      --server-ip 172.16.3.2 \
      --server-sans syslog01.empresa.local,logs.local \
      --tls-clients kali01,ubuntu01 \
      [--export-dir /root/syslog-client-bundles] \
      [--regenerate-certs] \
      [--run-test]
EOF
}
# Función que muestra cómo usar el script.

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Ejecuta este script con sudo o como root."
  # Comprueba que el usuario actual sea root.
  # EUID=0 significa root.
}

parse_args() {
  case "${MODE}" in
    basic) PORT="10514" ;;
    # Si el modo es basic, usa por defecto el puerto 10514.
    tls)   PORT="6514" ;;
    # Si el modo es tls, usa por defecto el puerto 6514.
    *) usage; die "Modo no válido: ${MODE:-<vacío>}" ;;
    # Si no es ninguno de los dos, muestra ayuda y falla.
  esac

  while [[ $# -gt 0 ]]; do
    # Recorre todos los argumentos que quedan.

    case "$1" in
      --allowed-ips)
        ALLOWED_IPS="${2:-}"
        # Guarda la lista de IPs permitidas.
        shift 2
        # Avanza dos posiciones: opción + valor.
        ;;
      --port)
        PORT="${2:-}"
        # Guarda el puerto indicado por el usuario.
        shift 2
        ;;
      --server-name)
        SERVER_NAME="${2:-}"
        # Guarda el nombre principal del servidor para el certificado.
        shift 2
        ;;
      --server-ip)
        SERVER_IP="${2:-}"
        # Guarda la IP del servidor para SAN.
        shift 2
        ;;
      --server-sans)
        SERVER_SANS="${2:-}"
        # Guarda SANs extra del servidor.
        shift 2
        ;;
      --tls-clients)
        TLS_CLIENTS="${2:-}"
        # Guarda la lista de clientes TLS permitidos.
        shift 2
        ;;
      --export-dir)
        EXPORT_DIR="${2:-}"
        # Guarda el directorio de exportación de bundles TLS.
        shift 2
        ;;
      --regenerate-certs)
        REGENERATE_CERTS="true"
        # Activa regeneración de certificados.
        shift
        ;;
      --run-test)
        RUN_TEST="true"
        # Activa prueba local al final.
        shift
        ;;
      -h|--help)
        usage
        # Muestra ayuda.
        exit 0
        # Sale correctamente.
        ;;
      *)
        die "Opción no reconocida: $1"
        # Falla si encuentra una opción desconocida.
        ;;
    esac
  done

  [[ -n "${ALLOWED_IPS}" ]] || die "Debes indicar --allowed-ips"
  # Obliga a indicar IPs permitidas.

  if [[ "${MODE}" == "tls" ]]; then
    # Solo en modo TLS se exigen estos parámetros.
    [[ -n "${SERVER_IP}" ]] || die "En modo tls debes indicar --server-ip"
    [[ -n "${TLS_CLIENTS}" ]] || die "En modo tls debes indicar --tls-clients"
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
  local -n out_arr="$2"
  # Crea una referencia al array de salida.

  IFS=',' read -r -a raw <<< "${csv}"
  # Divide el CSV por comas y lo mete en el array raw.

  out_arr=()
  # Inicializa el array de salida vacío.

  for item in "${raw[@]}"; do
    # Recorre cada elemento del CSV.
    item="$(echo "${item}" | xargs)"
    # Elimina espacios al principio y al final.
    [[ -n "${item}" ]] && out_arr+=("${item}")
    # Si no está vacío, lo añade al array final.
  done
}

install_packages() {
  info "Actualizando índice de paquetes..."
  apt-get update -y
  # Actualiza la lista de paquetes disponibles.

  info "Instalando dependencias si faltan..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    rsyslog ufw openssl ca-certificates coreutils grep sed gawk findutils
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
  # Hace backup de config previa basic si existe.
  backup_file_if_exists "${TLS_CONF}"
  # Hace backup de config TLS previa si existe, por si vienes de ese modo.

  rm -f "${TLS_CONF}"
  # Elimina la config TLS para evitar conflicto.

  cat > "${REMOTE_CONF}" <<EOF
# Carga el módulo de entrada TCP.
module(load="imtcp")

# Define un ruleset separado para logs remotos.
ruleset(name="remote_store") {
    # Define una plantilla dinámica basada en IP y programa.
    template(name="RemoteLogs" type="string" string="${LOG_DIR}/%FROMHOST-IP%/%PROGRAMNAME%.log")
    # Escribe el log en fichero dinámico usando la plantilla.
    action(type="omfile" DynaFile="RemoteLogs" DirCreateMode="0750" FileCreateMode="0640")
    # Detiene el procesamiento de este mensaje dentro de este ruleset.
    stop
}

# Abre un input TCP en el puerto indicado y lo asocia al ruleset remoto.
input(
    type="imtcp"
    port="${PORT}"
    ruleset="remote_store"
)
EOF
  # Escribe la configuración.

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

# Ruleset separado para logs remotos recibidos por TLS.
ruleset(name="remote_store_tls") {
    # Plantilla dinámica por IP y programa.
    template(name="RemoteLogs" type="string" string="${LOG_DIR}/%FROMHOST-IP%/%PROGRAMNAME%.log")
    # Escritura en fichero con creación automática de directorios.
    action(type="omfile" DynaFile="RemoteLogs" DirCreateMode="0750" FileCreateMode="0640")
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
  # Escribe la configuración TLS.

  ok "Configuración TLS escrita."
}

configure_firewall() {
  info "Configurando UFW..."

  ufw allow OpenSSH >/dev/null 2>&1 || true
  # Permite SSH para no perder acceso.

  ufw deny "${PORT}/tcp" >/dev/null 2>&1 || true
  # Bloquea por defecto el puerto syslog TCP.

  local ips=()
  # Array temporal de IPs.
  csv_to_array "${ALLOWED_IPS}" ips
  # Convierte la lista CSV a array.

  for ip in "${ips[@]}"; do
    # Recorre las IPs permitidas.
    if ufw status | grep -Fq "${ip}" && ufw status | grep -Fq "${PORT}/tcp"; then
      ok "Regla UFW ya presente para ${ip}:${PORT}/tcp"
      # Informa si ya parece estar la regla.
    else
      ufw allow from "${ip}" to any port "${PORT}" proto tcp >/dev/null 2>&1 || true
      # Permite acceso desde esa IP al puerto.
      ok "Regla UFW aplicada para ${ip}:${PORT}/tcp"
    fi
  done

  ufw --force enable >/dev/null 2>&1 || true
  # Activa UFW si no lo estaba.

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
  # Ruta del informe final.

  info "Generando informe final..."

  {
    echo "======== SYSLOG SERVER REPORT ========"
    echo "Fecha:            $(date -Iseconds)"
    echo "Modo:             ${MODE}"
    echo "Puerto:           ${PORT}"
    echo "IPs permitidas:   ${ALLOWED_IPS}"
    echo "Log dir:          ${LOG_DIR}"
    echo "Backup dir:       ${BACKUP_DIR}"
    echo "Cert dir:         ${CERT_DIR}"
    echo "Export dir:       ${EXPORT_DIR}"
    echo "Prueba ejecutada: ${RUN_TEST}"
    echo
    echo "Escucha actual:"
    ss -tulpn | grep -E ":${PORT}\b" || true
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
  # Escribe el informe final.

  ok "Informe generado en ${report}"
}

show_summary() {
  echo
  ok "Servidor configurado correctamente."
  echo "Resumen:"
  echo "  Modo:             ${MODE}"
  echo "  Puerto:           ${PORT}"
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
  ss -tulpn | grep -E ":${PORT}\b" || warn "No se pudo verificar la escucha del puerto ${PORT}"
  echo
}
# Muestra resumen legible al final.

main() {
  require_root
  # Verifica que se ejecuta como root.

  parse_args "$@"
  # Procesa todos los argumentos.

  install_packages
  # Instala dependencias.

  prepare_directories
  # Prepara directorios de trabajo.

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
