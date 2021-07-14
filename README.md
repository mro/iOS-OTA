# Simplify iPhone OTA deployment

## IPA OTA Deployment

requires an [IPA](https://en.wikipedia.org/wiki/.ipa_%28file_extension%29) as created
e.g. by [Xcode](http://developer.apple.com/tools/xcode/)
-> Window -> Organizer -> Archives -> Distribute App -> Ad Hoc.

Extracts Icon and Info.plist from the IPA and creates the required manifest.

Creates a [doap](http://usefulinc.com/doap/) rdf/xml,
rendered to html by a [xslt](http://www.w3.org/TR/xslt) stylesheet (client-side).

## Installation

1. Copy `./ios-ota/` anywhere, e.g. into your iOS project,
2. adjust the first 3 lines of `./ios-ota/deploy-ipa.sh` accordingly and
3. run it.

Needs a webserver capable serving static files (the IPAs to test).
