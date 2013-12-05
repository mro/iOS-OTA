# Simplify iPhone OTA deployment

## IPA OTA Deployment

requires just an [IPA](https://en.wikipedia.org/wiki/.ipa_%28file_extension%29) as created
e.g. by [Xcode](http://developer.apple.com/tools/xcode/)
"Organizer -> Archived Applications -> Share -> Save to Disk".

Extracts Icon, iTunesArtwork and Info.plist from the IPA and automagically creates the
required manifest.

Creates a [doap](http://usefulinc.com/doap/) rdf/xml,
rendered to html by a [xslt](http://www.w3.org/TR/xslt) stylesheet (client-side).

## Installation

- [Apache Webserver with eruby](http://www.google.de/search?q="eruby"+apache)
- or [Lighttpd Webserver with erubis](http://www.google.de/search?q="erubis"+lighttpd) running.
- install [cfpropertylist gem](https://github.com/ckruse/CFPropertyList).

[![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=mro&url=https://github.com/mro/iOS-OTA&title=iOS-OTA&language=&tags=github&category=software) 
