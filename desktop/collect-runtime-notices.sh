#!/bin/sh
set -eu
# Runs inside the pinned Tebako container, after packaging.
destination=/mnt/output/runtime-notices
mkdir -p "$destination"
cp /usr/local/lib/ruby/gems/3.2.0/gems/tebako-0.15.9/LICENSE.md "$destination/tebako-LICENSE.md"
cp /root/.tebako/deps/src/_ruby_3.4.2/COPYING "$destination/ruby-COPYING"
cp /root/.tebako/deps/src/_ruby_3.4.2/BSDL "$destination/ruby-BSDL"
for source in /root/.tebako/deps/vcpkg_installed/x86_64-linux/share/*/copyright; do
  component=$(basename "$(dirname "$source")")
  cp "$source" "$destination/$component-copyright"
done

chown -R "$BUILD_UID:$BUILD_GID" "$destination"
