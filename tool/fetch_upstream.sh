#!/bin/sh
# Fetches the pinned three.js release as a read-only reference into third_party/three.js.
set -eu

tag=r187
commit=7e89746a687bb88271253698fa108b1dd59825d0
dir="$(cd "$(dirname "$0")/.." && pwd)/third_party/three.js"

if [ ! -d "$dir/.git" ]; then
	git -c advice.detachedHead=false clone --depth 1 --branch "$tag" --filter=blob:none --sparse \
		https://github.com/mrdoob/three.js "$dir"
fi

# Set on every run, so an existing checkout picks up paths added here (fetching their blobs at the pinned commit).
git -C "$dir" sparse-checkout set --no-cone '/src/' '/test/unit/' '/examples/jsm/lights/' '/examples/jsm/controls/' '/examples/jsm/postprocessing/' '/examples/jsm/shaders/' '/examples/jsm/loaders/GLTFLoader.js' '/examples/jsm/loaders/HDRLoader.js' '/examples/jsm/loaders/RGBELoader.js' '/examples/jsm/loaders/VOXLoader.js' '/examples/jsm/utils/BufferGeometryUtils.js' '/examples/jsm/utils/SkeletonUtils.js' '/LICENSE' '/package.json'

actual="$(git -C "$dir" rev-parse HEAD)"

if [ "$actual" != "$commit" ]; then
	echo "three.js checkout is at $actual, expected $tag ($commit)" >&2
	exit 1
fi

echo "three.js $tag at $commit"
