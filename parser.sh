#!/usr/bin/env sh

_accept_command=auto # auto, none, any, mapped_only
_accept_options=auto # auto, none, any, mapped_only
_default_max_positional_args=""
_default_min_positional_args=0
_default_positional_arg_variable=""
_mapping_key_value_delimiter="="
_mapping_values_delimiter=","
_option_duplicates_allowed=true
_option_key_value_delimiter=" "
_option_values_delimiter=" "
_options_combination_allowed=true
_options_combination_args_allowed=true
_positional_args_placement=any # any, before_options, after_options

_mapped_commands_count=0
_mapped_options_count=0
_positional_args_count=0

_err() {
  for arg in "$@"; do
    echo "$arg"
  done

  exit 1
}

_math() {
  printf "%s" "$(($@))"
}

_is() {
  [ "$1" = "true" ]
}

_is_not() {
  [ "$1" != "true" ]
}

_is_int() {
  case $1 in
    [0-9])
      return 0
      ;;
    [1-9][0-9]*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

_is_flag() {
  [ "$1" = "true" ] || [ "$1" = "false" ]
}

_assign() {
  if ! _is_valid_var_name "$1"; then
    _err "Invalid variable name: $1."
  fi

  _value=$2
  _escaped_value=""

  while [ -n "$_value" ]; do
    _part=${_value%%\'*}
    _escaped_value="$_escaped_value$_part"
    _value=${_value#"$_part"}

    if [ -n "$_value" ]; then
      _escaped_value="$_escaped_value'\''"
      _value=${_value#\'}
    fi

  done

  eval "$1='$_escaped_value'"
}

_var_value() {
  if _is_valid_var_name "$1"; then
    eval "echo \"\$$1\""
  else
    _err "Invalid variable name: $1."
  fi
}

_starts_with() {
  case "$1" in
    "$2"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

_get_mapping_entry_key() {
  echo "${1%%["${_mapping_key_value_delimiter}"]*}"
}

_get_mapping_entry_value() {
  case "$1" in
    *"$_mapping_key_value_delimiter"*)
      echo "${1#*"${_mapping_key_value_delimiter}"}"
      ;;
    *)
      ;;
  esac
}

_str_contains() {
    case "$1" in
      *"$2"*)
        return 0
        ;;
      *)
        return 1
        ;;
    esac
}

_aliases_list_contains() {
  _str_contains \
    "${_mapping_values_delimiter}$1${_mapping_values_delimiter}" \
    "${_mapping_values_delimiter}$2${_mapping_values_delimiter}"
}

_is_valid_var_name() {
  case "$1" in
    [!a-zA-Z_]*)
      return 1
      ;;
    *[!a-zA-Z0-9_]*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

_command_required() {
  [ "$_accept_command" = "none" ] && return 1
  [ "$_accept_command" != "auto" ] && return 0
  [ "$_mapped_commands_count" -gt 0 ]
}

_mapped_options_only() {
  [ "$_accept_options" = "none" ] && return 1
  [ "$_accept_options" = "any" ] && return 1
  [ "$_accept_options" = "mapped_only" ] && return 0
  [ "$_mapped_options_count" -gt 0 ]
}

_is_free_var_name() {
  if [ -n "$_default_positional_arg_variable" ] && [ "$_default_positional_arg_variable" = "$1" ]; then
      echo "Variable is already used as default positional arg variable: $1."
      return 1
  fi

  _i=1
  while [ "$_i" -le "$_mapped_options_count" ]; do
    if [ "$1" = "$(_var_value "_options_${_i}_variable")" ]; then
      echo "Variable is already mapped for option #${_i}: $1."
      return 1
    fi

    _i=$(_math "$_i + 1")
  done

  _i=1
  while [ "$_i" -le "$_mapped_commands_count" ]; do
    if [ "$1" = "$(_var_value "_commands_${_i}_arg_variable")" ]; then
      echo "Arg variable is already mapped for command #${_i}: $1."
      return 1
    fi

    _i=$(_math "$_i + 1")
  done
}

