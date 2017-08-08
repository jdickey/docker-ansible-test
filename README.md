<h1>Docker Ansible Test</h1>

<h2>Contents</h2>

- [Introduction and Structure](#introduction-and-structure)
- [What Works So Far](#what-works-so-far)
- [What's Broken](#whats-broken)
- [What's Incomplete](#whats-incomplete)
- [Quirks Mode](#quirks-mode)
- [Useful References](#useful-references)
  * [DigitalOcean tutorials](#digitalocean-tutorials)
  * [Ansible resources](#ansible-resources)
    + [Modules](#modules)
    + [Official Ansible docs and tutorials](#official-ansible-docs-and-tutorials)
    + [Ansible from other sources](#ansible-from-other-sources)

## Introduction and Structure

This is a small exploration, of which the first commit marked what was in reality at least the fourth grab-another-template-and-experiment iteration, of how to use Ansible _from within a Docker container_ to create (and eventually provision and otherwise manage) a DigitalOcean Droplet that itself uses Docker to host an application from an image distinct from the one running Ansible.

This is initially a private repo, at least until I get some workflows fully spun up and working. I've achieved a major milestone tonight, recreating the one from 48 hours prior, where I:

1. have an Ansible Playbook, `playbook.yml`, that first ensures that a `~/.ssh/authorized_keys` file exists *in the Docker image running the Playbook* and then use the [`digital_ocean` Ansible module](http://docs.ansible.com/ansible/latest/digital_ocean_module.html) to create a new Droplet, `droplet_one`. This *should* be idempotent;
2. a bare-bones `inventory` that defines a `localhost` system name purely to satisfy the requirement that the Playbook name a defined system (even if it's going to create a new, entirely different one);
3. an Ansible [Role definition](http://docs.ansible.com/ansible/latest/digital_ocean_module.html), named `common`, that defines several variables used in the Playbook. Since one of these, `do_token`, is a "secret" value for our DigitalOcean API key, the file defining those variables is encrypted using `ansible-vault`, and decrypted on-the-fly with a password read from a `.vault-password` file in the Docker build source directory. That `.vault-password` has been added to `.gitignore` for obvious reasons;
4. Naturally, a `Dockerfile` which, when the image built from it is run, _presently_ does most of the internal setup needed for our Ansible rig and then drops you into a Bash shell. There, one can run the Playbook via Ansible. Once the Playbook(s) are complete and correct, we can adopt at least one of multiple strategies:
	1. By removing the `ENTRYPOINT` line entirely, execution of the container built from it will terminate after the last instruction in the Dockerfile; if that container was run using Docker's `--rm` option, it will remove itself from the container (*not* image) list entirely;
	2. The same Docker image can be built with multiple Ansible Playbooks, to be selected from at `docker run` time;
	3. A variation on the previous option would require that a Docker volume be specified at `docker run` time; the Playbooks, roles, and so on would be read from that.
5. A `.dockerignore` file prevents the `.git` directory/repo from being added to the Dockerfile *even if* copying of files when the image is built is made less selective; and
6. A `.gitignore` file excludes the `.vault-password` file, containing the password for our Ansible secrets, from being added to our Git repo.

## What Works So Far

The Playbook builds a (defective) Droplet according to the (incomplete) instructions specified to the `digital_ocean` Ansible module.

## What's Broken

The Droplet built by the Playbook **does not** have login locked down securely, due to either a profound misunderstanding of or a bug in the `digital_ocean` Ansible module. As things are now, when the Droplet is created, DigitalOcean emails a one-time `root` password to the DO account holder.

## What's Incomplete

The Playbook

1. *creates* a Droplet, but it does not yet provision it and, therefore, doesn't spin up our app's Docker image in a container on the new Droplet;
2. does not yet know anything about Floating IPs;
3. does not yet name a new Droplet correctly, nor rename existing ones;
4. has not been experimentally proven to be idempotent.

## Quirks Mode

The created Droplet apparently far more closely matches one that would be created through the DigitalOcean [Droplet Control Panel](https://cloud.digitalocean.com/droplets) than one created using the [`doclt`](https://github.com/omgimanerd/doclt) or [`doctl`](https://github.com/digitalocean/doctl) command-line tools. This includes an email being sent to the account holder with a one-time `root` password, and the SSH daemon not being hardened. Maybe we should use such tools from Ansible rather than the inbuilt `digital_ocean` Ansible module?

## Useful References

Not likely to be terribly complete, but the ones I left open in browser tabs over the last three days:

### DigitalOcean tutorials

* [*Initial Server Setup with Ubuntu 16.04*](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-16-04);
* [*How To Use the DigitalOcean API v2 with Ansible 2.0 on Ubuntu 16.04*](https://www.digitalocean.com/community/tutorials/how-to-use-the-digitalocean-api-v2-with-ansible-2-0-on-ubuntu-16-04);

### Ansible resources

#### Modules

* An Ansible module to ["Create/delete a droplet/SSH_key in DigitalOcean"](http://docs.ansible.com/ansible/latest/digital_ocean_module.html);
* An Ansible module that ["Adds or removes an SSH authorized key"](http://docs.ansible.com/ansible/latest/authorized_key_module.html);

#### Official Ansible docs and tutorials

* [Ansible doc on Roles](http://docs.ansible.com/ansible/latest/playbooks_reuse_roles.html);
* An [Ansible tutorial](https://www.codereviewvideos.com/course/ansible-tutorial) on codereviewvideos.com that had some useful information, yet also led me down paths which I followed imperfectly;

#### Ansible from other sources

* The [SO answer](https://stackoverflow.com/a/29399036/1372767) that first twigged me to practical use of `ansible-vault` (Thanks, [Ben Whaley](https://stackoverflow.com/users/2430241/ben-whaley)!);
