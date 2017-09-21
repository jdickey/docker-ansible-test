#!env bash

##
# Droplet functions -- convenience functions for running our Ansible Playbooks
#
# Created and maintained by [Jeff Dickey](https://github.com/jdickey).
#
# We have three "higher-order" functions, which are what you'll probably want to
# use most of the time, and several task-specific functions to run individual
# Playbooks.
#
# # FUNCTIONS
#
# The primary functions are:
#
# 1. `create_and_provision_droplet`
#    Taking an optional 'timeout' parameter that defaults to 30 (seconds), this
#    function calls each of the task-specific functions in turn (see below for
#    details):
#    a. `new_droplet`
#    b. `provision_droplet`
#    c. `setup_docker_on_droplet`
#    d. `update_floating_ip`
#
# 2. `remove_droplet`
#    Taking an optional "Droplet name" parameter that defaults to `new-demo` (to
#    match the current value of `droplet_name` in the `do_droplet_vars` file),
#    this function lists the current Droplets, limiting to the specified Droplet
#    name, and then extracts the Droplet ID number if found. If there is no
#    Droplet matching the name, an error message is produced and the function
#    returns a value of 1. Assuming we've gotten the Droplet ID, that's passed
#    as the "extra variable" `droplet_id` to the `remove_droplet.yml` Playbook.
#    **NOTE** that this function requires that the [`doctl`](https://github.com/digitalocean/doctl)
#    utility be installed on the host executing this function.
#
# 3. `rename_and_retag_droplet` will rename the Droplet created and provisioned
#    by the earlier functions, which by default presently is set to `new_demo`.
#    This will allow for a more meaningful report when listing running/available
#    Droplets. This function **must** be executed explicitly, separately, after
#    `create_and_provision_droplet` has successfully completed.
#
# # SECONDARY FUNCTIONS
#
# 1. `new_droplet` runs the `new_droplet.yml` Playbook to create a new Droplet.
#    a. Like each of the functions that directly invoke Playbooks, this uses the
#       `--vault-password` option to tell Ansible where to find the password to
#       decrypt the `secret` file.
#    b. Like the `provision_droplet` function, this invokes `ansible-playbook`
#       with the `ANSIBLE_HOST_KEY_CHECKING` variable set to `False`. This tells
#       Ansible not to verify that the host being addressed has a matching entry
#       in the local `~/.ssh/authorized_keys` file. See the Ansible "Getting
#       Started" docs under "Host Key Checking".
#    c. Uniquely among these functions, this uses the `--ssh-common-args`
#       command-line parameter for `ansible-playbook` to force `ssh` to disable
#       strict host-key checking. (This is separate from the instruction given
#       to Ansible in (b) above.) This is essential since there shoudl be *no*
#       key for the target host in the `authorized_keys` file yet.
#    d. When invoking the Playbook, this function *does not* supply an Ansible
#       inventory, either dynamic or static. The Playbook invoked here runs on
#       `localhost`, and does not make any use of previously-provisioned host
#       data.
#    e. After successfully creating a Droplet, this function tags it with the
#       `in_process` tag. This allows other scripts (see `provision_droplet`) to
#       search a dynamically-created Ansible inventory for the Droplet address.
# 2. `provision_droplet` runs the `provision_droplet` Playbook to run OS-level
#    provisioning on a newly-created Droplet. This includes creating an ordinary
#    unprivileged user, configuring the firewall, and updating software already
#    installed on the system.
#    a. Like each of the functions that directly invoke Playbooks, this uses the
#       `--vault-password` option to tell Ansible where to find the password to
#       decrypt the `secret` file.
#    b. Like the `new_droplet` function, this invokes `ansible-playbook` with
#       the `ANSIBLE_HOST_KEY_CHECKING` variable set to `False`. This tells
#       Ansible not to verify that the host being addressed has a matching entry
#       in the local `~/.ssh/authorized_keys` file. See the Ansible "Getting
#       Started" docs under "Host Key Checking".
#    c. This function tells `ansible-playbook` to invoke a dynamic inventory
#       script (`digital_ocean.py`) to produce an Ansible inventory which the
#       Playbook can examine to find the Droplet created by `new_droplet`.
#    d. The final tasks of the Playbook invoked by this function tags the Droplet
#       with a `provisioned` tag, then removes the `in_process` tag attached by
#       `new_droplet`, in that order.
# 3. `setup_docker_on_droplet` runs an Ansible Playbook to get a Docker image up
#    and running on the Droplet provisioned by `provision_droplet`.
#    a. Like each of the functions that directly invoke Playbooks, this uses the
#       `--vault-password` option to tell Ansible where to find the password to
#       decrypt the `secret` file.
#    b. This function tells `ansible-playbook` to invoke a dynamic inventory
#       script (`digital_ocean.py`) to produce an Ansible inventory which the
#       Playbook can examine to find the Droplet created by `new_droplet` and
#       provisioned by `provision_droplet`.
#    c. The final tasks of the Playbook invoked by this function tags the Droplet
#       with a "final droplet tag" as defined in the `running_droplet_details`
#       variable file, then removes the `provisioned` tag attached by
#       `provision_droplet`, in that order.
#    d. **NOTE** that the tag name applied in (d) above **will change** after
#       adding implementations for our `rename_and_retag_droplet` and
#       `update_floating_ip` functions, as below.
# 4. `update_floating_ip` unassigns a Floating IP address (whose value is read
#    from the `running_droplet_details` variable file), then assign it to the
#    Droplet created by the earlier functions. It also re-tags the Droplet using
#    a distinct tag which will then be used by `rename_and_retag_droplet`.
#
# # ENVIRONMENT VARIABLES
#
# 1. Several of these functions use the Ansible-defined `ANSIBLE_HOST_KEY_CHECKING`
#    environment variable, which may or may not already be set when the
#    functions are called. Any existing value assigned will be preserved across
#    function calls; i.e., these functions require explicitly setting the value,
#    but any existing value will be restored after the functions' use of it is
#    completed.
# 2. If the `OTHER_OB_ARGS` variable is set, it will be passed as additional
#    command-line parameter(s) to `ansible-playbook`. One possible use for this
#    is to set verbosity levels; e.g., `-v` simply shows the result of each task
#    in the Playbooks being run; `-vvvv` displays full debugging information.
##

