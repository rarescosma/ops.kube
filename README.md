A library of shell scripts that I use to manage my local k8s cluster.

Features:
* it works with both `docker` and `lxc` as the virtualization component for the k8s nodes (the master and the workers)
* docker registry daemonset on each worker
* wrapper script for all the commands
* very bad documentation

Have a look at `share/env.sh.sample` for an idea of what can be configured. 
