#!/usr/bin/env bash
set -e

# settings

python_version="3.11"
minimum_os_version="12.0"
sdk_version="17.0"

# Python package name, package version tag, package name alias

# shellcheck disable=SC2034
numpy=("numpy" "latest" "numpy")
# shellcheck disable=SC2034
scikit_learn=("scikit-learn" "latest" "sklearn")
# shellcheck disable=SC2034
scipy=("scipy" "latest" "scipy")

packages=(
  numpy[@]
  scikit_learn[@]
  scipy[@]
)

base_dir="$(pwd)"
export base_dir
export frameworks_dir="${base_dir}/frameworks"
export python_dir="${base_dir}/python${python_version}"
export site_packages_dir="${python_dir}/site-packages"
export sources_dir="${base_dir}/sources"
export version_file="${base_dir}/versions.txt"
PATH="${base_dir}/bin:${PATH}"

# python apple support

echo "Building Python ${python_version} for iOS..."
rm -rf "${frameworks_dir}" "${python_dir}" "${version_file}" Python-*.zip
mkdir "${frameworks_dir}"
#python_url=$(curl --silent --location https://api.github.com/repos/beeware/Python-Apple-support/releases | jq --raw-output --arg python_version "${python_version}" '.[] | select(.name | contains($python_version)) | .assets[].browser_download_url' | head -n 1)
#python_file=$(echo "${python_url}" | awk -F/ '{print $NF}')
#curl --silent --location "${python_url}" --output "${python_file}"
#tar xfz "${python_file}"
pushd "${sources_dir}/python-apple-support" &>/dev/null
sed -i '' "s/ -bundle/ -shared/g" patch/Python/Python.patch
make iOS
tar -xzf dist/Python-3.11-iOS-support.custom.tar.gz --directory "${base_dir}"
popd &>/dev/null
mv python-stdlib "${python_dir}"
mv Python.xcframework "${frameworks_dir}"
cp module.modulemap "${frameworks_dir}/Python.xcframework/ios-arm64/Headers"
mv VERSIONS "${version_file}"
echo "---------------------" >> "${version_file}"
rm -rf "${python_file}" platform-site "${python_dir}/lib-dynload"/*-iphonesimulator.dylib "${frameworks_dir}/Python.xcframework/ios-arm64_x86_64-simulator"
make-frameworks.sh --bundle-identifier "org" --bundle-name "python" --bundle-version "${python_version}" --input-dir "${python_dir}/lib-dynload" --minimum-os-version "${minimum_os_version}" --sdk_version "${sdk_version}" --output-dir "${frameworks_dir}"
rm -rf "${python_dir}/lib-dynload"

# pip packages

echo "Installing pip packages..."
mkdir -p "${python_dir}/site-packages"
pushd "${base_dir}/site-packages" &>/dev/null
pip-compile  --resolver=backtracking
sed -i '' "s/^# pip/pip/g" requirements.txt
sed -i '' "s/^# setuptools/setuptools/g" requirements.txt
popd &>/dev/null

pushd "${site_packages_dir}" &>/dev/null
python3 -m pip install --no-deps -r "${base_dir}/site-packages/requirements.txt" -t .
rm pip/__init__.py setuptools/_distutils/command/build_ext.py
cp "${base_dir}/site-packages/__init__.py" pip/__init__.py
cp "${base_dir}/site-packages/build_ext.py" setuptools/_distutils/command/build_ext.py
find . -type d -name "__pycache__" -prune -exec rm -rf {} \;
popd &>/dev/null

# dependencies

dependencies=(
   "gcc"
   "libomp"
   "openblas"
   "xxhash"
)

echo "Installing dependencies..."

for dependency in "${dependencies[@]}"; do
  if ! brew list "${dependency}" &>/dev/null; then
    brew install "${dependency}"
  fi
done

# cp "$(brew --prefix openblas)"/lib/*.dylib "${frameworks_dir}"
# cp "$(brew --prefix libomp)"/lib/*.dylib "${frameworks_dir}"
# cp "$(brew --prefix gcc)"/lib/gcc/current/libgfortran*.dylib "${frameworks_dir}"
# cp "$(brew --prefix gcc)"/lib/gcc/current/libgomp*.dylib "${frameworks_dir}"
# cp "$(brew --prefix gcc)"/lib/gcc/current/libquadmath*.dylib "${frameworks_dir}"
# cp "$(brew --prefix gcc)"/lib/gcc/current/libgcc_s*.dylib "${frameworks_dir}"
#
# for library in "${frameworks_dir}"/*.dylib; do
#   xcrun vtool -arch arm64 -set-build-version 2 "${minimum_os_version}" "${sdk_version}" -replace -output "${library}" "${library}" &>/dev/null
#   loader_paths=$(otool -L "${library}" | grep -v : | grep -v /usr/ | grep -v /System/ | awk '{ print $1 }')
#
#   if [ -n "${loader_paths}" ]; then
#     for loader_path in ${loader_paths}; do
#       echo "Patching loader path ${loader_path}..."
#       install_name_tool -change "${loader_path}" "@loader_path/$(basename ${loader_path})" "${library}" &>/dev/null
#     done
#   fi
# done

# openblas

# lapack_version="1.4"
#
# curl --silent --location "https://github.com/ColdGrub1384/lapack-ios/releases/download/v${lapack_version}/lapack-ios.zip" --output lapack-ios.zip
# unzip -q lapack-ios.zip
# mv lapack-ios/openblas.framework "${frameworks_dir}"
# mv lapack-ios/lapack.framework "${frameworks_dir}/scipy-deps.framework"
# mv lapack-ios/ios_flang_runtime.framework "${frameworks_dir}"
# cp "${frameworks_dir}/openblas.framework/openblas" "${frameworks_dir}/libopenblas.dylib"
# cp "${frameworks_dir}/ios_flang_runtime.framework/ios_flang_runtime" "${frameworks_dir}/libgfortran.dylib"
# rm -rf __MACOSX lapack-ios lapack-ios.zip

# package wheels

echo "Installing package wheels..."
count=${#packages[@]}

for ((i = 0; i < count; i++)); do
  package_name="${!packages[i]:0:1}"
  package_version="${!packages[i]:1:1}"
  package_bundle="${!packages[i]:2:1}"

  if [ "$package_version" == "latest" ]; then
    package_version=$(curl --silent --location "https://pypi.org/pypi/${package_name}/json" | jq -r '.info.version')
  fi

  echo "Processing package '${package_name}' with version '${package_version}' and Python ${python_version}..."
  echo "${package_name}: ${package_version/v/}" >> "${version_file}"
  wheel_url=$(curl --silent --location "https://pypi.org/pypi/${package_name}/json" | jq --raw-output --arg version "${package_version}" --arg py_version "${python_version//.}" '.releases[$version][] | select(.filename | test("-cp" + $py_version + "-cp" + $py_version + "-macosx_[0-9]+_[0-9]+_arm64.whl$")) | .url' | head -n 1) || true
  echo "Downloading wheel from ${wheel_url}..."

  if [ -z "${wheel_url}" ]; then
      echo "No matching wheel found for package '${package_name}' with version '${package_version}' and Python ${python_version} on macOS arm64!"
      curl --silent --location "https://pypi.org/pypi/${package_name}/json" | jq --raw-output --arg py_version "${python_version//.}" '.releases | to_entries[] | .value[] | select(.filename | contains("macosx")) | select(.filename | contains("arm64")) | select(.filename | contains($py_version)) | .filename'
      exit 1
  fi

  temp_dir=$(mktemp -d)
  curl --silent --location "${wheel_url}" --output "${temp_dir}/$(basename "${wheel_url}")"
  wheel_file=$(echo "${wheel_url}" | awk -F/ '{print $NF}')
  pushd "${temp_dir}" &>/dev/null
  unzip -q "${wheel_file}"
  rm -f "${wheel_file}"

  if [ -d "${package_bundle}/.dylibs" ]; then
    cp -f "${package_bundle}/.dylibs"/*.dylib "${frameworks_dir}"
  fi

  # shellcheck disable=SC2010
  make-frameworks.sh --bundle-identifier "org" --bundle-name "${package_bundle}" --bundle-version "${package_version}" --input-dir "${temp_dir}/$(ls | grep -v dist-info)" --minimum-os-version "${minimum_os_version}" --sdk_version "${sdk_version}" --output-dir "${frameworks_dir}"
  mv ./* "${site_packages_dir}"
  popd &>/dev/null
  rm -rf "${temp_dir}"

  if ! [ -f "tests/test_${package_name}.py" ]; then
      echo "No tests found for package '${package_name}'!"
      exit 1
  fi
done

for library in "${frameworks_dir}"/*.dylib; do
  xcrun vtool -arch arm64 -set-build-version 2 "${minimum_os_version}" "${sdk_version}" -replace -output "${library}" "${library}" &>/dev/null
  loader_paths=$(otool -L "${library}" | grep -v : | grep -v /usr/ | grep -v /System/ | awk '{ print $1 }')

  if [ -n "${loader_paths}" ]; then
    for loader_path in ${loader_paths}; do
      echo "Patching loader path ${loader_path}..."
      install_name_tool -change "${loader_path}" "@loader_path/$(basename ${loader_path})" "${library}" &>/dev/null
    done
  fi
done

find "${SOURCES_DIR}" -name '*.egg-info' -exec cp -rf {} "${site_packages_dir}" \; &>/dev/null || true
find "${site_packages_dir}" -name '*.a' -delete &>/dev/null || true
find "${site_packages_dir}" -name '*.dylib' -delete &>/dev/null || true
find "${site_packages_dir}" -name '*.so' -delete &>/dev/null || true
find "${site_packages_dir}" -name '*.md' -delete &>/dev/null || true

# compress output

echo "Compressing output..."
zip --quiet --recurse-paths "Python-$(grep Python versions.txt | awk -F':' '{ print $2 }' | sed 's/ //g')-iOS-Libraries-$(xxhsum versions.txt | awk '{ print $1 }').zip" license versions.txt frameworks "python${python_version}"

echo "${0##*/} completed successfully."
