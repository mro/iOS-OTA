# Simplify iPhone OTA deployment

## IPA OTA Deployment

requires an [IPA](https://en.wikipedia.org/wiki/.ipa_%28file_extension%29) as
created e.g. by [Xcode](https://developer.apple.com/xcode/) -> Window -> Organizer
-> Archives -> Distribute App -> Ad Hoc.

Extracts Icon and Info.plist from the IPA and creates the required manifest.

Creates a [doap](http://usefulinc.com/doap/) rdf/xml,
rendered to html by a [xslt](http://www.w3.org/TR/xslt) stylesheet (client-side).

## Installation

1. Copy `./ios-ota/` anywhere, e.g. into your iOS project,
2. adjust the first 3 lines of `./ios-ota/deploy-ipa.sh` accordingly and
3. run it.

Needs a webserver serving static files (the IPAs to test plus manifest), so e.g.
[darkhttpd](https://unix4lyfe.org/darkhttpd/),
[thttpd](http://www.acme.com/software/thttpd/),
[quark](http://tools.suckless.org/quark/) or
[althttpd](https://sqlite.org/althttpd/) will do behind a reverse proxy like
[stunnel](https://fossil-scm.org/home/doc/trunk/www/server/any/stunnel.md) to have
TLS as iOS OTA requires.

