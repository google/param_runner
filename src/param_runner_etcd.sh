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

source $( dirname "${BASH_SOURCE[0]}" )/param_runner.sh
DEFINE_string param_runner_etcdctl_bin "$(which etcdctl)" "Path to etcdctl binary" "~"
DEFINE_string param_runner_etcdctl_args "" "Additional args to pass to etcdctl" "~"

export ETCDCTL_API=3
PARAM_RUNNER_ETCDCTL=

function param_runner::_init {
  param_runner::_log "Testing connection to etcd"
  PARAM_RUNNER_ETCDCTL=( ${FLAGS_param_runner_etcdctl_bin} ${FLAGS_param_runner_etcdctl_args} )
  "${PARAM_RUNNER_ETCDCTL[@]}" get $1 || exit 1
  "${PARAM_RUNNER_ETCDCTL[@]}" txn <<< "ver(\"$1/tasklock\") > \"0\"


put $1/tasklock "."

"
}

function param_runner::_exist {
  [ -n "$( "${PARAM_RUNNER_ETCDCTL[@]}" get $1)" ]
}

function param_runner::_cp {
  local content=$( param_runner::_get $1 )
  "${PARAM_RUNNER_ETCDCTL[@]}" put $2 -- "${content}"
}

function param_runner::_rm {
  "${PARAM_RUNNER_ETCDCTL[@]}" del $1
}

function param_runner::_atomic_find_new {
  local lockVer=$( "${PARAM_RUNNER_ETCDCTL[@]}" get $1/tasklock -w json | jq -r .kvs[0].version )
  local newParamFull=$( "${PARAM_RUNNER_ETCDCTL[@]}" get --prefix --keys-only --limit=1 $1/param/ )
  [ -z ${newParamFull} ] && return 1
  local newParam=${newParamFull#$1/param/}

  # Due to the limitation in etcdctl txn cli command, we put the value in base64 encoded form. In future once they support %q formatted string, we can switch to %q formatted string so that parameter values in /running/ directory will match the param set verbatim. See https://github.com/coreos/etcd/issues/6315.

  local newParamValueB64=$( "${PARAM_RUNNER_ETCDCTL[@]}" get ${newParamFull} -w json | jq -r .kvs[0].value )
  local txnResult=$( "${PARAM_RUNNER_ETCDCTL[@]}" txn <<<"ver(\"$1/tasklock\") = \"${lockVer}\"

put -- $1/running/${newParam} ${newParamValueB64}
del ${newParamFull}
put $1/tasklock "."


")

  param_runner::_log "Transaction result: $txnResult"
  local txnResultArr=(${txnResult})
  if [[ ${txnResultArr[0]} == "SUCCESS" ]]; then
    echo ${newParam}
  fi
}

function param_runner::_get {
  # Double decoding base64 because the content of the value is also in base64 form.
  "${PARAM_RUNNER_ETCDCTL[@]}" get $1 -w json | jq -r .kvs[0].value | base64 --decode | base64 --decode
}
