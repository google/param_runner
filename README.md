# param_runner

`param_runner.sh` is a minimalistic task batching / queueing tool built on top of `etcd` version 3, written as a bash script library.

In order to use `param_runner`, write your own task as a bash function that takes parameters to partition work item, then pass the function as an argument to `param_runner::run`. The following example illustrates the usage of this library end to end.

## Installation

`etcdctl` commandline tool is required. See [etcd](https://github.com/coreos/etcd) document for instructions on getting `etcd`, which also bundles `etcdctl`. You can either put `etcdctl` in PATH, or path to `etcdctl` can be specified by `--param_runner_etcdctl_bin` flag.

Apart from `bash`, `coreutils` and `etcdctl` executable, the only external dependency is [jq](https://stedolan.github.io/jq/) used for commandline json parsing. `jq` is widely available as binary package in most popular OS distributions. In Ubuntu, install `jq` by doing:

```shell
$ sudo apt-get install jq
```

## Example

Suppose we have a simple addition calculating job defined (see [the included example](example/calc_and_sleep_etcd.sh) for the full example):

```shell
#!/bin/bash

source path/to/param_runner_etcd.sh || exit 1

FLAGS "$@" || exit 1
set -- "${FLAGS_ARGV[@]}"
extra_flags=( "$@" )

function run {
  echo "Task example $1: $2 + $3 = $(($2 + $3))"
  echo "${extra_flags[@]}"
}

param_runner::run run

```

Note that `param_runner.sh` sources `shflags`, and it is the wrapping script's job to initialize `FLAGS` (after defining its own flags). This job takes three parameters, the name of task and two numbers whose sum will be an output of the job. Also note the `extra_flags` handling. This allows us to specify parameters at run time independent of the parameter sets. Now run the example:

```shell
$ ./example/calc_and_sleep_etcd.sh -- --some --extra=argument
```

You will see the following message, among other messages:

```
Listing /ls/test/home/$USER/param_runner/param to find any param set to work on
```

Note that `/ls/test/home/$USER/param_runner` is the default base path. This can be overridden with `--param_runner_base_path` flag.

Note that we use `etcdctl` version 3 API.

```shell
$ export ETCDCTL_API=3
```

Now we can enqueue some tasks by placing parameter sets under `/param/`: 

```shell
$ for i in {1..10}; do
  etcdctl put /ls/test/home/$USER/param_runner/param/$i "${i}plusTen $i 10"
done
```

You will see the example program start processing the tasks:

```
Running with parameter set found at /ls/test/home/$USER/param_runner/param/1
Task example 1plusTen: 1 + 10 = 11
--some --extra=argument
Parameter set 1 succeeded

...etc
```

We can see the execution results by listing /result path:

```shell
$ etcdctl get --prefix /ls/test/home/$USER/param_runner/result
/ls/test/home/username/param_runner/result/20160901220004_SUCCESS_1_hostname_33783
1plusTen 1 10
/ls/test/home/username/param_runner/result/20160901220014_SUCCESS_10_hostname_33783
10plusTen 10 10
/ls/test/home/username/param_runner/result/20160901220025_SUCCESS_2_hostname_33783
2plusTen 2 10
/ls/test/home/username/param_runner/result/20160901220035_SUCCESS_3_hostname_33783
3plusTen 3 10
...etc
```

If there is any failure, you will see `_FAIL_` instead of `_SUCCESS_`. The content of these files will be identical to the very parameter given.

Once we are done with the tasks, we can place poison pill so that the param runner will exit gracefully.

```shell
$ etcdctl put /ls/test/home/$USER/param_runner/poison_pill "."
```

The example program will now exit:

```
Poison pill found, exiting
```

### Deployment with Docker

See the included example [Docker file](Dockerfile.example).

## Disclaimer

This is not an official Google product.
