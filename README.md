# updatemyfarm
Bash script to update multiple Debian/CentOS servers in parallel using SSH and sudo.

## DESCRIPTION
The idea behind this script is to use a management server or workstation to orchestrate the OS update process across all servers in the organization, farm or cluster.
For this purpose, it uses an unprivileged user with the ability to remotely connect to any server using public key authentication over SSH.
This user has the ability to authenticate as root on target servers, but ONLY to update the OS through the package manager. This is accomplished by a restrictive sudo rules set on each host.
When started, the script offers to update each server in the organization with pending updates (as previously defined in a configuration file). And the administrator has the chance to update only selected servers.
One important thing to note is the administrator running this script must know which packages have newer versions. So it's highly recommended to use this script in conjuntion with check_updates.bash (https://github.com/linuxitux/scripts/blob/master/Devuan/check_updates.bash). This is because this script presents no information about package updates on each server. It only tells you which servers have pending updates (and if it's available a Linux kernel update).
This scripts works only on Debian and CentOS based systems (it supports only APT and Yum package managers).
