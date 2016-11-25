usage="$(basename "$0") [OPTIONS] -- program to retrieve network devices and show IP address paired with the device name

where:
	-h	show this help text
	-i	set the IP interface to check (default: 1) - check available IPs list with [-l] option
	-l	list the available IP addresses
	-a	show all network IPs, even if no computer name is found
	-m	show MAC address
	-b	show devices brand when no other information is available (if nmap installed and if can be found)"

myip=1
shownoname=false
showmac=false
showbrand=false
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m'

while getopts ':halmbi:' option; do
	case "$option" in
		h) echo "$usage"
			exit 0
	   		;;
		a) shownoname=true
			;;
		l) sudo nm-tool | grep -i 'address' | grep -Po '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | nl -n 'ln'
		   	exit 0
		   	;;
		m) showmac=true
			;;
		b) showbrand=true
			;;
   		i) myip=$OPTARG
			if [ -z $(sudo nm-tool | grep -i 'address' | grep -Po '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sed -n "$myip"p) ]; then
				echo "there is no such interface, try the [-l] option"
				exit 1
			fi
	   		;;
	   	:) printf "missing argument for -%s\n" "$OPTARG" >&2
	   		exit 1
		   	;;
		\?) printf "illegal option: -%s\n" "$OPTARG" >&2
		   	exit 1
		   	;;
	esac
done
shift $((OPTIND - 1))

# get if nmap is installed
nmapInstalled=$(whereis nmap)
if [ -z "$nmapInstalled" ]; then
	showbrand=false
fi

maxwait=0.1;
# get starter IP address
IFS=. read -r i1 i2 i3 i4 <<< $(sudo nm-tool | grep -i 'address' | grep -Po '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sed -n "$myip"p)
IFS=. read -r m1 m2 m3 m4 <<< $(sudo nm-tool | grep -i 'prefix' | grep -Po '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sed -n "$myip"p)
si1=$(($i1 & $m1))
si2=$(($i2 & $m2))
si3=$(($i3 & $m3))
si4=$(($i4 & $m4))
# get my HW address
myhwaddr=$(ifconfig | grep -B 1 "$i1.$i2.$i3.$i4" | grep -oP '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})' | sed -n "$myip"p)
# get number of IPs in network
iprange=$(sudo nm-tool | grep -i 'prefix' | grep -Po '\s[0-9]+' | grep -Po '[0-9]+' | sed -n "$myip"p)
iprange=$(( 2**(32-$iprange) -1 ))
#  cycle through IPs
for((i=1;i<$iprange;i++)); do
	# calulate IP
	ci4=$(($si4 + $i))
	ci3=$(($si3 + ($ci4 / 256) )); ci4=$(($ci4 % 256))
	ci2=$(($si2 + ($ci3 / 256) )); ci3=$(($ci3 % 256))
	ci1=$(($si1 + ($ci2 / 256) )); ci2=$(($ci2 % 256))
	# get computer name
	result=$(timeout $maxwait nmblookup -A "$ci1.$ci2.$ci3.$ci4" | sed -n 2p | grep -Po '\t.+?\s' | xargs)
	hwaddress=$(arp "$ci1.$ci2.$ci3.$ci4" | grep -Po '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})')
	if [ -z "$result" ] && [ ! -z "$hwaddress" ] && [ $shownoname == true ]; then
		result="???"
	fi
	# print if response given
	if [ ! -z "$result" ]; then
		toprint="$ci1.$ci2.$ci3.$ci4"
		if [ $showmac == true ]; then
			if [ -z "$hwaddress" ]; then
				hwaddress=$myhwaddr
			fi
			toprint="$toprint ( $hwaddress )"
		fi
		myhost=$(grep "$ci1.$ci2.$ci3.$ci4" /etc/hosts | grep -oP '\s.+' | xargs)
		if [ ! -z "$myhost" ]; then
			result="$result ( ${GREEN}$myhost${NC} )"
		fi
		if [ "$ci1.$ci2.$ci3.$ci4" == "$i1.$i2.$i3.$i4" ]; then
			result="$result ( ${RED}THIS DEVICE${NC} )"
		fi
		# if nothing found and nmap installed get device brand
		if [ "$result" == "???" ] && [ $showbrand == true ]; then
			result=$(sudo nmap -sP "$ci1.$ci2.$ci3.$ci4" | grep 'MAC Address' | grep -Po '\(.+?\)')
			if [ "$result" == "(Unknown)" ]; then
				result="???"
			else
				result="??? ${ORANGE}$result${NC}"
			fi
		fi
		echo -e "$toprint\t=>\t$result"
	fi
done
