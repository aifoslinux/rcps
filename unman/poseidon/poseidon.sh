#!/bin/bash

cd /lib/poseidon

export PYTHONPATH=$(pwd)
export MOZ_PLUGIN_PATH=$HOME/.mozilla/plugins:/lib/mozilla/plugins:$HOME/.poseidon/plugins

# Should be ready for Wayland!
# export GDK_BACKEND=x11

python3 ./poseidon.py "$@"
