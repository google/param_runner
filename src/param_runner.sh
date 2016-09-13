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

source $( dirname "${BASH_SOURCE[0]}" )/../third_party/shflags

DEFINE_string param_runner_base_path "/ls/test/home/$USER/param_runner" "Base directory to param runner keys" "~"
DEFINE_integer param_runner_poll_interval 10 "Polling interval in seconds" "~"

PARAM_RUNNER_CURRENT_PARAM_SET=""
PARAM_RUNNER_CURRENT_PID=-1

# Performs any initialization tasks necessary.
#
# Args:
#   string: base path
function param_runner::_init {
  param_runner::_log "param_runner::_init not implemented, skipping"
}

# Returns success state if the given path exists.
#
# Args:
#   string: path to test
function param_runner::_exist {
  param_runner::_log "param_runner::_exist not implemented, exiting"
  exit 1
}

# Copies key content from source path to destination path.
#
# Args:
#   string: source path
#   string: destination path
function param_runner::_cp {
  param_runner::_log "param_runner::_cp not implemented, exiting"
  exit 1
}

# Deletes key at the given path.
#
# Args:
#   string: path of key to delete
function param_runner::_rm {
  param_runner::_log "param_runner::_rm not implemented, exiting"
  exit 1
}

# Atomically select one parameter set ${base_path}/param/${param_set} and move to running sub directory ${base_path}/running/${param_set}
# Args:
#   string: base path
# Output:
#   string: path to new parameter set under running sub directory, or empty if there is none.
function param_runner::_atomic_find_new {
  param_runner::_log "param_runner::_atomic_find_new not implemented, exiting"
  exit 1
}

# Outputs the content of the given path.
#
# Args:
#   string: path to the key
# Output:
#   string: content of the key
function param_runner::_get {
  param_runner::_log "param_runner::_get not implemented, exiting"
  exit 1
}

function param_runner::_log {
  >&2 echo $(date -Ins) param_runner $@
}

function param_runner::_result_path {
  echo $(date +%Y%m%d%H%M%S)_$1_$2_$(hostname -s)_$$
}

function param_runner::_trapper {
  local path=${FLAGS_param_runner_base_path}

  if [ -n "$PARAM_RUNNER_CURRENT_PARAM_SET" ]; then
    param_runner::_log "Termination signal trapped. Restoring parameter set ${PARAM_RUNNER_CURRENT_PARAM_SET}"
    param_runner::_cp "${path}/running/$PARAM_RUNNER_CURRENT_PARAM_SET" ${path}/result/$(param_runner::_result_path ABORTED ${PARAM_RUNNER_CURRENT_PARAM_SET})
    # Restore parameter set to param directory so that other worker can pick up the task.
    param_runner::_cp "${path}/running/$PARAM_RUNNER_CURRENT_PARAM_SET" "${path}/param/$PARAM_RUNNER_CURRENT_PARAM_SET"
  fi

  if (( "$PARAM_RUNNER_CURRENT_PID" > -1 )); then
    param_runner::_log "Terminating child processes"
    local cid
    for cid in $(pgrep -P "$PARAM_RUNNER_CURRENT_PID"); do
      param_runner::_log "Terminating process $cid"
      kill "$cid"
      wait "$cid"
    done
    param_runner::_log "Terminating main process $PARAM_RUNNER_CURRENT_PID"
    kill "$PARAM_RUNNER_CURRENT_PID"
    wait "$PARAM_RUNNER_CURRENT_PID"
  fi

  exit
}

function param_runner::run {
  local path=${FLAGS_param_runner_base_path}
  local interval=${FLAGS_param_runner_poll_interval}

  param_runner::_init ${path}

  trap param_runner::_trapper SIGABRT SIGINT SIGTERM

  while ((1)); do
    param_runner::_log "Testing if there is a poison pill at $path/poison_pill"
    if param_runner::_exist "${path}/poison_pill"; then
      param_runner::_log "Poison pill found, exiting"
      break
    fi

    param_runner::_log "Listing $path/param to find any param set to work on"

    # Atomically try fetch and move one work item.
    local param_set=$( param_runner::_atomic_find_new ${path} )
    if [ -z "$param_set" ]; then
      param_runner::_log "No parameter set found, sleeping $interval seconds..."
      sleep "${interval}"
      continue
    fi
    param_runner::_log "Running with parameter set found at $path/param/$param_set"
    PARAM_RUNNER_CURRENT_PARAM_SET="$param_set"

    # SC2046 advises to put $() in quotes in order to prevent word splitting. However, in our case, since the file contains parameters, we do want word splitting. Hence disabling linting option.
    # shellcheck disable=SC2046

    # Run task in background process, so that the param runner process can trap signals.
    ( $1 $( param_runner::_get "$path/running/$param_set" ) ) &
    # shellcheck enable=SC2046
    PARAM_RUNNER_CURRENT_PID=$!

    if wait "$PARAM_RUNNER_CURRENT_PID"; then
      param_runner::_log "Parameter set $param_set succeeded"
      param_runner::_cp "$path/running/$param_set" ${path}/result/$(param_runner::_result_path SUCCESS ${param_set})
    else
      param_runner::_log "Parameter set $param_set failed"
      param_runner::_cp "$path/running/$param_set" ${path}/result/$(param_runner::_result_path FAIL ${param_set})
    fi

    PARAM_RUNNER_CURRENT_PID=-1
    PARAM_RUNNER_CURRENT_PARAM_SET=""
    param_runner::_rm "$path/running/$param_set"
  done
}
