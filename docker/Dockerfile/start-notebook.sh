#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

set -e

USER=jovyan

chown $USER:users /home/$USER/work

su -c "export PATH=/opt/conda/bin/:$PATH;. /usr/local/bin/start.sh jupyter notebook $*" -m $USER
