#!/usr/bin/env bash

module_cmd_available() {
  type module >/dev/null 2>&1
}

module_load_test() {
  local mod="$1"
  bash -lc "source /etc/profile >/dev/null 2>&1 || true; module purge >/dev/null 2>&1 || true; module load '$mod'" >/dev/null 2>&1
}

module_show_contains() {
  local mod="$1"
  local pattern="$2"
  bash -lc "source /etc/profile >/dev/null 2>&1 || true; module show '$mod' 2>&1" | grep -q -- "$pattern"
}

list_available_modules() {
  if module --redirect -t avail >/dev/null 2>&1; then
    module --redirect -t avail 2>/dev/null | sort -f
  else
    module -t avail 2>&1 | awk '!/^\// {print $1}' | sort -f
  fi
}
