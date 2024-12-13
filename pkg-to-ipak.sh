#!/bin/bash

POSITIONAL_ARGS=()

cmd=""
dist=""

while [[ $# -gt 0 ]]; do
  case $1 in
	-h | --help)
		echo "Usage: $0 pkgname command output_file"
		echo "-h, --help      show this help text"
		echo "--cmd           commandline to run in the chroot before packaging"
		echo "--dist          distribution to use for the chroot"
		echo "                Run --help-dists for a list of distro/distroless bases"
		shift
		exit 0
		;;
	--help-dists)
		echo "Available distros:"
		echo "    alpine"
		echo "    debian"
		exit 0
		;;
	--cmd)
		cmd="$2"
		shift
		shift
		;;
	--dist)
		dist="$2"
		shift
		shift
		;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [ -z "$1" ]; then
	echo "Usage: $0 pkgname output_file"
	exit 1
fi
if [ -z "$2" ]; then
	echo "Usage: $0 pkgname output_file"
	exit 1
fi
if [ -z "$3" ]; then
	echo "Usage: $0 pkgname output_file"
	exit 1
fi


echo "Please authenticate at the sudo prompt."

if [ -z "$dist" ]; then
	echo "You need to specify a distrobution. using --dist <distro>."
	echo "What? You think we're just going to pick one for you?"
	echo "Think again! Hahaha!"
	echo ";)"
	exit 1
fi

base=""
if [ "$dist" == "debian" ]; then
	# Check if the __ipak_cache__/dbase directory exists
	if [ ! -d "__ipak_cache__/dbase" ]; then
		mkdir -p "__ipak_cache__/dbase"
		sudo debootstrap --variant=minbase stable __ipak_cache__/dbase http://deb.debian.org/debian
	fi
	base="__ipak_cache__/dbase"
elif [ "$dist" == "alpine" ]; then
	# Check if the __ipak_cache__/abase directory exists
	if [ ! -d "__ipak_cache__/abase" ]; then
		$(cd __ipak_cache__/abase && tar xf alpine-minirootfs*.tar.gz ; cd ../..)
	fi
	base="__ipak_cache__/abase"
else
	echo "Unknown distro: $dist"
	exit 1
fi

pkg_out=$(mktemp -d)
mkdir -p "${pkg_out}/rootfs"
sudo cp -r $base/* ${pkg_out}/rootfs/
ls "${pkg_out}/rootfs"


if [ "$dist" == "debian" ]; then
	sudo arch-chroot "${pkg_out}/rootfs" /bin/bash <<EOF

apt update -y
apt install -y $1
$cmd

EOF
elif [ "$dist" == "alpine" ]; then
	sudo arch-chroot "${pkg_out}/rootfs" /bin/sh <<EOF

apk update
apk add $1
$cmd

EOF
fi




cat <<EOF > "$pkg_out/rootfs/AppRun"
#!/bin/bash
$2 \$@
exit \$?
EOF
chmod +x "$pkg_out/rootfs/AppRun"

sudo rm -Rf "$pkg_out/rootfs/dev"
mkdir "$pkg_out/rootfs/dev"

sudo chown -R "$USER":"$USER" "$pkg_out"
./ipak-creater.sh "$pkg_out" "$3"


rm -Rf "$pkg_out"