_set_config() {
  _config_key="$1"
  _config_value="$2"

  if [ "$_config_key" = "accept_command" ]; then
    _validate_config_accept_command "$_config_value"
  elif [ "$_config_key" = "accept_options" ]; then
    _validate_config_accept_options "$_config_value"
  elif [ "$_config_key" = "default_max_positional_args" ]; then
    _validate_config_default_max_positional_args "$_config_value"
  elif [ "$_config_key" = "default_min_positional_args" ]; then
    _validate_config_default_min_positional_args "$_config_value"
  elif [ "$_config_key" = "default_positional_arg_variable" ]; then
    _validate_config_default_positional_arg_variable "$_config_value"
    _default_max_positional_args="1"
    _default_min_positional_args="1"
  elif [ "$_config_key" = "mapping_key_value_delimiter" ]; then
    _validate_config_mapping_key_value_delimiter "$_config_value"
  elif [ "$_config_key" = "mapping_values_delimiter" ]; then
    _validate_config_mapping_values_delimiter "$_config_value"
  elif [ "$_config_key" = "option_duplicates_allowed" ]; then
    _validate_config_option_duplicates_allowed "$_config_value"
  elif [ "$_config_key" = "option_key_value_delimiter" ]; then
    _validate_config_option_key_value_delimiter "$_config_value"
  elif [ "$_config_key" = "option_values_delimiter" ]; then
    _validate_config_option_values_delimiter "$_config_value"
  elif [ "$_config_key" = "options_combination_allowed" ]; then
    _validate_config_options_combination_allowed "$_config_value"
  elif [ "$_config_key" = "options_combination_args_allowed" ]; then
    _validate_config_options_combination_args_allowed "$_config_value"
  elif [ "$_config_key" = "positional_args_placement" ]; then
    _validate_config_positional_args_placement "$_config_value" # TODO
  else
    _err "Unknown config key: $_config_key."
  fi

  _assign "_$_config_key" "$_config_value"
}

_map_command() {
  _command_index=$(_math "$_mapped_commands_count + 1")
  _mapping_command_prefix="_commands_${_command_index}"

  while [ "$#" -gt 0 ]; do
    _map_entry="$1"

    if _str_contains "$_map_entry" "$_mapping_key_value_delimiter"; then
      _map_key=$(_get_mapping_entry_key "$_map_entry")
      _map_value=$(_get_mapping_entry_value "$_map_entry")
      if [ -z "$_map_key" ] || [ -z "$_map_value" ]; then
        _err "Invalid command #${_command_index} mapping entry: $_map_entry."
      fi
    else
      _map_key="$_map_entry"
      _map_value=true
    fi

    # Per-key command mapping validation.

    if [ "$_map_key" = "description" ]; then
      _validate_command_description "$_map_value"
    elif [ "$_map_key" = "max_args" ]; then
      _validate_command_max_args "$_map_value"
    elif [ "$_map_key" = "min_args" ]; then
      _validate_command_min_args "$_map_value"
    elif [ "$_map_key" = "name" ]; then
      _validate_command_name "$_map_value"
    elif [ "$_map_key" = "arg_variable" ]; then
      _validate_command_arg_variable "$_map_value"
      _assign "${_mapping_command_prefix}_min_args" 1
      _assign "${_mapping_command_prefix}_max_args" 1
    else
      _err "Invalid command #${_command_index} mapping key: $_map_key."
    fi

    _assign "${_mapping_command_prefix}_${_map_key}" "$_map_value"

    shift
  done

  # Post-mapping command validation.

  if [ -z "$(_var_value "${_mapping_command_prefix}_name")" ]; then
    _err "Missing command #${_command_index} name."
  fi

  _mapped_commands_count=$_command_index
}

_map_command_auto() {
  _command_index=$(_math "$_mapped_commands_count + 1")
  _mapping_command_prefix="_commands_${_command_index}"

  _validate_command_name "$1"

  _assign "${_mapping_command_prefix}_name" "$1"
  _assign "${_mapping_command_prefix}_auto" "true"

  _mapped_commands_count=$_command_index
}

