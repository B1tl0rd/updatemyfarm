# updatemyfarm
Bash script to update multiple Debian/CentOS servers in parallel using SSH and sudo.

## DESCRIPTION
The idea behind this script is to use a management server or workstation to orchestrate the OS update process across all servers in the organization, farm or cluster.

For this purpose, it uses an unprivileged user with the ability to remotely connect to any server using public key authentication over SSH.

This user has the ability to authenticate as root on target servers, but ONLY to update the OS through the package manager. This is accomplished by a restrictive sudo rules set on each host.

When started, the script offers to update each server in the organization with pending updates (as previously defined in a configuration file). And the administrator has the chance to update only selected servers.

One important thing to note is the administrator running this script must know which packages have newer versions. So it's highly recommended to use this script in conjuntion with check_updates.bash (https://github.com/linuxitux/scripts/blob/master/Devuan/check_updates.bash). This is because this script presents no information about package updates on each server. It only tells you which servers have pending updates (and if it's available a Linux kernel update).

This scripts works only on Debian and CentOS based systems (it supports only APT and Yum package managers).

## INSTALLATION
The installation procedure for this script is very easy, but involves a lot of handwork on target servers.

### MANAGEMENT SERVER CONFIGURATION
On the management system (the one where the script will run) you need to create the unprivileged account to remotely connect to the target servers using public key authentication. For example, create the user "updateusr":
```
root@adminsrv:~# useradd -d /home/updateusr -m -s /bin/bash updateusr
root@adminsrv:~# passwd updateusr
```
Remember this password. You'll need it later.
Then, download a copy of the script:
```
root@adminsrv:~# su - updateusr
updateusr@adminsrv:~$ git clone https://github.com/linuxitux/updatemyfarm.git
```
And configure your target servers:
```
updateusr@adminsrv:~$ cd updatemyfarm/
updateusr@adminsrv:~/updatemyfarm$ nano updatemyfarm.conf
```
The syntax has the format ```USER:HOST:PORT:OS```. Comments starting with ```#``` are allowed, but not empty lines. Remember OS can be only ```debian``` or ```centos```.
The final step is to generate a pair of keys for SSH authentication:
```
updateusr@adminsrv:~/updatemyfarm$ cd
updateusr@adminsrv:~$ ssh-keygen -t dsa
```

### CONFIGURATION ON TARGET SERVERS
This section explains the configuration needed for each server inside ```updatemyfarm.conf```.

First, create the unprivileged account "updateusr":
```
root@targetsrv:~# useradd -d /home/updateusr -m -s /bin/bash updateusr
```
#### PUBLIC KEY AUTHENTICATION
Next, setup public key authentication for "updateusr":
```
root@targetsrv:~# su - updateusr
updateusr@targetsrv:~$ mkdir .ssh
updateusr@targetsrv:~$ chmod 700 .ssh/
updateusr@targetsrv:~$ touch .ssh/authorized_keys
updateusr@targetsrv:~$ chmod 644 .ssh/authorized_key
updateusr@targetsrv:~$ exit
```
Verify that public key authentication it's enabled in SSH:
```
root@targetsrv:~# nano /etc/ssh/sshd_config
```
Be sure this lines are present:
```
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```
Then, restart the SSH deamon (```service ssh restart``` on Debian, ```service sshd restart``` on CentOS).

The last step related to SSH and public key aythentication, consists in install the public key of "updateusr@adminsrv" to allow passwordless access to this server as "updateusr@targetsrv".
From each target server, logged as "updateusr", run this command:
```
updateusr@targetsrv:~$ ssh -p 2022 updateusr@adminsrv "cat .ssh/id_dsa.pub" >> .ssh/authorized_keys
```
For this, you need to know updateusr's password on adminsrv (it was set up earlier on management server configuration).
After this steps, "updateusr@adminsrv" will be able to login on any target server as "updateusr" without a password.
#### RESTRICTIVE SUDO FOR UPDATEUSR
TODO

