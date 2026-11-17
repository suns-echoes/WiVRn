#!/bin/sh
# Install and remove this fork's WiVRn server (on this PC) and client (on the headset).
#
#   utils/wivrn-fixes.sh install-server [BUILD_DIR] [PREFIX]
#   utils/wivrn-fixes.sh remove-server  [PREFIX]
#   utils/wivrn-fixes.sh install-client APK
#   utils/wivrn-fixes.sh remove-client  [PACKAGE]
#
# Server: `cmake --install` of a finished build (default BUILD_DIR: build-server) into PREFIX
#   (default: ~/.local/opt/wivrn-fixes), so it never mixes with a system or flatpak WiVRn.
#   The list of installed files is kept in PREFIX/install_manifest.txt; remove-server deletes
#   exactly those files (only ones inside PREFIX), then the directories left empty.
#   Run it as PREFIX/bin/wivrn-server (or PREFIX/bin/wivrn-dashboard if built).
# Client: `adb install -r` / `adb uninstall` on the connected headset (developer mode, USB).
#   A local or debug build is "WiVRn Local" = org.meumeu.wivrn.local (the default PACKAGE);
#   the store app is org.meumeu.wivrn. Android refuses an unsigned APK (CI's
#   "apk-Release-unsigned" must be signed first, e.g. with apksigner).

set -eu

DEFAULT_PREFIX="$HOME/.local/opt/wivrn-fixes"
DEFAULT_PACKAGE="org.meumeu.wivrn.local"

die() { echo "wivrn-fixes: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "'$1' not found"; }

usage() {
	sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
}

install_server() {
	build="${1:-build-server}"
	prefix="${2:-$DEFAULT_PREFIX}"
	need cmake
	[ -f "$build/CMakeCache.txt" ] || die "$build is not a CMake build directory"
	[ -x "$build/server/wivrn-server" ] || die "$build/server/wivrn-server not built yet"
	cmake --install "$build" --prefix "$prefix"
	cp "$build/install_manifest.txt" "$prefix/install_manifest.txt"
	echo "Installed in $prefix; start it with: $prefix/bin/wivrn-server"
}

remove_server() {
	prefix="${1:-$DEFAULT_PREFIX}"
	manifest="$prefix/install_manifest.txt"
	[ -f "$manifest" ] || die "no $manifest: nothing installed there by this script"
	# Delete only the listed files, and only those inside the prefix.
	while IFS= read -r f; do
		case "$f" in
			"$prefix"/*) [ -e "$f" ] || [ -L "$f" ] && rm -f -- "$f" ;;
			*) echo "skipped (outside $prefix): $f" >&2 ;;
		esac
	done < "$manifest"
	rm -f -- "$manifest"
	# Links made at install time but not in the manifest, now pointing nowhere.
	find "$prefix" -xtype l -delete 2>/dev/null || true
	find "$prefix" -depth -type d -empty -delete 2>/dev/null || true
	echo "Removed the server from $prefix"
}

install_client() {
	[ $# -ge 1 ] || die "install-client needs the APK file"
	[ -f "$1" ] || die "no such file: $1"
	need adb
	adb install -r "$1"
}

remove_client() {
	need adb
	adb uninstall "${1:-$DEFAULT_PACKAGE}"
}

[ $# -ge 1 ] || usage
cmd="$1"; shift
case "$cmd" in
	install-server) install_server "$@" ;;
	remove-server)  remove_server "$@" ;;
	install-client) install_client "$@" ;;
	remove-client)  remove_client "$@" ;;
	*) usage ;;
esac
