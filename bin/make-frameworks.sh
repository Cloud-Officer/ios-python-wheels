#!/usr/bin/env bash
set -e
shopt -s nullglob globstar

parse_command_line()
{
  local append argument default_value help_text line required variable_name
  printf "# default values\n\n"

  while read -r line; do
    IFS=, read -r argument variable_name default_value required append help_text <<<"${line}"

    if [ "${default_value}" != "-1" ]; then
      printf "%s=\"%s\"\n" "${variable_name}" "${default_value}"
    fi
  done < <(awk '/^#\[/,/^#\]/ { print }' <"${0}" | grep -v '\[' | grep -v '\]' | tr -d '#')

  printf "\n# parse command line\n\npositional=()\n\n"
  printf "while [[ \$# -gt 0 ]]; do\n"
  printf "  key=\"\${1}\"\n\n"
  printf "  case \"\${key}\" in\n"
  printf "  --help)\n"
  printf "  echo \"Usage: \${0##*/} options\n"
  printf "\n    options\n"

  while read -r line; do
    IFS=, read -r argument variable_name default_value required append help_text <<<"${line}"
    printf "            %s %s\n" "${argument}" "${help_text}"
  done < <(awk '/^#\[/,/^#\]/ { print }' <"${0}" | grep -v '\[' | grep -v '\]' | tr -d '#')

  printf "\"\n    exit 0\n    ;;\n\n"

  while read -r line; do
    IFS=, read -r argument variable_name default_value required append help_text <<<"${line}"

    if [ "${append}" == "1" ]; then
      printf "  %s)\n    %s=\"\${%s} %s \${2}\"\n    shift\n    shift\n    ;;\n\n" "${argument}" "${variable_name}" "${variable_name}" "${argument}"
    else
      printf "  %s)\n    %s=\"\${2}\"\n    shift\n    shift\n    ;;\n\n" "${argument}" "${variable_name}"
    fi
  done < <(awk '/^#\[/,/^#\]/ { print }' <"${0}" | grep -v '\[' | grep -v '\]' | tr -d '#')

  printf "  *)\n    positional+=(\"\${1}\")\n    shift\n    ;;\n  esac\ndone\n\nset -- \"\${positional[@]}\"\n\n"

  while read -r line; do
    IFS=, read -r argument variable_name default_value required append help_text <<<"${line}"

    if [ "${required}" == "1" ]; then
      printf "if [ -z \"\${%s}\" ]; then\n  echo \"Error: %s required !\"\n  exit 1\nfi\n\n" "${variable_name}" "${argument}"
    fi
  done < <(awk '/^#\[/,/^#\]/ { print }' <"${0}" | grep -v '\[' | grep -v '\]' | tr -d '#')
}

# parse command line

#[ argument,variable_name,default_value,required,append,help_text
# --bundle-identifier,bundle_identifier,,1,0,CFBundleIdentifier
# --bundle-name,bundle_name,,1,0,CFBundleName
# --bundle-version,bundle_version,,1,0,CFBundleVersion
# --input-dir,input_dir,,1,0,input directory
# --minimum-os-version,minimum_os_version,12.0,0,0,MinimumOSVersion
# --output-dir,output_dir,,1,0,output directory
# --sdk-version,sdk_version,17.3,0,0,SDKVersion
#]

# shellcheck source=/dev/null
. <(parse_command_line)

# generate xcframework

# shellcheck disable=SC2154
pushd "${input_dir}" &>/dev/null
bundle_version="${bundle_version/v/}"

