# Hostname

Starting with iOS 17 Apple no longer offers the iOS hostname to apps, instead
just reporting "localhost"

Since it used to be provided via iOS, nobody has implemented any functinolly
to change hostname within iSH. Hopefully that gets fixed at some point.

Here are some workarounds to handle this. It can't solve all instances of
`localhost` showing up, but it can make it much better.

Before starting to take action I would suggest to first browse through this
document so that you have realistic expectations about if this will be worthwhile.

## Set hostname

Uppercase and dashes work, spaces can't be used. This has always worked,
such as you can change this file. Up to this point iSH itself does not use it.
So it has historically been a waste of time to bother to change this file.

```shell
echo MyOwnIsh > /etc/hostname
```

## Alternate hostname cmd

```shell
# Create alternate hostname command, and make it runable
echo "#!/bin/sh" >/usr/local/bin/hostname
echo "cat /etc/hostname" >/usr/local/bin/hostname
chmod 755 /usr/local/bin/hostname
```

At this point, if you type hostname at the prompt you should get the expected result.

## System tools

Most system tools get the hostname from the kernel, especially if they are compiled
binaries. Currently, there is no way to change the kernel from reporting localhost.
In such cases, you can sometimes override the default behaviour if a specific tool
allows for configuration of hostname, either in a config file, or by using command
line parameters.

## Shell Prompts

By default, all the shells I am aware of use the kernel to get the hostname,
so the built-in shortcuts to display the hostname can't be used.

The only way to get shell prompts to display the intended hostname is to replace
the shell-specific shortcut for the hostname either with a fixed string or by
running your alternate hostname cmd.

| shell | hostname shortcut to replacce |
| ----- | ----------------------------- |
| ash   | `\h`                          |
| bash  | `\h`                          |
| zsh   | `%m`                          |

## Other general tools

### POSIX & Bash

Most general scripts use /bin/hostname, so they would typically show your intended
hostname.

### Python

Python has built in support for reading the hostname from the kernel, so in most
cases Python code would display localhost, but with Python you normally have
source-code, so you could change places that really bother you to either display
a static name, or displaying the output of /bin/hostname
