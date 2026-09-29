#!/bin/sh
set -eu
cd "$(dirname "$0")"
NAME=BeeHanBrightness
swiftc -O -swift-version 5 main.swift -o "$NAME"
# Two instances would fight over gamma and the brightness keys.
pkill -x "$NAME" || true
# Bare binary: TCC attributes Accessibility to the terminal, so grant it there.
exec ./"$NAME"