_map_option() {
  _option_index=$(_math "$_mapped_options_count + 1")
  _mapping_option_prefix="_options_${_option_index}"

  while [ "$#" -gt 0 ]; do
    _map_entry="$1"

    if _str_contains "$_map_entry" "$_mapping_key_value_delimiter"; then
      _map_key=$(_get_mapping_entry_key "$_map_entry")
      _map_value=$(_get_mapping_entry_value "$_map_entry")
      if [ -z "$_map_key" ] || [ -z "$_map_value" ]; then
        _err "Invalid option #${_option_index} mapping entry: $_map_entry."
      fi
    else
      _map_key="$_map_entry"
      _map_value=""
    fi

    # Per-key option mapping validation.

    if [ "$_map_key" = "aliases" ]; then
      _validate_option_aliases "$_map_value"
    elif [ "$_map_key" = "variable" ]; then
      _validate_option_variable "$_map_value"
      _assign "${_mapping_option_prefix}_min_args" 1
      _assign "${_mapping_option_prefix}_max_args" 1
    elif [ "$_map_key" = "description" ]; then
      _validate_option_description "$_map_value"
    elif [ "$_map_key" = "max_args" ]; then
      _validate_option_max_args "$_map_value"
    elif [ "$_map_key" = "min_args" ]; then
      _validate_option_min_args "$_map_value"
    elif [ "$_map_key" = "required" ]; then
      _validate_option_required "$_map_value"
      _map_value=true
    else
      _err "Invalid option #${_option_index} mapping key: $_map_key."
    fi

    _assign "${_mapping_option_prefix}_${_map_key}" "$_map_value"

    shift
  done

  # Post-mapping option validation.

  if [ -z "$(_var_value "${_mapping_option_prefix}_aliases")" ]; then
    _err "Missing option #${_option_index} aliases."
  fi

  _mapped_options_count=$_option_index
}

_map_option_auto() {
  _option_index=$(_math "$_mapped_options_count + 1")
  _mapping_option_prefix="_options_${_option_index}"

  _validate_option_aliases "$1"

  _assign "${_mapping_option_prefix}_aliases" "$1"
  _assign "${_mapping_option_prefix}_auto" "true"

  _mapped_options_count=$_option_index
}

_validate_config_accept_command() {
  case "$1" in
    any | none | mapped_only | auto)
      ;;
    *)
      _err "Invalid config \"_accept_command\" value: $1. Expected: any, none, mapped_only, auto."
    ;;
  esac
}

_validate_config_accept_options() {
  case "$1" in
    any | none | mapped_only | auto)
      ;;
    *)
      _err "Invalid config \"_accept_options\" value: $1. Expected: any, none, mapped_only, auto."
    ;;
  esac
}

_validate_config_default_max_positional_args() {
  if ! _is_int "$1"; then
    _err "Invalid config \"_default_max_positional_args\" value: $1. Expected: a non-negative integer."
  fi

  if [ -n "$_default_positional_arg_variable" ] && [ "$1" -ne 1 ]; then
    _err "Config \"_default_max_positional_args\" cannot differ from 1 if \"_default_positional_arg_variable\" is set."
  fi
}

_validate_config_default_min_positional_args() {
    if ! _is_int "$1"; then
    _err "Invalid config \"_default_min_positional_args\" value: $1. Expected: a non-negative integer."
  fi

  if [ -n "$_default_positional_arg_variable" ] && [ "$1" -ne 1 ]; then
    _err "Config \"_default_min_positional_args\" cannot differ from 1 if \"_default_positional_arg_variable\" is set."
  fi
}

_validate_config_default_positional_arg_variable() {
  if ! _is_valid_var_name "$1"; then
    _err "Default positional arg variable is invalid: $1. Must be a valid variable name."
  fi

  if ! _description=$(_is_free_var_name "$1"); then
    _err "Default positional arg is already used. ${_description}"
  fi
}

_validate_config_mapping_key_value_delimiter() {
  case "$1" in
    "=" | ":")
      ;;
    *)
      _err "Invalid config \"_mapping_key_value_delimiter\" value: $1. Expected: \"=\", \":\"."
    ;;
  esac
}

_validate_config_mapping_values_delimiter() {
  case "$1" in
    "," | "|" | ";" | "/")
      ;;
    *)
      _err "Invalid config \"_mapping_values_delimiter\" value: $1. Expected: \",\", \"|\", \";\", \"/\"."
      ;;
  esac
}

_validate_config_option_duplicates_allowed() {
  if ! _is_flag "$1"; then
    _err "Invalid config \"_option_duplicates_allowed\" value: $1. Expected \"true\" or \"false\"."
  fi
}

