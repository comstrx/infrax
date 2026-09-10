#!/usr/bin/env bash

log () {

    printf '%s\n' "$*" >&2

}
info () {

    printf 'ℹ️  %s\n' "$*" >&2

}
warn () {

    printf '⚠️  %s\n' "$*" >&2

}
succ () {

    printf '✅ %s\n' "$*" >&2

}
err () {

    printf '❌ %s\n' "$*" >&2

}
step () {

    printf '🚀 %s\n' "$*" >&2

}
die () {

    err "$*"
    exit 1

}
