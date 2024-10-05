#!/usr/bin/env bash

NZBGET=/usr/bin/nzbget
NZBGET_CONF=/etc/nzbget.conf
NZBGET_DIRMODE=775

function entrypoint_log() {
    local _msg
    _msg="${@:1}"
    echo "ENTRYPOINT INFO -- ${_msg}"
}

function build_config() {
  while read CONIFG_KEY CONFIG_VALUE
  do
    entrypoint_log "Setting: ${CONIFG_KEY} to ${CONFIG_VALUE}"
    _regex="s,^${CONIFG_KEY}=.*,${CONIFG_KEY}=${CONFIG_VALUE},g"
    sed -i "${_regex}" "${NZBGET_CONF}"
  done <<< $(env | grep '^NZBGET_' | sed -e 's/^NZBGET_//g' | tr '=' ' ' )
}

function display_config() {
  cat ${NZBGET_CONF} | grep -v '^#' | grep -v '=$' | sed '/^$/d'
}

function create_dirs() {
  local _dirs
  local _dir
  _dirs=${@:1}

  MainDir="${NZBGET_MainDir}"
  _dirs=$(eval echo "${_dirs}")

  for _dir in ${_dirs}
  do
    [ -d "${_dir}" ] || ( entrypoint_log "Creating dir: ${_dir}"; mkdir -p -m ${NZBGET_DIRMODE} "${_dir}" )
  done
}

function generate_cert() {
    local _key
    local _cert
    _cert="${1}"
    _key="${2}"

    entrypoint_log "Generating self signed certificate"
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 \
      -nodes -keyout "${_key}" -out "${_cert}" -subj "/CN=$(hostname)" 2> /dev/null
}

function certificates() {
  if ( grep '^SecureControl=yes' "${NZBGET_CONF}" 1> /dev/null 2>&1 )
  then
    entrypoint_log 'SecureControl is enabled'
    NZBGET_CERT=$( grep '^SecureCert' "${NZBGET_CONF}" | cut -d '=' -f 2 )
    NZBGET_CERT_KEY=$( grep '^SecureKey' "${NZBGET_CONF}" | cut -d '=' -f 2 )
    entrypoint_log "Certificate: ${NZBGET_CERT}"
    entrypoint_log "Certificate Key: ${NZBGET_CERT_KEY}"

    if [[ ! -f "${NZBGET_CERT}" || ! -f "${NZBGET_CERT_KEY}" ]]
    then
      local _certdir
      local _keydir
      _certdir="$(dirname ${NZBGET_CERT})"
      _keydir="$(dirname ${NZBGET_CERT_KEY})"
      create_dirs ${_certdir} ${_keydir}
      generate_cert "${NZBGET_CERT}" "${NZBGET_CERT_KEY}"
      chown 750 "${NZBGET_CERT_KEY}"
    fi
  fi
}

function generate_password() {
  local _password
  _password="$(openssl rand -hex 4)"
  printf ${_password}
}

function newsserver_info() {
    for _server in $(grep '^Server[0-9]*.Host=' "${NZBGET_CONF}" | cut -d '.' -f 1)
    do
      _nr=$(echo ${_server} | sed -e 's/Serer//g')
      _hostname=$(grep "${_server}\.Host=" "${NZBGET_CONF}" | cut -d "=" -f 2)
      _port=$(grep "${_server}\.Port=" "${NZBGET_CONF}" | cut -d "=" -f 2)
      _username=$(grep "${_server}\.Username=" "${NZBGET_CONF}" | cut -d "=" -f 2)
      _connections=$(grep "${_server}\.Connections=" "${NZBGET_CONF}" | cut -d "=" -f 2)
      _active=$(grep "${_server}\.Active=" "${NZBGET_CONF}" | cut -d "=" -f 2)
      _encryption=$(grep "${_server}\.Encryption=" "${NZBGET_CONF}" | cut -d "=" -f 2)
      printf "%-2d %-20s  port: %-5d     use ssl: %-3s     connections: %-2d    Username: %-10s    Active: %s\n" \
        "${nr}" "${_hostname}" "${_port}" "${_encryption}" "${_connections}" "${_username}" "${_active}"
    done
}

# Main Function

# creating dirs and configuration
create_dirs "${NZBGET_QueueDir}" "${NZBGET_TempDir}" "${NZBGET_ScriptDir}" "$(dirname ${NZBGET_LogFile})" "$(dirname ${NZBGET_LockFile})"

[ "${NZBGET_ControlUsername}" == "" ] && export NZBGET_ControlUsername="nzbget"

[ "${NZBGET_ControlPassword}" == "" ] && export NZBGET_ControlPassword="$(generate_password)"

build_config
certificates

( ${SHOW_CONFIG} ) && display_config

cat<<EOF
####################################################################################################################################

WEB INTERFACE USERNAME:      ${NZBGET_ControlUsername}
WEB INTERFACE PASSWORD:      ${NZBGET_ControlPassword}

Configured usenet servers list:

$(newsserver_info)

####################################################################################################################################
EOF

# Starting nzbget
if [[ ${1} == 'nzbget' ]]
then
  $NZBGET -c ${NZBGET_CONF} -o outputmode=log "${@:2}"
else
  exec "$@"
fi