# bash-network-scan
Bash script to detect devices in your local network: gets IP address, MAC address and Device name

# usage
./net-scan.sh [-h] [-i n] [-l] [-a] [-m]

where:
- -h	show this help text
- -i	set the IP interface to check (default: 1) - check available IPs list with [-l] option
- -l	list the available IP addresses
- -a	show all network IPs, even if no computer name is found
- -m	show MAC address
