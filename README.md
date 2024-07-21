# AOK-Filesystems-Tools

The aim of this is to create a consistent iSH environment that provides
a mostly normal Linux experience, minus the obvious lack of a GUI.
Initially focused on the iSH-AOK fork, but this also works fine on the
mainline iSH, with the exception that Debian/Devuan can't be used, and
features not supported by the regular iSH shell, such as displaying battery
charge won't be available.

You can choose between the distributions Alpine or Debian. For shells it
comes with a basic setup for Bash, Zsh and Ash, using a common init file
shared between the different shells, for settings not bound to a specific
shell, such as PATH aliases and so on.

Both Alpine and Debian offer a fairly similar user experience. More or less
the same apps are installed, and they offer the same custom tools. Alpine
uses fewer resources, so things will be a bit "faster," but in the iSH
universe, speed is a relative concept.

## What works?

I havent fiddled with the Devuan build for almot two years, so is highly unlikely to do something meaningfull at this point in time. Same with `./build_fs -s` (select), also something I havent used for ages, so higly unlikely to be working. At some point I should do a cleanup and fix what doesnt work

## Disclaimer

I typically work on this on a workstation and test it on multiple devices
to ensure it functions as intended in various scenarios. I don't use branches
extensively to isolate experimental changes. If you want to try it out, I
recommend starting with the latest release. These releases are thoroughly
tested and should always be stable. While the main branch usually works fine,
there are no guarantees.

## Installation

### Getting the Repository

For general usage, it is recommended to use the latest release, as mentioned
in the Disclaimer. Once you have downloaded it, follow these steps (please note
that release numbers change over time):

```sh
unzip AOK-Filesystem-Tools-0.9.2.zip
sudo rm -rf /opt/AOK  # Remove the previous instance if present
sudo mv AOK-Filesystem-Tools-0.9.2 /opt/AOK
```

To try out the latest changes:

```sh
git clone https://github.com/jaclu/AOK-Filesystem-Tools.git
sudo rm -rf /opt/AOK  # Remove the previous instance if present
sudo mv AOK-Filesystem-Tools /opt/AOK
```

Please ensure that this is located in /opt/AOK, as various parts of the tool
rely on its known location.

## Compatability

You can build the file system on any platform, but for chrooting, so that you
can pre-build, and/or run the dest env on the build platform, you need to
build on iSH or Linux (x86).

## Available Distros

### Alpine File System

Fully usable. The release can be selected in AOK_VARS

### Debian File System

Fully usable. Be aware that this is Debian 10, since that was the last
version of Debian for 32-bit environs. Deb 10 has been end of lifed, so
will no longer receive updates, but you are unlikely to run any public
services on iSH, so for experimenting with a local Debian, it should be fine.

#### Performance issues running Debian

Any time you add/delete a package containing man pages it will cause a
man-db trigger to reindex all man pages. On a normal system, this is
so close to instantaneous that it is a non-issue. However, when running
Debian on iSH this reindexing takes a long time...

For this reason, by default the iSH-AOK Debian base images does not
include the man tools.
Since it is normally expected to be present on a Debian, if you wan't
to enable man you can achieve this by adding the following to your config

```sh
DEB_PKGS="man-db"
```

This will install the man system in the new File Systems you create.

If you can use prebuild when you generate your FS, DEB_PKGS will be processed
on the build host, completing the task in seconds, instead of minutes on
the destination platform.

In an already deployed Debian 10, instead do:

```sh
apt install man-db
```

If the delays of the man-db trigger becomes an issue, just disable man by doing

```sh
apt remove man-db
```

### Devuan File System

DNS resolving doesn't work, so while you can use Devuan, it's not very
useful beyond testing at the moment. You can use `/etc/hosts`, to add
hosts, and the hostnames needed for apt handling are included, but this
is a limited solution to the DNS issue.

## Build Process

For instructions on how to build an AOK File System, run:

```sh
./build_fs -h
```

### Choosing Distro When You First Boot the File System

To create a File system allowing you to choose between Alpine, Debian,
or Devuan when iSH first boots it up use:

```sh
build_fs -s
```

This is the recommended build method if you don't need to pre-build.
The initial tarball will be around 8MB, and assuming the target device is
reasonably modern, the setup should not take too long.

## Configuration

Settings are in `AOK_VARS`. You can override these with local settings in
`.AOK_VARS`, which will be ignored by Git.

The simplest way to start using this override file is to copy `AOK_VARS`
into `.AOK_VARS` and then edit `.AOK_VARS` to match your needs.

## Running Chrooted

The default command when running `do_chroot.sh` is to examine /etc/password
on the dest_fs and select the shell used by root.

When testing setups in a chroot environment, some extra steps might be
needed to complete the deployment. Any remaining deploy steps are copied
to /etc/profile, since in virtually all cases, it is run during startup.

If you start with a shell not running /etc/profile, the deployment will
not progress. If that happens, it is not much of an issue.

Either run it manually inside the chrooted env:

```bash
/etc/profile
```

Or exit the chroot and run

```bash
./tools/do_chroot.sh /etc/profile
```

### License

[MIT](LICENSE)
