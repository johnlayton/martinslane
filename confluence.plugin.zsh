#####################################################################
# Init
#####################################################################

function confluence () {
  [[ $# -gt 0 ]] || {
    _confluence::help
    return 1
  }

  local command="$1"
  shift

  (( $+functions[_confluence::$command] )) || {
    _confluence::help
    return 1
  }

  _confluence::$command "$@"
}

function _confluence {
  local -a cmds subcmds
  cmds=(
    'help:Usage information'
    'init:Initialisation information'
  )

  if (( CURRENT == 2 )); then
    _describe 'command' cmds
  elif (( CURRENT == 3 )); then
    case "$words[2]" in
      teams) subcmds=(
        'list:List all the teams'
        )
    esac
  fi

  return 0
}

compdef _confluence confluence

function _confluence::help {
    cat <<EOF
Usage: confluence <command> [options]

Available commands:

  help
  init

EOF
}

function _confluence::init {
  if [ -n "${CONFLUENCE_EMAIL}" ] && [ -n "${CONFLUENCE_TOKEN}" ]; then
    echo "============================================="
    echo "Current Configuration"
    echo "CONFLUENCE_API_ENDPOINT  ...... ${CONFLUENCE_API_ENDPOINT}"
    echo "CONFLUENCE_EMAIL .............. ${CONFLUENCE_EMAIL}"
    echo "CONFLUENCE_TOKEN .............. ${CONFLUENCE_TOKEN}"
    echo "============================================="
  else
    echo "============================================="
    echo "Create Configuration"
    echo "CONFLUENCE_API_ENDPOINT=<http://...>"
    echo "CONFLUENCE_EMAIL=<user@company.com>"
    echo "CONFLUENCE_TOKEN=<token>"
    echo "============================================="
    open "https://id.atlassian.com/manage-profile/security/api-tokens"
  fi
}