function new_droplet() {
  local saved_ahkc=${ANSIBLE_HOST_KEY_CHECKING:-''}
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook new_droplet.yml --vault-password=./.vault-password --ssh-common-args='-o StrictHostKeyChecking=no' $OTHER_PB_ARGS
  if [[ $saved_ahkc ]]; then
    export ANSIBLE_HOST_KEY_CHECKING=$saved_ahkc
  else
    unset ANSIBLE_HOST_KEY_CHECKING
  fi
}

function provision_droplet() {
  local saved_ahkc=${ANSIBLE_HOST_KEY_CHECKING:-''}
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook provision_droplet.yml -i ./digital_ocean.py --vault-password=./.vault-password $OTHER_PB_ARGS
  if [[ $saved_ahkc ]]; then
    export ANSIBLE_HOST_KEY_CHECKING=$saved_ahkc
  else
    unset ANSIBLE_HOST_KEY_CHECKING
  fi
}

function rename_and_retag_droplet() {
  ansible-playbook rename_and_retag_droplet.yml -i ./digital_ocean.py --vault-password=./.vault-password $OTHER_PB_ARGS
}

function setup_docker_on_droplet() {
  local saved_ahkc=${ANSIBLE_HOST_KEY_CHECKING:-''}
  ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook setup_docker.yml -i ./digital_ocean.py --vault-password=./.vault-password $OTHER_PB_ARGS
  if [[ $saved_ahkc ]]; then
    export ANSIBLE_HOST_KEY_CHECKING=$saved_ahkc
  else
    unset ANSIBLE_HOST_KEY_CHECKING
  fi
}

function update_floating_ip() {
  ansible-playbook update_floating_ip.yml -i ./digital_ocean.py --vault-password=./.vault-password $OTHER_PB_ARGS
}

function create_and_provision_droplet() {
  local timeout=${1:-30}
  new_droplet
  sleep $timeout
  provision_droplet
  setup_docker_on_droplet
  update_floating_ip
}

function remove_droplet() {
  local droplet_name=${1:-new-demo}
  local droplet_id=`doctl compute droplet list $droplet_name --no-header --format "ID"`
  if [[ ! $droplet_id ]]; then
    echo "Unable to find Droplet ID for $droplet_name"
    return 1
  fi
  ansible-playbook remove_droplet.yml --vault-password=./.vault-password -e droplet_id=$droplet_id $OTHER_PB_ARGS
}