_validate_config_option_key_value_delimiter() {
  case "$1" in
    " " | "=" | ":")
      ;;
    *)
      _err "Invalid config \"_option_key_value_delimiter\" value: $1. Expected: \" \", \"=\", \":\"."
    ;;
  esac

  if [ "$1" != " " ] && [ "$_option_key_value_delimiter" = " " ]; then
    _err "Non-space value of config \"_option_key_value_delimiter\" is incompatible with space valueof config \"_option_values_delimiter\" due to parsing ambiguity."
  fi
}

_validate_config_option_values_delimiter() {
  case "$1" in
    " " |"," | "|" | ";" | "/")
      ;;
    *)
      _err "Invalid config \"_mapping_values_delimiter\" value: $1. Expected: \" \", \",\", \"|\", \";\", \"/\"."
      ;;
  esac

  if [ "$1" = " " ] && [ "$_option_key_value_delimiter" != " " ]; then
    _err "Non-space value of config \"_option_key_value_delimiter\" is incompatible with space valueof config \"_option_values_delimiter\" due to parsing ambiguity."
  fi
}

_validate_config_options_combination_allowed() {
  if ! _is_flag "$1"; then
    _err "Invalid config \"_options_combination_allowed\" value: $1. Expected \"true\" or \"false\"."
  fi
}

_validate_config_options_combination_args_allowed() {
  if ! _is_flag "$1"; then
    _err "Invalid config \"_options_combination_args_allowed\" value: $1. Expected \"true\" or \"false\"."
  fi
}

_validate_config_positional_args_placement() {
  case "$1" in
    any | before_options | after_options)
      ;;
    *)
      _err "Invalid config \"_positional_args_placement\" value: $1. Expected: any, before_options, after_options."
    ;;
  esac
}

_validate_command_description() {
  if [ -n "$(_var_value "${_mapping_command_prefix}_description")" ]; then
    _err "Command #${_command_index} description is already mapped."
  fi
}

_validate_command_max_args() {
  if [ -n "$(_var_value "${_mapping_command_prefix}_max_args")" ]; then
    _err "Command #${_command_index} max args is already mapped."
  fi

  if [ -z "$1" ]; then
    _err "Command #${_command_index} max args cannot be empty."
  fi

  if ! _is_int "$1"; then
    _err "Command #${_command_index} max args is invalid: $1. Must be a non-negative integer."
  fi
}

_validate_command_min_args() {
  if [ -n "$(_var_value "${_mapping_command_prefix}_min_args")" ]; then
    _err "Command #${_command_index} min_args is already mapped."
  fi

  if [ -z "$1" ]; then
    _err "Command #${_command_index} min args cannot be empty."
  fi

  if ! _is_int "$1"; then
    _err "Command #${_command_index} min args is invalid: $1. Must be a non-negative integer."
  fi
}

_validate_command_name() {
  _existing_command_name=$(_var_value "${_mapping_command_prefix}_name")

  if [ -n "$_existing_command_name" ]; then
    _err "Command #${_command_index} name is already mapped: $_existing_command_name."
  fi

  # Check if command name not empty.

  if [ -z "$1" ]; then
    _err "Command #${_command_index} name is required."
  fi

  # Check if command name is valid.

  case "$1" in
    [!a-zA-Z0-9]*)
      _err "Command #${_command_index} name is invalid: $1. Must start with an alphanumeric character."
      ;;
    *[!a-z0-9\-_]*)
      _err "Command #${_command_index} name is invalid: $1. Must be alphanumeric, hyphen and underscore only."
      ;;
    *)
      ;;
  esac

  # Check if command name is unique.

  _i=1
  while [ "$_i" -le "$_mapped_commands_count" ]; do
    if [ "$1" = "$(_var_value "_commands_${_i}_name")" ]; then
      _err "Command #${_command_index} already mapped: $1."
    fi

    _i=$(_math "$_i + 1")
  done
}

