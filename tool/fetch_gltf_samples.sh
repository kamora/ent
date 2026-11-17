#!/bin/sh

# Fetches the Khronos glTF sample models of the "real content" milestone (docs/implementation-roadmap.md) at a pinned
# commit into third_party/glTF-Sample-Assets, then copies the variant each scene uses, with the model's license and
# metadata, into fixtures/gltf/khronos/<Name>/. Only those files are checked out (sparse, blobs on demand).
set -eu

commit=8f492390ddc7a2ae221a1369ef560589cf8c70fb
root="$(cd "$(dirname "$0")/.." && pwd)"
dir="$root/third_party/glTF-Sample-Assets"
out="$root/fixtures/gltf/khronos"

# Name and the variant directory used. MetalRoughSpheres is left out: its smallest variant is 11.2 MB. DamagedHelmet
# too: its license includes CC-BY-NC-4.0 (Kai, 2026-11-10).
models='BoxTextured:glTF-Binary
TextureCoordinateTest:glTF-Binary
VertexColorTest:glTF-Binary
AlphaBlendModeTest:glTF-Binary
NormalTangentMirrorTest:glTF-Binary
TextureTransformTest:glTF
ClearCoatTest:glTF-Binary
TransmissionTest:glTF-Binary
AnimatedMorphCube:glTF-Binary
CesiumMan:glTF-Binary'

if [ ! -d "$dir/.git" ]; then
	git clone --depth 1 --filter=blob:none --sparse --no-checkout https://github.com/KhronosGroup/glTF-Sample-Assets "$dir"
fi

if [ "$(git -C "$dir" rev-parse HEAD)" != "$commit" ]; then
	git -C "$dir" fetch --depth 1 --filter=blob:none origin "$commit"
fi

# The license texts the models' metadata.json names.
licenses='CC-BY-4.0.txt CC0-1.0.txt LicenseRef-LegalMark-Cesium.txt'
paths=''

for name in $licenses; do
	paths="$paths /LICENSES/$name"
done

for entry in $models; do
	name="${entry%%:*}"
	paths="$paths /Models/$name/${entry#*:}/ /Models/$name/LICENSE.md /Models/$name/metadata.json /Models/$name/README.md"
done

# Set on every run, so an existing checkout picks up models added here.
# shellcheck disable=SC2086
git -C "$dir" sparse-checkout set --no-cone $paths
git -c advice.detachedHead=false -C "$dir" checkout --detach "$commit"

actual="$(git -C "$dir" rev-parse HEAD)"

if [ "$actual" != "$commit" ]; then
	echo "glTF-Sample-Assets checkout is at $actual, expected $commit" >&2
	exit 1
fi

for entry in $models; do
	name="${entry%%:*}"
	rm -rf "${out:?}/$name"
	mkdir -p "$out/$name"
	cp -R "$dir/Models/$name/${entry#*:}" "$dir/Models/$name/LICENSE.md" "$dir/Models/$name/metadata.json" \
		"$dir/Models/$name/README.md" "$out/$name/"
done

rm -rf "$out/LICENSES"
mkdir -p "$out/LICENSES"

for name in $licenses; do
	cp "$dir/LICENSES/$name" "$out/LICENSES/"
done

echo "glTF-Sample-Assets at $commit"
