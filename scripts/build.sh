#!/bin/sh
# build commandline used by travis:
# set -o pipefail && xcodebuild -workspace Monal.xcworkspace -scheme Monal -destination platform\=iOS\ Simulator,OS\=13.2.2,name\=iPhone\ 8 build test | xcpretty

if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then
  echo "This is a pull request. No deployment will be done."
  exit 0
fi
if [[ "$TRAVIS_BRANCH" != "develop" ]]; then
  echo "Testing on a branch other than develop. No deployment will be done."
  exit 0
fi

# Abort on Error
set -e
export PING_SLEEP=10s
export BUILD_OUTPUT=../scripts/build.out
touch $BUILD_OUTPUT
dump_output() {
   echo Tailing the last 500 lines of output:
   tail -500 $BUILD_OUTPUT  
}
error_handler() {
  echo ERROR: An error was encountered with the build.
  dump_output
  exit 1
}
# If an error occurs, run our error handler to output a tail of the build
trap 'error_handler' ERR
# Set up a repeating loop to send some output to Travis.
bash -c "while true; do echo \$(date) - building ...; sleep $PING_SLEEP; done" &
PING_LOOP_PID=$!


ls -l ~/Library/MobileDevice/Provisioning\ Profiles/
# echo "*********************"
# echo "*     Building      *"
# echo "*********************"
# xcrun xcodebuild -workspace "Monal.xcworkspace" -scheme "Monal" -sdk iphoneos -configuration Debug build CODE_SIGN_IDENTITY="$DEVELOPER_NAME" CODE_SIGN_STYLE="Manual" > $BUILD_OUTPUT 2>&1
# #PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME"
echo "*********************"
echo "*     Archiving     *"
echo "*********************"
xcrun xcodebuild -workspace "Monal.xcworkspace" -scheme "Monal" -sdk iphoneos -configuration Debug -archivePath "build/$APP_NAME.xcarchive" archive CODE_SIGN_IDENTITY="$DEVELOPER_NAME" CODE_SIGN_STYLE="Manual" >> $BUILD_OUTPUT 2>&1
echo "**********************"
echo "*     Exporting      *"
echo "**********************"
# see: https://gist.github.com/cocoaNib/502900f24846eb17bb29
# and: https://forums.developer.apple.com/thread/100065
xcodebuild -exportArchive -archivePath "build/$APP_NAME.xcarchive" -exportPath "build/ipa" -exportOptionsPlist ../scripts/exportOptions.plist
echo "build dir:"
ls -l "build"

# The build finished without returning an error so dump a tail of the output
#dump_output
# nicely terminate the ping output loop
kill $PING_LOOP_PID
exit
