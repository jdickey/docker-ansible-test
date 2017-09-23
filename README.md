<h1>Docker Ansible "Test"</h1>

<h2>Contents</h2>

- [Introduction and Structure](#introduction-and-structure)
- [Usage](#usage)
- [Variables and Variable Files](#variables-and-variable-files)
  * [Policies](#policies)
  * [Variable Files](#variable-files)
    + [`do_droplet_vars`](#do_droplet_vars)
    + [`docker_app`](#docker_app)
    + [`running_droplet_details`](#running_droplet_details)
  * [`secret`](#secret)
- [Playbooks](#playbooks)
  * [`new_droplet.yml`](#new_dropletyml)
  * [`provision_droplet.yml`](#provision_dropletyml)
  * [`setup_docker.yml`](#setup_dockeryml)
  * [`update_floating_ip.yml`](#update_floating_ipyml)
  * [`rename_and_retag_droplet.yml`](#rename_and_retag_dropletyml)
  * [`remove_droplet.yml`](#remove_dropletyml)
- [Shell Functions](#shell-functions)
  * [`create_and_provision_droplet`](#create_and_provision_droplet)
  * [`remove_droplet`](#remove_droplet)
  * [`rename_and_retag_droplet`](#rename_and_retag_droplet)
- [Future Enhancements](#future-enhancements)
  * [Multiple Docker Containers](#multiple-docker-containers)
  * [Ansible Roles](#ansible-roles)
  * [Error Handling](#error-handling)
- [Legal](#legal)

## Introduction and Structure

First, this is a complete rewrite of the original `README` for this project. You may find the [earlier version](https://github.com/jdickey/docker-ansible-test/blob/aab81fc/README.md) interesting as a snapshot of where my mind was at at the time. (I think) I've learned a *lot* in the last month, particularly about Ansible, one of the most active projects I've seen in *decades.* It's literally impossible for a lone developer to wrap her head around everything in Ansible, or even everything that happens to the open-source [repo](https://github.com/ansible/ansible) in any given week. If you're coming across this wondering "how do I learn, then", the advice is to understand the [documentation](http://docs.ansible.com/ansible/latest/) at a broadly general level (particularly with regard to Playbooks, Roles, and `ansible-vault`), and then grok in fullness the modules you plan on using. Being familiar with [Ansible Galaxy](https://galaxy.ansible.com/) is a Good Idea, and the Ansible [Gitter channel](https://gitter.im/ansible/ansible) is *priceless.*

This was originally attempted as a single Playbook, before learning through experience why that's not really a good way to do things &mdash; at least, not when you're trying to incrementally make progress towards a (mostly) "fire-and-forget" deployment process. (What we now recommend is documented in the [Usage](#usage) section, below.)

There are presently six Ansible [Playbooks](#playbooks), each of which has a wrapper function defined in the [`droplet_functions.sh` script](#shell-functions), with additional functions defined for higher-level sequencing. The Playbooks (and their wrapper functions) automate the broad steps in deploying a DigitalOcean Droplet (VPS instance) running a single Docker container based on an image accessible via `docker pull`. (Presently, this would be a public image hosted on [Docker Hub](https://hub.docker.com/), although the process to add a private image source is localised and readily understood.) There is support for reassigning an existing FLoating IP to the new Droplet, as well as for removing an existing droplet, e.g., one replaced by a new deployment.

These Playbooks use [Ansible variables](http://docs.ansible.com/ansible/latest/playbooks_variables.html) and [dynamic inventories](http://docs.ansible.com/ansible/latest/intro_dynamic_inventory.html) in order to reduce the hard-coded [module](http://docs.ansible.com/ansible/latest/modules.html) parameters and other values which could possibly change between invocations or projects. A further Ansible technique for ease of reuse, [Roles](http://docs.ansible.com/ansible/latest/playbooks_reuse_roles.html), should be a primary topic of attention for near-future enhancement/revision of this project.

Several variables used by these Playbooks, such as passwords and API keys, are sensitive and should never be published in plaintext. These are encrypted using the [Ansible Vault](http://docs.ansible.com/ansible/latest/vault.html) utility, using a password that is stored in the `.vault-password` file in the project root. That `.vault-password` file, obviously, is and must be ignored by version control.

## Usage

1. First, read the [Playbooks](#playbooks) to understand how [variables and variable files](#variables-and-variable-files) are used.
2. Then, modify the variables _in_ the variable files to suit your needs. You can use the `ansible-playbook` command lines as shown in the [shell functions](#shell-functions) to test individual steps, rather than troubleshooting the high-level functions described in the next step.
3. Once you're confident that your variables have all been set properly, you're ready to run the high-level functions from the command line.
	1. If you haven't already, create a Floating IP using [DigitalOcean's dashboard](https://cloud.digitalocean.com/networking/floating_ips) or a command-line tool such as [`doctl`](https://github.com/digitalocean/doctl). Update the [`running_droplet_details`](#running_droplet_details) file accordingly;
	2. Run `source ./droplet_functions.sh` if you've made any changes to that file. You **do not** need to reload the functions if you've modified variable files or Playbooks;
	3. Run the [`create_and_provision_droplet`](#create_and_provision_droplet) function. That will run the Playbooks necessary to create, provision, and finalise your new Droplet, assigning a DigitalOcean-specified public IP(v4) address from which the Droplet is *immediately publicly accessible,* as well as the DigitalOcean Floating IP which you've correctly specified in the [`running_droplet_details`](#running_droplet_details) file. (Haven't you?)
	4. Assuming the newly-running Droplet replaces one previously associated with that Floating IP, remove the old Droplet using the [`remove_droplet`](#remove_droplet) function;
	5. Rename and re-tag the new Droplet to match your in-production standards using the [`rename_and_retag_droplet`](#rename_and_retag_droplet) function.

## Variables and Variable Files

Variables may be defined and redefined in a wide variety of places; the [documentation for precedence](http://docs.ansible.com/ansible/latest/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable) lists nearly two dozen levels, ranging from role defaults at the lowest precedence up to command-line-specified ["extra" vars](http://docs.ansible.com/ansible/latest/playbooks_variables.html#passing-variables-on-the-command-line). One of the implications of this is that values of variables may be overridden on an ad-hoc basis via Ansible "extra" vars; for example, to experiment by creating and provisioning a Droplet in a DigitalOcean [region](https://developers.digitalocean.com/documentation/v2/#regions) other than the default.

### Policies

1. All variables defined with sensitive values, such as API keys, **must** be encrypted using `ansible-vault`. A Git commit hook [**should** be in place](https://github.com/jdickey/docker-ansible-test/issues/6) to enforce this.
2. Variables which *do not* contain sensitive values **must not** be stored in the `ansible-vault`-encrypted variable file.
3. The password or passphrase used to encrypt and decrypt an encrypted variable file **must** be in a file which **must not** be added to version control. This **should** involve adding the password-containing file to `.gitignore` or equivalent.
4. All variables that are not simple reformatting of other variables (such as where `remote_user` is defined as `'{{ droplet_user_name }}'`) **must** be defined in a variable file.
5. No variable definition should be repeated in multiple variable files.
5. Variables which are specific to individual Playbooks **should** be stored in variable files distinct from those containing variables applicable to multiple Playbooks.

### Variable Files

#### `do_droplet_vars`

Defines variables used for creating a Droplet using the [`digital_ocean`](http://docs.ansible.com/ansible/latest/digital_ocean_module.html) module.

Used only by the `new_droplet.yml` Playbook.

The variables defined in this file include:

* `droplet_name`: the *initial* name assigned to the newly-created Droplet. The Droplet name will be changed in the final Playbook run to bring up a new Docker-container Droplet (`rename_and_retag_droplet.yml`);
* `image_id`: the slug for the Digital Ocean [image ID](https://developers.digitalocean.com/documentation/v2/#images) used to create the new Droplet. This can be an ID for a bare distribution, e.g., Ubuntu Linux or FreeBSD, or it can be an ID for a "one-click app" such as Docker on Ubuntu or Discourse on Ubuntu. (At the time of this writing, all DO one-click apps used Ubuntu 16.04 as the base OS.) For our present purposes, this will be set to `docker-16-04`, which will install Docker 17.05.0-ce on Ubuntu 16.04;
* `private_networking`: this tells the Docker API whether or not the new Droplet should support addressing via a privately-routed network address (10.x.x.x). The Playbooks assume this is set to `yes`;
* `region_id`: the DigitalOcean [region identifier](https://developers.digitalocean.com/documentation/v2/#regions) to create the Droplet in. (Remember that both Floating IPs and Droplets are tied to a specific DO region and **must** match);
* `size_id`: indicates the desired memory size of the Droplet to create. This can range from `512mb` up to `64gb`. Remember that memory size is the primary basis for DigitalOcean pricing;
* `ssh_key_ids`: documented as "[an] array containing the IDs or fingerprints of the SSH keys that you wish to embed in the Droplet's root account upon creation." In this context, "IDs" refers to a relatively short DO-internal identifier associated with an SSH key and visible via the [Settings/Security panel](https://cloud.digitalocean.com/settings/security?i=af3d74) of the Control Panel or via the [DigitalOcean API](https://developers.digitalocean.com/documentation/v2/#ssh-keys).

#### `docker_app`

Defines variables associated with a specific Docker image and its associated Git commit hash (unique identifier), as used by the `setup_docker.yml` Playbook. These include:

* `app_image_tag`: the bare repository name and version identifier as per Docker conventions, e.g, `grid_demo:dev4`;
* `docker_container_memory`: the amount of RAM specified as being used by the running Docker container; e.g., `64m` for 64 MB of RAM;
* `docker_container_name`: the name to assign to the running Docker container;
* `docker_hub_user`: the user name on Docker Hub or equivalent; used to query and then pull the Docker image;
* `git_hash_full`: the full 40-hexit SHA1 identifier of the (remote) Git commit tagged with the version identifier for the image to be used;
* `git_hash_short`: the first _n_ hexits of the value specified by `git_hash_full`, where _n_ is ordinarily 7 per GitHub convention.

#### `running_droplet_details`

Contains the DigitalOcean Droplet tag name and Floating IP address to be associated with a newly-set-up Droplet created and provisioned using the Playbooks.

Used by the following Playbooks:

* `setup_docker.yml`;
* `update_floating_ip.yml`; and
* `rename_and_retag_droplet.yml`.

### `secret`

As indicated by the name, this variable file contains sensitive information that must be kept secret; i.e., not published in a form susceptible to unauthorised cleartext access. As described earlier, this is accomplished via the `ansible_vault` utility.

This file includes passwords and API/SSH keys used by each of the Playbooks.

**NOTE:** This file will be renamed imminently to comply with the naming convention required by the Git pre-commit hook mentioned in Issue [#6](https://github.com/jdickey/docker-ansible-test/issues/6).

## Playbooks

Listed in the order in which they are normally used over an individual Droplet's lifecycle.

### `new_droplet.yml`

Creates a new Droplet (or overwrites an existing one with the initial name), then associates the Droplet with a DigitalOcean Droplet tag indicating that it is a newly-created, not-yet-provisioned Droplet.

Uses the variable files `secret` and `do_droplet_vars`.

### `provision_droplet.yml`

Finalises user and firewall setup on a Droplet created by the `new_droplet.yml` Playbook, associates the Droplet with a new `provisioned` tag and removes the `in_process` tag added by the previous Playbook.

Uses the `secret` variable file (but see Issue [#6](https://github.com/jdickey/docker-ansible-test/issues/6)).

### `setup_docker.yml`

Installs Python module support needed by the `docker` Ansible module, if not already installed. Pulls the appropriate Docker image and starts it as a running container. Finally, associates the Droplet with a new `docker_up` tag and removes the existing `provisioned` tag.

Note that the running container has several environment variables specified for it, which are based on the variables specified in the `docker_app` variable file. Like each of the other Playbooks, it also uses the `secret` variable file.

### `update_floating_ip.yml`

Reassigns an existing Floating IP to the recently-created and -provisioned Droplet. Ensures that the same HTTP content is served from the Droplet's direct public IP address and the Floating IP. Finally, associates the Droplet with a new `fip_set` tag and removes the `docker_up` tag added by the previous Playbook

In addition to the `secret` variable file, uses the variables defined in `running_droplet_details`.

### `rename_and_retag_droplet.yml`

Renames and retags a Droplet after assigning it a Floating IP using the `update_floating_ip.yml` Playbook. This assigns a new name for the Droplet and replaces the `fip_set` tag removed by the previous Playbook, based on the variables read from the `running_droplet_details` file (as well as the `secret` file).

**Note** that this Playbook uses the official DigitalOcean command-line utility, [`doctl`](https://github.com/digitalocean/doctl), since there is presently no support within Ansible for renaming Droplets.

After this Playbook has completed successfully, the Droplet created and set up by the sequence of Playbooks listed to this point is up and accepting HTTP connections on Port 80 on behalf of the application in the running Docker container.

**Note** also that, when replacing an existing Droplet, it may be desirable to run this Playbook after each of the preceding Playbooks *and* after removing the previous Droplet as well, using the `remove_droplet.yml` Playbook immediately below.

### `remove_droplet.yml`

Shuts down and removes a DigitalOcean Droplet. This Playbook requires a`droplet_id` variable to be defined, which *is not* defined within this Playbook or the `secret` variable file which it reads. This will ordinarily be defined on the command line using ["extra" vars](http://docs.ansible.com/ansible/latest/playbooks_variables.html#passing-variables-on-the-command-line).

## Shell Functions

The `droplet_functions.sh` file defines a set of (`bash`-compatible) functions that wrap invoking each of the listed Playbooks via `ansible-playbook`. To load them into your Terminal session, run `source ./droplet_functions.sh`. Each of the functions are documented in the `droplet_functions.sh` file itself; what follows is a brief overview of what are expected to be the most frequently used ones, adapted from the doc in the script itself:

### `create_and_provision_droplet`

Runs steps to:

1. Create a new Droplet;
2. Delay for a number of seconds (defaulting to 30) to allow the action to complete;
3. Provision the newly-created Droplet;
4. Pull our Docker image and start it in a container running on the Droplet; and
5. Reassign an existing Floating IP to the Droplet.

It *does not* rename or re-tag the new Droplet (which doesn't affect its accessibility via the Floating IP). Those tasks are performed by running the `rename_and_retag_droplet` function.

### `remove_droplet`

Accepts a parameter value for the *name* of the Droplet to be removed, defaulting to the name used when creating a new Droplet by default.

Directly uses the official DigitalOcean command-line utility, [`doctl`](https://github.com/digitalocean/doctl), since there is presently no support within Ansible's DigitalOcean modules for searching among existing Droplets.

After determining the relevant Droplet ID, passes that number to the `remove_droplet.yml` Playbook to perform the deletion.

### `rename_and_retag_droplet`

Renames the created (and ordinarily by-then-HTTP-serving) Droplet based on the `final_tag_name` read from the `running_droplet_details` variable file. It then creates a DigitalOcean Droplet tag based on that `final_tag_name` variable (if the tag does not already exist), adds the tag to the current Droplet, and removes the tag added by the `update_floating_ip.yml` Playbook.

## Future Enhancements

### Multiple Docker Containers

Real, production-scale apps often if not usually require orchestration of multiple Docker containers using Composer, Kubernetes, or other such tooling; the Playbooks and shell functions existing here are foreseen as building blocks towards that. More tooling, likely one or more additional layers, would probably be needed.

### Ansible Roles

Migrating several, if not all, of the tasks and variables associated with these Playbooks to Ansible Roles would make their reuse for different applications/versions much easier.

### Error Handling

There is essentially no provision for error detection or handling within the shell functions or the Playbooks they exercise. The initial use case for these anticipates the shell functions being run directly from a Terminal window; that doesn't get us to properly-automated continuous deployment, but it's a start. Error detection/rollback/retry would be much better.

It would also be highly desirable to have a utility to recreate the `docker_app` variable file based on the Docker image and associated Git repository to be hosted, rather than the current practice of manual editing and committal to source control. This is the subject of Issue [#7](https://github.com/jdickey/docker-ansible-test/issues/7).

## Legal

This `README` and the project which it describes are Copyright &copy; 2017 by Jeff Dickey, and made available under the [MIT License](https://opensource.org/licenses/MIT). No claims to copyright or licensing of projects/products deployed using these tools is inherent in your use of these tools, to the degree and with the limited liability specified in the MIT License.

