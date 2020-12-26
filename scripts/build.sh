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
   echo Tailing the last 50 lines of output:
   tail -50 $BUILD_OUTPUT  
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


if [ "$BUILD_MACOS" = true ] || grep -q "Friedrich" "$TRAVIS_BUILD_DIR/changes.txt"
then
	echo ""
	echo "*********************************"
	echo "*     Installing macOS Pods     *"
	echo "*********************************"
	pod install
	pod update
	
	echo ""
	echo "***************************"
	echo "*     Archiving macOS     *"
	echo "***************************"
	xcrun xcodebuild -workspace "Monal.xcworkspace" -scheme "Monal" -sdk macosx -configuration Debug -destination 'generic/platform=macOS,variant=Mac Catalyst,name=Any Mac' -archivePath "build/macos_$APP_NAME.xcarchive" clean archive CODE_SIGN_IDENTITY="$APP_DEVELOPER_NAME" CODE_SIGN_STYLE="Manual" GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS IS_ALPHA=1' BUILD_LIBRARIES_FOR_DISTRIBUTION=YES SUPPORTS_MACCATALYST=YES >> $BUILD_OUTPUT 2>&1
	
	echo ""
	echo "****************************"
	echo "*     Exporting macOS      *"
	echo "****************************"
	# see: https://gist.github.com/cocoaNib/502900f24846eb17bb29
	# and: https://forums.developer.apple.com/thread/100065
	# and: for developer-id distribution (distribution *outside* of appstore) an developer-id certificate must be used for building
	xcodebuild -exportArchive -archivePath "build/macos_$APP_NAME.xcarchive" -exportPath "build/app" -exportOptionsPlist ../scripts/catalyst_exportOptions.plist
	echo "build dir:"
	ls -l "build"
	
	echo ""
	echo "**************************"
	echo "*     Packing macOS      *"
	echo "**************************"
	cd build/app
	mv "$APP_NAME.app" "$APP_NAME.alpha.app"
	tar -cf "$APP_NAME.tar" "$APP_NAME.alpha.app"
	cd ../..
	ls -l build/app
fi
	

echo ""
echo "*******************************"
echo "*     Installing iOS Pods     *"
echo "*******************************"
sed 's/###ios_only###//' Podfile >Podfile.new
mv Podfile Podfile.old
mv Podfile.new Podfile
pod install
pod update

echo ""
echo "*************************"
echo "*     Archiving iOS     *"
echo "*************************"
xcrun xcodebuild -workspace "Monal.xcworkspace" -scheme "Monal" -sdk iphoneos -configuration Debug -archivePath "build/ios_$APP_NAME.xcarchive" clean archive CODE_SIGN_IDENTITY="$IOS_DEVELOPER_NAME" CODE_SIGN_STYLE="Manual" GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS IS_ALPHA=1' >> $BUILD_OUTPUT 2>&1

echo ""
echo "*************************"
echo "*     Exporting iOS     *"
echo "*************************"
# see: https://gist.github.com/cocoaNib/502900f24846eb17bb29
# and: https://forums.developer.apple.com/thread/100065
xcodebuild -exportArchive -archivePath "build/ios_$APP_NAME.xcarchive" -exportPath "build/ipa" -exportOptionsPlist ../scripts/exportOptions.plist
echo "build dir:"
ls -l "build"


# The build finished without returning an error so dump a tail of the output
#dump_output
# nicely terminate the ping output loop
kill $PING_LOOP_PID
exit
