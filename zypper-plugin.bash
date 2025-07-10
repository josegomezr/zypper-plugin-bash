#!/bin/bash -e

ZPB_COMMAND=""
ZPB_BODY=""
ZPB_DEFINED_HEADERS=""

#---
## zpb_debug
#---

function zpb_debug {
  if [[ -z "$ZYPPER_PLUGIN_BASH_DEBUG" ]]; then
    return
  fi
  zpb_log "[ZPB-DEBUG]" "$@"
}

function zpb_log {
  echo "$@" >&2
}

function zpb__reply {
  local verb=${1?'Missing verb'}
  shift || true
  local body="$1"
  shift || true

  echo "$verb"
  for headerpair in "$@"; do
    echo "$headerpair"
  done
  echo "content-length:${#body}"
  echo ""
  echo -n "$body"
  echo -en "\x00"
}

function zpb_reply {
  zpb__reply "$@"

  zpb_debug "zypper <- plugin: reply"
  zpb_debug "$(zpb__reply "$@" |hexdump -C -v)"
}

function zpb_read_frame {
  zpb_debug "zypper -> plugin: read-frame"
  zpb_debug "$(echo -n "$1"|hexdump -C -v)"
  local H=""

  ZPB_DEFINED_HEADERS=""
  for H in $ZPB_DEFINED_HEADERS; do
    printf -v "ZPB_HEADER_$H" "%s" ""
    unset "ZPB_HEADER_$H"
  done
  local state=verb

  while read -r -t 1 -d$'\n' line; do
    case "$state" in
      verb )
        ZPB_COMMAND="$line"
        state=headers
        ;;

      headers )
        if [[ $line == "" ]]; then
          state=body_start
          continue
        fi
        local h_name=$(echo -n "$line" | cut -f1 -d':' | tr -d $'\n' | tr '[:lower:]' '[:upper:]' | tr -c '[:alnum:]' '_')
        local h_val=$(echo -n "$line" | cut -f2- -d':' | tr -d $'\n')
        ZPB_DEFINED_HEADERS="$(echo "$ZPB_DEFINED_HEADERS $h_name" | xargs)"
        printf -v "ZPB_HEADER_$h_name" "%s" "$h_val"
        ;;
      
      body_start )
        ZPB_BODY="$line"
        state=body_final
      ;;

      body_final )
        ZPB_BODY="$ZPB_BODY\n$line"
      ;;
    esac
  done <<< "$1"

  zpb_debug "FRAME COMMAND: $ZPB_COMMAND"
  zpb_debug "FRAME HEADERS: $ZPB_DEFINED_HEADERS"
  zpb_debug "FRAME BODY: $ZPB_BODY"
}
