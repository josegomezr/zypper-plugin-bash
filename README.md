# zypper-plugin-bash

Simple-enough bash implementation of stateful zypper-plugin interface. The
zypper plugin interface is based on [STOMP](https://stomp.github.io/).

See the [libzypp documentation](https://doc.opensuse.org/projects/libzypp/HEAD/zypp-plugins.html) to
understand what messages are transmitted between zypper & your plugin.

## Usage

```bash
#!/bin/bash

source 'path/to/zypper-plugin.bash'

# use the zpb_* functions and ZPB_* vars
while read -r -t 1 -d $'\0' frame; do
  zpb_read_frame "$frame"

  if [[ "$ZPB_COMMAND" == "RESOLVEURL" ]];
  then
    # Hear RESOLVEURL Commands
    zpb_reply "RESOLVEDURL" \
      "https://sample-url/here/$ZPB_HEADER_NAME1/$ZPB_HEADER_NAME2" \
      "Authorization:Bearer mytoken" \
      "Another-Header:With value"
  elif [[ "$ZPB_COMMAND" == "_DISCONNECT" ]];
  then
    exec 0<&-
    zpb_reply "ACK" "Disconnect" "exit:0"
    break
  else
    zpb_reply "ERROR" "Reason: unknown frame $ZPB_COMMAND" "exit:1"
  fi
done

exec 1<&-
exec 2<&-
```

## API

### `zpb_debug $@`

Print debug messages if `ZYPPER_PLUGIN_BASH_DEBUG` is not empty.

Example:
```bash
zpb_debug "a message"
# zypper logs
# [...] ! [ZPB-DEBUG] a message
```

### `zpb_log $@`

Print log messages to standard err

Example:
```bash
zpb_debug "doing work..."
# zypper logs
# [...] ! doing work...
```

### `zpb_reply $VERB $BODY $HEADERS...`:

Reply back with a frame to zypper.

`$HEADERS` corresponds to the rest arguments, each argument is a
`header-name:header-value` pair.

It'll add the `content-length` header automatically.

Example:
```bash
zpb_reply "ACK" "test" "header:value"
# zypper receives:

# zypper <- plugin: reply
# ACK
# header:value
# content-length:4
#
# test@^
#
# @^ = NUL
```


### `zpb_read_frame`:

Reads a frame from zypper.

It'll populate the following variables:

- `$ZPB_COMMAND`: The frame's command.
- `$ZPB_BODY`: The full body/payload of the frame.
- `$ZPB_HEADER_${%name%}`: Every returned header.

Example:
```bash
zpb_reply "ACK" "test" "header:value"
# zypper sends:

# HELLO
# content-length:4
# foo:bar
#
# test@^
#
# @^ = NUL
```

Will populate the variables as follows:

```bash
ZPB_COMMAND=HELLO
ZPB_BODY=test
ZPB_HEADER_CONTENT_LENGTH=4
ZPB_HEADER_FOO=bar
```

## Limitations

* It won't respect the `content-length` header, `zypper` is a
  well-behaved-enough program so that's a liberty I can afford.