for library in ./**/*.so ./**/*.dylib; do
  library_name="$(basename "${library%.cpython*}")"
  directory="$(dirname "${library/.\//}")"

  if [ "${directory}" = "." ]; then
    # shellcheck disable=SC2154
    folder_name="${bundle_name##*.}-${library_name}.framework"
    prefix_package="${bundle_name}"
  else
    # shellcheck disable=SC2154
    folder_name="${bundle_name##*.}-$(echo "${directory}" | tr '/' '-')-${library_name}.framework"
    prefix_package="${bundle_name}.$(echo "${directory}" | tr '/' '.')"
  fi

  if [ "${bundle_name}" == "python" ]; then
    folder_name="${folder_name/python-/}"
  fi

  rm -rf "${output_dir:?}/${folder_name}"
  mkdir "${output_dir}/${folder_name}"
  library_file="${library/darwin/iphoneos}"
  library_file="${library_file/.so/.dylib}"
  echo "Processing ${library_file}..."
  # shellcheck disable=SC2154
  xcrun vtool -arch arm64 -set-build-version 2 "${minimum_os_version}" "${sdk_version}" -replace -output "${library}" "${library}" &>/dev/null

  framework_path="${output_dir}/${folder_name}"
  base_library_name="$(basename "${library_file}")"
  framework_lib_name="${framework_path}/${base_library_name}"
  cp "${library}" "${framework_lib_name}"

  # shellcheck disable=SC2154
  full_bundle_identifer="${bundle_identifier//_/}.${prefix_package//_/}.${library_name//_/.}"
  full_bundle_identifer="${full_bundle_identifer/../.}"

  full_bundle_identifer="${full_bundle_identifer}.${base_library_name}"

  tmp_file_name="${framework_path}/${full_bundle_identifer}"
  mv "${framework_lib_name}" "${tmp_file_name}"
  install_name_tool -id "${full_bundle_identifer}" "${tmp_file_name}" &>/dev/null
  loader_paths=$(otool -L "${tmp_file_name}" | grep -v "${full_bundle_identifer}" | grep -v : | grep -v /usr/ | grep -v /System/ | awk '{print $1}')

  if [ -n "${loader_paths}" ]; then
    for loader_path in ${loader_paths}; do
      echo "Patching ${loader_path}..."

      case "${loader_path}" in
        *openblas*)
          if [ ! -f "${output_dir}/libopenblas64_.0.dylib" ]; then
            echo "Error: libopenblas64_.0.dylib not found!"
            exit 1
          fi

          install_name_tool -change "${loader_path}" "@loader_path/../libopenblas64_.0.dylib"  "${tmp_file_name}" &>/dev/null
          ;;

        *libomp*)
          if [ ! -f "${output_dir}/libomp.dylib" ]; then
            echo "Error: libomp.dylib not found!"
            exit 1
          fi

          install_name_tool -change "${loader_path}" "@loader_path/../libomp.dylib"  "${tmp_file_name}" &>/dev/null
          ;;

        *libgfortran*)
          if [ ! -f "${output_dir}/libgfortran.5.dylib" ]; then
            echo "Error: libgfortran.5.dylib not found!"
            exit 1
          fi

          install_name_tool -change "${loader_path}" "@loader_path/../libgfortran.5.dylib"  "${tmp_file_name}" &>/dev/null
          ;;

        *)
          echo "Error: unable to patch ${loader_path}!"
          exit 1
      esac
    done
  fi

  mv "${tmp_file_name}" "${framework_lib_name}"

  {
    echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    echo "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
    echo "<plist version=\"1.0\">"
    echo "<dict>"
    echo "    <key>CFBundlePackageType</key>"
    echo "    <string>FMWK</string>"
    echo "    <key>CFBundleInfoDictionaryVersion</key>"
    echo "    <string>6.0</string>"
    echo "    <key>CFBundleDevelopmentRegion</key>"
    echo "    <string>en</string>"
    echo "    <key>CFBundleSupportedPlatforms</key>"
    echo "    <array>"
    echo "        <string>iPhoneOS</string>"
    echo "    </array>"
    echo "    <key>MinimumOSVersion</key>"
    echo "    <string>${minimum_os_version}</string>"
    echo "    <key>CFBundleIdentifier</key>"
    echo "    <string>${full_bundle_identifer}</string>"
    echo "    <key>CFBundleName</key>"
    echo "    <string>${full_bundle_identifer}</string>"
    echo "    <key>CFBundleVersion</key>"
    echo "    <string>${bundle_version}</string>"
    echo "    <key>CFBundleShortVersionString</key>"
    echo "    <string>${bundle_version%.*}</string>"
    echo "    <key>CFBundleExecutable</key>"
    echo "    <string>$(basename "${library_file}")</string>"
    echo "</dict>"
    echo "</plist>"
  } >"${output_dir}/${folder_name}/Info.plist"
done

popd &>/dev/null

