# sudo

## Source Install/uninstall
- Source install of sudo
    - emerge --sync
- install
    - emerge app-admin/sudo
- uninstall
    - emerge --unmerge app-admin/sudo
- Clean Up Dependencies (Optional)
    - emerge --depclean
- Update Configuration Files (Optional) pick one:
    - etc-update
    - dispatch-conf


## Installs to

- /usr/sbin/sudo

```
-rwsr-xr-x 1 root root 272K Apr  8 16:50 /usr/bin/sudo
```

Remember s bit!

## dir listing

```bash
-rw-r--r--  1 root  root  4.3K Aug 25 06:45 sudo.conf
-r--r-----  1 root  root  4.2K Aug 25 06:45 sudoers
-r--r-----  1 root  root  4.2K Aug 25 06:45 sudoers.dist
-rw-r--r--  1 root  root  9.6K Aug 25 06:45 sudo_logsrvd.conf
```
