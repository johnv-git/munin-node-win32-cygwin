# munin-node-win32-cygwin

## Security Considerations

### Network Security

`munin-node-win32-cygwin` is easiest run via a password-less ssh session, secured by RSA key.
However, adding an sshd service to a client machine opens the possibility of attack.

If `PasswordAuthentication` is enabled, brute force attacks against the client are possible.
Running on a port other than `22` may reduce this somewhat.  In general, having an sshd port
open to the internet means you will be attacked rather quickly.  Port scanners are constantly 
looking for targets.

When using an RSA key, the client is still at risk from a compromised account on the munin server.
This can be mitigated by specifying a command in the `authorized_keys` file, rather than permitting
shell access.

### Operational Security

`munin-node-win32-cygwin` uses a set of executable programs (plugins) to produce out.  If the
`plugins` directory is writable, an attacker could add plugins that will be executed.

To minimize risks, the owning account should be used for munin and nothing else.

## Installation

`munin-node-win32-cygwin` requires Cygwin, Perl, and the `Win32::OLE` perl module.
Because the `Win32:OLE` module is not available pre-compiled, you will also need
`gcc-core`, `g++`, and the `libcrypt-devel` library.

### Install Cygwin x86_64

* Download Cygwin setup-x86_64.exe
  * http://cygwin.org/setup-x86_64.exe
* Run and install to c:\cygwin64

### Install Cygwin packages

* install Perl perl
* install Net openssh
* install Devel make
* install Devel gcc-core
* install Devel g++
* install libs libcrypt-devel
* install System procps (uptime plugin)
* install Utils smartmontools (smartmon plugin)

### Build the Win32::OLE Perl Module

* $ cpan
* cpan> install Win32::OLE
  * will die with an error
* cpan> look Win32::OLE
* $ vi OLE.xs
  * On line 483 change stricmp to strcasecmp
  * Save changes
* $ make
* $ make install
* $ exit shell
* cpan> exit cpan

### Install Cygwin sshd as a service

* See Security concerns above.
* [open terminal as admin]
* # ssh-host-config -y
* # cygrunsrv -S sshd

### Configure ssh on your client

In order to connect to and run the node client, the 

* On the client in `~user/.ssh/authorized_keys`
```
ssh-rsa AAAAB2AC1...(RSA KEY)... root@server.domain.com
```

* Optionally the client can provide the command in `authorized_keys`.  This is more secure.
```
command="cd ./munin-node; /usr/bin/perl -T ./munin-node.pl",no-agent-forwarding,no-portforwarding,no-X11-forwarding,no-user-rc,no-pty ssh-rsa AAAAB2AC1...(RSA KEY)... root@server.domain.com
```

### Configure munin-master on your server

* On the server in `/usr/local/etc/munin/munin.conf`
```
[hostname]
    address ssh://user@hostname -t -t -t "cd ./munin-node; ./munin-node.pl"
```
