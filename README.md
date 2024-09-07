# Sh args parser

This is POSIX-compliant code for parsing shell script arguments. It helps you focus on writing the script logic by separating argument parsing and basic validation.

## Contents

1. [Installation](#installation)
2. [Usage](#usage)
3. [Syntax conventions](#argument-syntax-conventions)
4. [Configuration](#configuration)
5. [Functions](#functions)
6. [License](#license)


## Installation

Include the `parser.sh` file in your script using [`dot`](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#dot) or [`source`](https://www.gnu.org/software/bash/manual/bash.html#index-source).

```bash
#!/usr/bin/env sh
. parser.sh
```

Or copy the contents of the `parser.sh` file into your script.

## Usage

The parser provides functions for working with arguments. They become available after passing all script arguments to the parser using `_parse`:

```bash
#!/usr/bin/env sh
. parser.sh

# In most cases, all script arguments are passed to _parse: $@.
_parse --foo bar baz

_is_used_option '--foo' && echo "Option 'foo' is used"
_get_option_args_count '--foo'
_get_option_arg '--foo' 2
```
```
Option 'foo' is used
2
baz
```

### What's next?

1. [Learn about the argument syntax.](#argument-syntax-conventions)
2. [Configure the parser to suit your needs.](#configuration)
3. [Map commands.](#_map_command)
4. [Map options.](#_map_option)
5. [Learn about the functions for working with parsing results.](#functions-for-working-with-parsing-results)

## Argument Syntax Conventions

The argument syntax is based on, but does not fully comply with, the conventions used in POSIX <sup>[1](https://www.gnu.org/software/libc/manual/html_node/Argument-Syntax.html), [2](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html)</sup>.

### General
- Commands, options, and positional arguments are separated by spaces.
- All script arguments are case-sensitive.

### Commands
A command typically represents the core action performed by the script: `run`, `build`, `issue`, etc. If the script is designed to perform a single action, a command is generally not required.

- A script may or may not accept a command.
- If the script accepts a command, it must be the first argument.
- A command can contain Latin letters, digits, `-`, and `_`.

### Positional Arguments

- Positional arguments are placed after the command, if present.
- The presence and number of positional arguments are determined by the script's logic.
- After the special argument --, all arguments are considered positional. This allows passing arguments that start with a dash and might be confused with options.

### Options
Options are script parameters. Each option has at least one alias by which it can be specified in the command line. Options often have both short and long aliases, such as `-h` and `--help`.

- Short aliases start with `-` and consist of a single Latin letter;
- Long aliases start with `--` and consist of Latin letters, digits, `-`, and `_`;
- Short aliases can be used individually or combined. For example, `-b -a -r` is equivalent to `-bar`;
- Options may have arguments. The presence and number of arguments are determined by the specific option and the script's logic.

## Configuration

Configuration is defined by assigning values to variables before using the parser. For example:

```bash
_accept_command=true
```
Configuration variables must be assigned before calling `_parse`.

| Name | Default Value | Description |
| --- | --- | --- |
| _accept_command | `auto` | `any` — The script accepts a command.<br>`none` — The script does not accept a command.<br>`mapped_only` — The script accepts only a mapped command.<br>`auto` — The script accepts a command if at least one has been mapped. |
| _accept_options | `auto` | `any` — The script accepts any options.<br>`none` — The script does not accept any options.<br>`mapped_only` — The script accepts only mapped options.<br>`auto` — The script accepts only mapped options if at least one has been mapped. Otherwise, it accepts any options. |
| _default_max_positional_args |  | Maximum number of positional arguments. A different value can be set for each command (see [_map_command](#_map_command)). |
| _default_min_positional_args | `0` | Minimum number of positional arguments. A different value can be set for each command (see [_map_command](#_map_command)). |
| _default_positional_arg_variable || Name of the variable that will store the single positional argument. Implicitly sets `_default_max_positional_args` and `_default_min_positional_args` to 1. Command-specific values for `max_args` and `arg_variable` disables this behavior. |
| _mapping_key_value_delimiter | `=` | Key-value delimiter for options mapping (see [_map_option](#_map_option)). |
| _mapping_values_delimiter | `,` | Values delimiter for options mapping (see [_map_option](#_map_option)). |
| _option_duplicates_allowed | `false` | `true` — Multiple uses of options are allowed.<br>`false` — Multiple uses of options are not allowed.|
| _option_key_value_delimiter | `' '` | Option alias-args delimiter. |
| _option_values_delimiter | `' '` | Option values delimiter. |
| _options_combination_allowed | `true` | `true` — Combining short option aliases into combinations is allowed.<br>`false` — Combining short option aliases is not allowed. |
| _options_combination_args_allowed | `true` | `true` — Passing arguments to the last option in a combination is allowed.<br>`false` — Passing arguments to the last option in a combination is not allowed. |
| _positional_args_placement | `any` | `any` — Positional arguments can be placed anywhere, including mixed with options.<br>`before_options` — Positional arguments are placed before options.<br>`after_options` — Positional arguments are placed after options. |

## Functions

#### _parse
Parses the provided arguments. Typically, takes all command-line arguments `$@` as input.
```bash
# Parser configuration, command and option mapping above

_parse $@

# Script logic below
```

### Functions for command and option mapping

Mapping functions are used to specify the available commands and options of the script, as well as for their basic validation. Mapping functions must be used before calling `_parse`.

#### _map_command

Maps a command. Takes key-value pairs as arguments. Key and values list are separated by `_mapping_key_value_delimiter`.

| Key | Description |
| --- | --- |
| name | Command name. Required key. |
| description | Command description. Currently not used. |
| min_args | Minimum number of positional arguments when using the command. |
| max_args | Maximum number of positional arguments when using the command. |
| arg_variable | Name of the variable that will store the command's positional argument. Implicitly sets `min_args` and `max_args` to 1. |

```bash
_map_command \
  name=foo \
  min_args=1 \
  max_args=2
```

### _map_option

Maps an option. Takes key-value pairs as arguments. Key and values list are separated by `_mapping_key_value_delimiter`. Values of the same key are separated by `_mapping_values_delimiter`.

| Key | Description |
| --- | --- |
| aliases | List of option aliases. Required key. |
| description | Option description. Currently not used. |
| min_args | Minimum number of option arguments. |
| max_args | Maximum number of option arguments. |
| variable | Name of the variable that will store option's argument when the option is used. Implicitly sets `min_args` and `max_args` to 1. |
| required | If the `required` flag is present, the option will be considered mandatory. |

```bash
_map_option \
  aliases=-f,--foo \
  min_args=1 \
  max_args=10 \
  required
```

### Functions for working with parsing results

#### _get_command

Outputs the used command.

```bash
_accept_command=true

_parse foo bar baz

_get_command
```

```
foo
```

#### _is_used_command

Checks if the command passed as the first argument was used.

```bash
_accept_command=true

_parse foo bar baz

_is_used_command foo && echo 'Command "foo" was used'
_is_used_command bar && echo 'Command "bar" was used'
```
```
Command "foo" was used
```

#### _get_positional_args_count

Outputs the number of positional arguments.

```bash
_parse foo bar baz
_get_positional_args_count
```
```
3
```

#### _get_positional_arg

Outputs the positional argument at the index passed as the first argument. Indexes start from 1.

```bash
_parse foo bar baz
_get_positional_arg 3
```
```
baz
```

#### _is_used_option

Checks if the option with the alias passed as the first argument was used.

```bash
_parse foo --bar -abc

_is_used_option foo && echo 'Option "--foo" was used'
_is_used_option --bar && echo 'Option "--bar" was used'
_is_used_option bar && echo 'Option "bar" was used'
_is_used_option -c && echo 'Option "-c" was used'

```
```
Option "--bar" was used
Option "-c" was used
```

#### _get_option_args_count

Outputs the number of arguments for the option with the alias passed as the first argument.

```bash
_parse -o foo bar baz

_get_option_args_count -o
```
```
3
```

#### _get_option_arg

Outputs the argument for the option with the alias passed as the first argument, at the index provided as the second argument. Indexes start from 1.

```bash
_parse -o foo bar baz

_get_option_arg -o 3
```
```
baz
```

## TODO
- Add "Debug" mode with verbose output;
- Bug: required + variable/variable_value makes no sense as it makes option variable constant;
- Add examples;
- Implement "Help" generation;
- Add tests.

## License

This project is licensed under the terms of the MIT license.