_validate_command_arg_variable() {
  if [ -n "$(_var_value "${_mapping_command_prefix}_arg_variable")" ]; then
    _err "Command #${_command_index} arg variable is already mapped."
  fi

  _min_args=$(_var_value "${_mapping_command_prefix}_min_args")
  _max_args=$(_var_value "${_mapping_command_prefix}_max_args")

  if { [ -n "$_min_args" ] && [ "$_min_args" -ne 1 ]; } || { [ -n "$_max_args" ] && [ "$_max_args" -ne 1 ]; }; then
    _err "Command #${_command_index} arg variable can only be used with commands that requires single argument."
  fi

  if [ -z "$1" ]; then
    _err "Command #${_command_index} arg variable cannot be empty."
  fi

  if ! _is_valid_var_name "$1"; then
    _err "Command #${_command_index} arg variable is invalid: $1. Must be a valid variable name."
  fi

  if ! _description=$(_is_free_var_name "$1"); then
    _err "Command #${_command_index} arg variable is already used. ${_description}"
  fi
}

_validate_option_aliases() {
  if [ -n "$(_var_value "${_mapping_option_prefix}_aliases")" ]; then
    _err "Option #${_option_index} aliases are already mapped."
  fi

  _old_ifs="$IFS"
  IFS="$_mapping_values_delimiter"

  _current_option_aliases_list="$_mapping_values_delimiter"

  for _option_alias in $1; do
    if _aliases_list_contains "$_current_option_aliases_list" "$_option_alias"; then
      _err "Option #${_option_index} alias duplicate: $_option_alias."
    fi

    case "$_option_alias" in
      --*)
        _validate_long_option_alias "${_option_alias#??}"
        ;;
      -*)
        _validate_short_option_alias "${_option_alias#?}"
        ;;
      *)
        _err "Option #${_option_index} alias is invalid: $_option_alias. Must start with: -- or -."
        ;;
    esac

    _current_option_aliases_list="${_current_option_aliases_list}${_option_alias}${_mapping_values_delimiter}"
  done

  IFS="$_old_ifs"
}

_validate_long_option_alias() {
  if [ -z "$1" ]; then
    _err "Option #${_option_index} alias cannot be empty."
  fi

  case "$1" in
    [!a-zA-Z0-9]*)
      _err "Option #${_option_index} alias is invalid: $1. Must start with an alphanumeric character."
      ;;
    *[!a-z0-9\-_]*)
      _err "Option #${_option_index} alias is invalid: $1. Must be alphanumeric, hyphen and underscore only."
      ;;
    *)
      ;;
  esac

  _validate_option_alias_uniqueness "--$1"
}

_validate_short_option_alias() {
  if [ -z "$1" ]; then
    _err "Option #${_option_index} alias cannot be empty."
  fi

  case "$1" in
    [!a-zA-Z])
      _err "Option #${_option_index} alias is invalid: $1. Must be a single latin letter."
      ;;
    *)
      ;;
  esac

  _validate_option_alias_uniqueness "-$1"
}

_validate_option_alias_uniqueness() {
  _i=1
  while [ "$_i" -le "$_mapped_options_count" ]; do
    if _aliases_list_contains "$(_var_value "_options_${_i}_aliases")" "$1"; then
      _err "Option #${_option_index} alias is already mapped for option #${_i}: $1."
    fi

    _i=$(_math "$_i + 1")
  done
}

_validate_option_variable() {
  if [ -n "$(_var_value "${_mapping_option_prefix}_variable")" ]; then
    _err "Option #${_option_index} variable is already mapped."
  fi

  _min_args=$(_var_value "${_mapping_option_prefix}_min_args")
  _max_args=$(_var_value "${_mapping_option_prefix}_max_args")

  if { [ -n "$_min_args" ] && [ "$_min_args" -ne 1 ]; } || { [ -n "$_max_args" ] && [ "$_max_args" -ne 1 ]; }; then
    _err "Option #${_option_index} variable can only be used with options with a single argument."
  fi

  if [ -z "$1" ]; then
    _err "Option #${_option_index} variable cannot be empty."
  fi

  if ! _is_valid_var_name "$1"; then
    _err "Option #${_option_index} variable is invalid: $1. Must be a valid variable name."
  fi

  if ! _description=$(_is_free_var_name "$1"); then
    _err "Option #${_option_index} variable is already used. ${_description}"
  fi
}

_validate_option_description() {
  if [ -n "$(_var_value "${_mapping_option_prefix}_description")" ]; then
    _err "Option #${_option_index} description is already mapped."
  fi

  if [ -z "$1" ]; then
    _err "Option #${_option_index} description cannot be empty."
  fi
}

