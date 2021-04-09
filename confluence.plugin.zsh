#####################################################################
# Init
#####################################################################

function confluence-token () {
  echo $(kscript "println(java.util.Base64.getEncoder().encodeToString(\"${CONFLUENCE_EMAIL}:${CONFLUENCE_TOKEN}\".toByteArray()))")
}

function confluence-get () {
  local PTH=${1:-""}
  local QRY=${2:-""}

  if [[ -n "${PTH}" ]]; then
    PTH="/${PTH}"
  fi

  if [[ -n "${QRY}" ]]; then
    QRY="?${QRY}"
  fi

  curl --request GET \
       --silent \
       --header "Accept: application/json" \
       --header "Authorization: Basic $( confluence-token )" \
       --url "${CONFLUENCE_API_ENDPOINT}${PTH}${QRY}"
}

function confluence-upload () {
  local PATH=${1:-""}
  local FILE=${2:-""}

  if [[ -n "${PATH}" ]]; then
    PATH="/${PATH}"
  fi

  curl --request POST \
       --silent \
       --header "X-Atlassian-Token: nocheck" \
       --header "Authorization: Basic $( confluence-token )" \
       --url "${CONFLUENCE_API_ENDPOINT}${PATH}" \
       --form "file=@${FILE}"
}

function confluence-post () {
  local PATH=${1:-""}
  local DATA=${2:-"\{\}"}

  if [[ -n "${PATH}" ]]; then
    PATH="/${PATH}"
  fi

  curl --request POST \
       --silent \
       --header "Accept: application/json" \
       --header "Content-type: application/json" \
       --header "Authorization: Basic $( confluence-token )" \
       --url "${CONFLUENCE_API_ENDPOINT}${PATH}" \
       --data-raw ${DATA}
}

function confluence-put () {
  local PATH=${1:-""}
  local DATA=${2:-"\{\}"}

  if [[ -n "${PATH}" ]]; then
    PATH="/${PATH}"
  fi

  curl --request PUT \
       --silent \
       --header 'Accept: application/json' \
       --header 'Content-type: application/json' \
       --header "Authorization: Basic $( confluence-token )" \
       --url "${CONFLUENCE_API_ENDPOINT}${PATH}" \
       --data-raw ${DATA}
}

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
    'user:Manage user'
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
  user
  space
  content
  attach

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

function _confluence::user () {
  confluence-get "user/current" "expand=personalSpace"
}

function _confluence::space () {
  confluence-get "space/${1:-$(confluence user | jq -r ".personalSpace.key")}" "expand=homepage,homepage.descendants,homepage.descendants.page,homepage.descendants.page.version,settings"
}

function _confluence::content () {
  local TITLE=${1:-""}
  local PARENT=${2:-""}
  local TEXT=${3:-""}

  local SPACE=$(confluence space)

  if [ $# -eq 1 ]; then
    local CONTENT_ID=$(echo ${SPACE} | jq -r ".homepage.descendants.page.results[] | select(.title == \"$TITLE\")" | jq -r ".id")
    confluence-get "content/${CONTENT_ID}" "expand=body.view"
  elif [ $# -eq 3 ]; then
    local SPACE_KEY=$(echo ${SPACE} | jq -r ".key")
    local CONTENT_ID=$(echo ${SPACE} | jq -r ".homepage.descendants.page.results[] | select(.title == \"$PARENT\")" | jq -r ".id")
    local DATA="{
  \"title\": \"${TITLE}\",
  \"type\": \"page\",
  \"space\": {
    \"key\": \"${SPACE_KEY}\"
  },
  \"status\": \"current\",
  \"ancestors\": [
    {
      \"id\": \"${CONTENT_ID}\"
    }
  ],
  \"body\": {
    \"storage\": {
      \"value\": \"${TEXT}\",
      \"representation\": \"storage\"
    }
  }
}"
    confluence-post "content" "" "${DATA}"
  else
    confluence help
  fi
}

function _confluence::attach () {
  local TITLE=${1:-""}
  local FILE=${2:-""}

  local SPACE=$(confluence space)
  local CONTENT=$(echo ${SPACE} | jq -r ".homepage.descendants.page.results[] | select(.title == \"$TITLE\")")
  local CONTENT_ID=$(echo ${CONTENT} | jq -r ".id")

  if [ $# -eq 1 ]; then
    confluence-get "content/${CONTENT_ID}" "expand=body.view"
  elif [ $# -eq 2 ]; then
    local VERSION_NUMBER=$(echo ${CONTENT} | jq -r ".version.number")
    local EMBED_TEXT="<p> \
  <span class=\\\"confluence-embedded-file-wrapper confluence-embedded-manual-size\\\"> \
    <img class=\\\"confluence-embedded-image\\\" \
         src=\\\"https:\\/\\/whispir.atlassian.net\\/wiki\\/download\\/thumbnails\\/${CONTENT_ID}\\/${FILE}\\\" \
         data-image-src=\\\"https:\\/\\/whispir.atlassian.net\\/wiki\\/download\\/attachments\\/${CONTENT_ID}\\/${FILE}\\\" \
         data-unresolved-comment-count=\\\"0\\\" \
         data-linked-resource-type=\\\"attachment\\\" \
         data-linked-resource-default-alias=\\\"${FILE}\\\" \
         data-base-url=\\\"https:\\/\\/whispir.atlassian.net\\/wiki\\\" \
         data-linked-resource-content-type=\\\"image\\/gif\\\" \
         data-linked-resource-container-id=\\\"${CONTENT_ID}\\\" \
         data-linked-resource-container-version=\\\"$((${VERSION_NUMBER} + 1))\\\" \
         data-media-type=\\\"file\\\"\\/> \
   <\\/span> \
<\\/p>"
    local DATA="{
  \"title\": \"${TITLE}\",
  \"type\": \"page\",
  \"version\": {
    \"number\": \"$((${VERSION_NUMBER} + 1))\"
  },
  \"type\": \"page\",
  \"body\": {
    \"storage\": {
      \"value\": \"${EMBED_TEXT}\",
      \"representation\": \"storage\"
    }
  }
}"
    confluence-upload "content/${CONTENT_ID}/child/attachment" "${FILE}"
    confluence-put "content/${CONTENT_ID}" "${DATA}"
  else
    confluence help
  fi
}
