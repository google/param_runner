#!/bin/bash
#
# Copyright 2016 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

source $( dirname "${BASH_SOURCE[0]}" )/../src/param_runner_etcd.sh || exit 1

FLAGS "$@" || exit 1
set -- "${FLAGS_ARGV[@]}"
extra_flags=( "$@" )

function run {
  echo "Task example $1: $2 + $3 = $(($2 + $3))"
  echo "${extra_flags[@]}"
  # Sleep in a child process, to test signal trapper.
  bash -c "sleep 10"
}

param_runner::run run