_validate_option_max_args() {
  if [ -n "$(_var_value "${_mapping_option_prefix}_max_args")" ]; then
    _err "Option #${_option_index} max args are already mapped."
  fi

  if [ -z "$1" ]; then
    _err "Option #${_option_index} max args cannot be empty."
  fi

  if ! _is_int "$1"; then
    _err "Option #${_option_index} max args is invalid: $1. Must be a non-negative integer."
  fi

  if (_is "$(_var_value "${_mapping_option_prefix}_required")") && [ "$1" -eq 0 ]; then
    _err "Option #${_option_index} must be removed as constant. It is required without arguments."
  fi
}

_validate_option_min_args() {
  if [ -n "$(_var_value "${_mapping_option_prefix}_min_args")" ]; then
    _err "Option #${_option_index} min args are already mapped."
  fi

  if [ -z "$1" ]; then
    _err "Option #${_option_index} min args cannot be empty."
  fi

  if ! _is_int "$1"; then
    _err "Option #${_option_index} min args is invalid: $1. Must be a non-negative integer."
  fi
}

_validate_option_required() {
  if [ -n "$(_var_value "${_mapping_option_prefix}_required")" ]; then
    _err "Option #${_option_index} required is already mapped."
  fi

  if [ -n "$1" ]; then
    _err "Option #${_option_index} required is invalid: $1. Must be used as a flag without value."
  fi

  _option_max_args=$(_var_value "${_mapping_option_prefix}_max_args")

  if [ -n "$_option_max_args" ] && [ "$_option_max_args" -eq 0 ]; then
    _err "Option #${_option_index} must be removed as constant. It is required without arguments."
  fi
}


_get_mapped_option_index_by_alias() {
  _i=1
  while [ "$_i" -le "$_mapped_options_count" ]; do
    if _aliases_list_contains "$(_var_value "_options_${_i}_aliases")" "$1"; then
      echo "$_i"
      return 0
    fi

    _i=$(_math "$_i + 1")
  done

  return 1
}

_get_mapped_command_index_by_name() {
  _i=1
  while [ "$_i" -le "$_mapped_commands_count" ]; do
    if [ "$(_var_value "_commands_${_i}_name")" = "$1" ]; then
      echo "$_i"
      return 0
    fi

    _i=$(_math "$_i + 1")
  done

  return 1
}


_parse() {
  _option_index=0
  _used_command_index=0

  if _command_required; then
    if [ -z "$1" ]; then
      _err "Command is required."
    fi

    if _starts_with "$1" "-"; then
      _err "Command is required. Found option instead: $1."
    fi

    _use_command "$1"

    shift
  fi

  if [ "$_accept_options" = "none" ]; then
    _parse_positional_args "$@"
  else
    while [ $# -gt 0 ]; do
      case "$1" in
        --)
          shift
          _parse_positional_args "$@"
          break
          ;;
        --*)
          _parse_option "$1"
          ;;
        -*)
          _parse_options_combination "$1"
          ;;
        *)
          if [ "$_option_index" -eq 0 ] || [ "$_option_key_value_delimiter" != " " ]; then
            _parse_positional_args "$1"
          else
            _parse_option_args "$1"
          fi
          ;;
      esac

      shift
    done
  fi

  _i=1
  while [ "$_i" -le "$_mapped_options_count" ]; do
    _option_used=$(_var_value "_options_${_i}_used")

    if (_is "$(_var_value "_options_${_i}_required")") && (_is_not "$_option_used"); then
      _err "Option is required: $(_var_value "_options_${_i}_aliases")."
    fi

    _option_min_args=$(_var_value "_options_${_i}_min_args")

    if (_is "$_option_used") && [ -n "$_option_min_args" ] && [ "$_option_min_args" -gt 0 ]; then
      _option_args_count=$(_var_value "_options_${_i}_args_count")

      if [ -z "$_option_args_count" ] || [ "$_option_args_count" -lt "$_option_min_args" ]; then
        _err "At least $_option_min_args argument(s) required for option: $(_var_value "_options_${_i}_used_alias")."
      fi
    fi

    _i=$(_math "$_i + 1")
  done

  if [ "$_used_command_index" -ne 0 ]; then
    _min_positional_args=$(_var_value "_commands_${_used_command_index}_min_args")
  fi

  if [ -z "$_min_positional_args" ]; then
    _min_positional_args=$_default_min_positional_args
  fi

  if [ "$_min_positional_args" -gt 0 ] && [ "$_positional_args_count" -lt "$_min_positional_args" ]; then
    if [ "$_used_command_index" -eq 0 ]; then
      _err "At least $_min_positional_args positional argument(s) required."
    else
      _err "At least $_min_positional_args positional argument(s) required for command: $(_var_value "_commands_${_used_command_index}_name")."
    fi
  fi
}

