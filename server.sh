#!/usr/bin/env bash
set -euo pipefail

export REG_PRINT_HOME="${REG_PRINT_HOME:-${HOME:-$PWD}}"

mix phx.server
