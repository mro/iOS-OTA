# Simplify iPhone OTA deployment

## IPA OTA Deployment

requires just an IPA in <code><myproject>/deploy/v<num>/Debug</code> as created e.g. by Xcode "Organizer -> Archived Applications -> Share -> Save to Disk".

Extracts mobileprovision, Icon and iTunesArtwork from the IPA.

## Installation

- [Apache Webserver with eruby](http://www.google.de/search?q="eruby"+apache) running.
- install [cfpropertylist gem](https://github.com/ckruse/CFPropertyList).