_parse_positional_args() {
  if [ "$_positional_args_placement" = "before_options" ] && [ -n "$_option_index" ]; then
    _err "Positional arguments must be placed before options: $1."
  fi

  if [ -n "$_command_index" ]; then
    _max_args=$(_var_value "_commands_${_command_index}_max_args")
    _arg_variable="$(_var_value "_commands_${_command_index}_arg_variable")"
  fi

  if [ -z "$_max_args" ]; then
    _max_args=$_default_max_positional_args
  fi

  if [ -z "$_arg_variable" ]; then
    _arg_variable="$_default_positional_arg_variable"
  fi

  while [ $# -gt 0 ]; do
    _positional_arg_index=$(_math "$_positional_args_count + 1")

    if [ -n "$_max_args" ] && [ "$_positional_arg_index" -gt "$_max_args" ]; then
      if [ -z "$_command_index" ]; then
        _err "Maximum $_max_args positional argument(s) allowed."
      else
        _err "Maximum $_max_args positional argument(s) allowed for command: $(_var_value "_commands_${_command_index}_name")."
      fi
    fi

    _assign "_positional_args_${_positional_arg_index}" "$1"
    _assign "_positional_args_count" "$_positional_arg_index"

    if [ -n "$_arg_variable" ]; then
      _assign "$_arg_variable" "$1"
    fi

    shift
  done
}

_parse_option() {
  _option_alias="${1%%"$_option_key_value_delimiter"*}"
  _use_option "$_option_alias"

  if [ "$_option_key_value_delimiter" != " " ] && [ "$_option_alias" != "$1" ]; then
    _parse_option_args "${1#*"$_option_key_value_delimiter"}"
  fi
}

_parse_options_combination() {
  _options_combination=${1%%"$_option_key_value_delimiter"*}

  if [ ${#_options_combination} = 1 ]; then
    _err "Unknown empty option: $1."
  fi

  if [ "$_options_combination" != "$1" ] && (_is_not "$_options_combination_allowed"); then
    _err "Short options combination is not allowed: $1."
  fi

  _i=2
  while [ "$_i" -le "${#_options_combination}" ]; do
    _use_option "-$(printf '%s' "$_options_combination" | cut -c "$_i")"

    _i=$(_math "$_i + 1")
  done

  if [ "$_option_key_value_delimiter" != " " ] && [ "$_options_combination" != "$1" ]; then
    _option_args=${1#*"$_option_key_value_delimiter"}

    if [ ${#_options_combination} -gt 2 ] && (_is_not "$_options_combination_args_allowed"); then
      _err "Arguments after short options combination are not allowed: $_option_args."
    fi

    _parse_option_args "$_option_args"
  fi

  if [ ${#_options_combination} -gt 2 ] && (_is_not "$_options_combination_allowed"); then
    _option_index=0
  fi
}

_use_option() {
  if [ "$_positional_args_placement" = "after_options" ] && [ "$_positional_args_count" -gt 0 ]; then
    _err "Positional arguments must be placed before options: $_positional_args_1."
  fi

  _option_index=$(_get_mapped_option_index_by_alias "$1")

  if [ -z "$_option_index" ]; then
    if _mapped_options_only; then
      _err "Unknown option: $1."
    else
      _map_option_auto "$1"
      _option_index=$_mapped_options_count
    fi
  elif (_is_not "$_option_duplicates_allowed") && (_is "$(_var_value "_options_${_option_index}_used")"); then
    _err "Option is already used: $1."
  fi

  _assign "_options_${_option_index}_used" "true"
  _assign "_options_${_option_index}_used_alias" "$1"
}

_parse_option_args() {
  _old_ifs=$IFS
  IFS=$_option_values_delimiter

  for _option_arg in $1; do
    _parse_option_arg "$_option_arg"
  done

  IFS=$_old_ifs
}

_parse_option_arg() {
  _option_arg_index=$(_math "$(_var_value "_options_${_option_index}_args_count") + 1")
  _max_args_count=$(_var_value "_options_${_option_index}_max_args")

  if [ -n "$_max_args_count" ] && [ "$_option_arg_index" -gt "$_max_args_count" ]; then
    _err "Maximum $_max_args_count argument(s) allowed for option: $(_var_value "_options_${_option_index}_used_alias")."
  fi

  _assign "_options_${_option_index}_args_${_option_arg_index}" "$1"
  _assign "_options_${_option_index}_args_count" "$_option_arg_index"

  _variable="$(_var_value "_options_${_option_index}_variable")"

  if [ -n "$_variable" ]; then
    _assign "$_variable" "$1"
  fi
}

_use_command() {
  _command_index=$(_get_mapped_command_index_by_name "$1")

  if [ -z "$_command_index" ]; then
    if [ "$_accept_command" = "mapped_only" ]; then
      _err "Unknown command: $1."
    fi

    _map_command_auto "$1"
    _command_index=$_mapped_commands_count
  fi

  _used_command_index=$_command_index
}


_get_command() {
  _var_value "_commands_${_used_command_index}_name"
}

_is_used_command() {
  _command_index=$(_get_mapped_command_index_by_name "$1")
  [ -n "$_command_index" ] && [ -n "$_used_command_index" ] && [ "$_command_index" -eq "$_used_command_index" ]
}

_get_positional_args() {
  _delimiter=${1:-" "}


  if [ "$_positional_args_count" -gt "1" ]; then
    _positional_args=""

    _i=1
    while [ "$_i" -le "$_positional_args_count" ]; do
        _positional_arg=$(_var_value "_positional_args_${_i}")
        _positional_args="${_positional_args}${_delimiter}${_positional_arg}"
        _i=$(_math "$_i + 1")
    done

    echo "${_positional_args#"$_delimiter"}"
  fi
}

_get_positional_args_count() {
  echo  "$_positional_args_count"
}

_get_positional_arg() {
  if [ -z "$1" ]; then
    _err "Missing positional argument index."
  fi

  if ! _is_int "$1" || [ "$1" -lt 1 ]; then
    _err "Invalid positional argument index: $1. Must be a positive integer."
  fi

  if [ "$_positional_args_count" -ge "$1" ]; then
    _var_value "_positional_args_$1"
  fi
}

_is_used_option() {
  _option_index=$(_get_mapped_option_index_by_alias "$1")
  [ -n "$_option_index" ] && _is "$(_var_value "_options_${_option_index}_used")"
}

_get_option_args() {
  _option_index=$(_get_mapped_option_index_by_alias "$1")
  _delimiter=${2:-" "}

  _option_args=""
  if [ -n "$_option_index" ]; then
    _option_args_count=$(_var_value "_options_${_option_index}_args_count")

    _i=1
    while [ "$_i" -le "$_option_args_count" ]; do
        _arg=$(_var_value "_options_${_option_index}_args_${_i}")
        _option_args="${_option_args}${_delimiter}${_arg}"
        _i=$(_math "$_i + 1")
    done

    echo "${_option_args#"$_delimiter"}"
  fi
}

_get_option_args_count() {
  _option_index=$(_get_mapped_option_index_by_alias "$1")

  if [ -n "$_option_index" ]; then
    _args_count=$(_var_value "_options_${_option_index}_args_count")
  fi

  echo "${_args_count:=0}"
}

_get_option_arg() {
  if [ -z "$1" ]; then
    _err "Missing option alias."
  fi

  if [ -z "$2" ]; then
    _err "Missing option argument index."
  fi

  if ! _is_int "$2" || [ "$2" -lt 1 ]; then
    _err "Invalid option argument index: $1. Must be a positive integer."
  fi

  _option_index=$(_get_mapped_option_index_by_alias "$1")

  if [ -n "$_option_index" ]; then
    _args_count=$(_var_value "_options_${_option_index}_args_count")

    if [ -n "$_args_count" ] && [ "$_args_count" -ge "$2" ]; then
      _var_value "_options_${_option_index}_args_$2"
    fi
  fi
}