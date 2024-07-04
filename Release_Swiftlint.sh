# /bin/zsh

buildTime=`date "+%Y-%m-%d-%H-%M-%S"`

swift package clean 

mkdir -p ".build/universal"

swift build --configuration release --product swiftlint --arch arm64 --verbose

swift build --configuration release --product swiftlint --arch x86_64 --verbose

lipo -create -output \
		".build/universal/swiftlint_"${buildTime} \
		".build/arm64-apple-macosx/release/swiftlint" \
		".build/x86_64-apple-macosx/release/swiftlint"

# 移除符号信息和调试信息 
strip -rSTX ".build/universal/swiftlint_"${buildTime}