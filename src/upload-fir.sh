#!/usr/bin/env bash

set -e

if [ -z "$(readlink $0)" ]
then
  dir=$(dirname $0)
else
  dir=$(dirname $0)/$(dirname $(readlink $0))
fi
libs=$dir/libs

fir_host=http://api.fir.im/apps
api_token=$(node $libs/get-config.js fir.fir_api_token)

android=$(node $libs/get-config.js android#1 "$@")
ios=$(node $libs/get-config.js ios#1 "$@")

if [ $android -eq 0 ]
then
  echo -e "\n\033[33m[fir.im] Android is skipped.\033[0m\n"
  sleep 1
else
  sh $libs/build-android.sh

  android_app=$(ls -l ./android/app/build/outputs/apk/release/*.apk | tail -n 1 | awk '{print $NF}')
  apk_info=$(node $libs/apk-info.js $android_app)
  eval "$apk_info"
fi

if [ $ios -eq 0 ]
then
  echo -e "\n\033[33m[fir.im] Ios is skipped.\033[0m\n"
  sleep 1
else
  ios_export_plist=$(bash $libs/ipa-export-plist.sh fir.ios_export_plist)
  ios_export_method_line=$(($(cat "$ios_export_plist" | grep  -n  ">method<" | cut -d: -f1) + 1))
  ios_export_method=$(sed -n "${ios_export_method_line}p" "$ios_export_plist" | cut -d'>' -f2 | cut -d'<' -f1)
  ios_app_save_dir=./ios/build/rn-upload-app-temp

  sh $libs/archive.sh
  sh $libs/export-ipa.sh $ios_export_plist $ios_app_save_dir

  ios_app=$(ls $ios_app_save_dir/*.ipa)
  ipa_info=$(node $libs/ipa-info.js $ios_app)
  eval "$ipa_info"
  # ios_name=
  # ios_icon=
  # ios_bundle=
  # ios_code=
  # ios_version=
fi

# Android
[ \( $android -ne 0 \) -a \( -z "$android_app" \) ] && echo -e "\033[31m[fir.im] Android file is missing.\033[0m"

if [ \( $android -ne 0 \) -a \( -n "$android_app" \) ]
then
  echo -e "\033[32m[fir.im] Getting android token...\033[0m"
  token_result=$(
    curl \
      --silent \
      --request "POST" \
      --header "Content-Type: application/json" \
      --data "{\"type\":\"android\", \"bundle_id\":\"$android_bundle\", \"api_token\":\"$api_token\"}" \
      ${fir_host}
  )
  token_log=$(node $libs/validate-fir-token.js "$token_result")
  eval "$token_log"
  # short_url=
  # binary_key=
  # binary_token=
  # binary_upload_url=
  # icon_key=
  # icon_token=
  # icon_upload_url=

  if [ -n "$android_icon" ]
  then
    echo -e "\033[32m[fir.im] Uploading android icon...\033[0m"
    result=$(
      curl \
        --silent \
        --form "file=@$android_icon" \
        --form "key=$icon_key" \
        --form "token=$icon_token" \
        ${icon_upload_url}
    )
    rm -f $android_icon
  fi

  echo -e "\033[32m[fir.im] Uploading android app...\033[0m"
  result=$(
    curl \
      --form "file=@$android_app" \
      --form "key=$binary_key" \
      --form "token=$binary_token" \
      --form "x:name=$android_name" \
      --form "x:version=$android_version" \
      --form "x:build=$android_code" \
      --form "x:changelog=$(node $libs/get-config.js log# "$@")" \
      ${binary_upload_url}
  )
  node $libs/validate-fir.js "$result"
  echo -e "\n[fir.im] Install app by open link: \033[32mhttps://fir.im/$short_url\033[0m\n"
fi

# Ios
[ \( $ios -ne 0 \) -a \( -z "$ios_app" \) ] && echo -e "\033[31m[fir.im] Ios file is missing.\033[0m"

if [ \( $ios -ne 0 \) -a \( -n "$ios_app" \) ]
then
  echo -e "\033[32m[fir.im] Getting ios token...\033[0m"
  token_result=$(
    curl \
      --silent \
      --request "POST" \
      --header "Content-Type: application/json" \
      --data "{\"type\":\"ios\", \"bundle_id\":\"$ios_bundle\", \"api_token\":\"$api_token\"}" \
      ${fir_host}
  )
  token_log=$(node $libs/validate-fir-token.js "$token_result")
  eval "$token_log"
  # short_url=
  # binary_key=
  # binary_token=
  # binary_upload_url=
  # icon_key=
  # icon_token=
  # icon_upload_url=

  if [ -n "$ios_icon" ]
  then
    echo -e "\033[32m[fir.im] Uploading ios icon...\033[0m"
    result=$(
      curl \
        --silent \
        --form "file=@$ios_icon" \
        --form "key=$icon_key" \
        --form "token=$icon_token" \
        ${icon_upload_url}
    )
    rm -f $ios_icon
  fi

  if [ "$ios_export_method" == "enterprise" ]
  then
    release_type=inhouse
  else
    release_type=adhoc
  fi

  echo -e "\033[32m[fir.im] Uploading ios app...\033[0m"
  result=$(
    curl \
      --form "file=@$ios_app" \
      --form "key=$binary_key" \
      --form "token=$binary_token" \
      --form "x:name=$ios_name" \
      --form "x:version=$ios_version" \
      --form "x:build=$ios_code" \
      --form "x:changelog=$(node $libs/get-config.js log# "$@")" \
      --form "x:release_type=$release_type" \
      ${binary_upload_url}
  )
  node $libs/validate-fir.js "$result"
  echo -e "\n[fir.im] Install app by open link: \033[32mhttps://fir.im/$short_url\033[0m\n"
fi

echo -e "\033[32m[fir.im] Done!\033[0m"
