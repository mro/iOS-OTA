#!/bin/sh

host="example.com"
baseurl="https://${host}/tests/"
basedir="/var/www/vhosts/${host}/pages/tests/"

# DO EDIT ABOVE
# DO NOT EDIT BELOW

pb="/usr/libexec/PlistBuddy"
"${pb}" -h       >/dev/null ; [ $? = 1 ] || { echo "Please install ${pb} via Xcode-commandline?" ; exit 2; }
rsync --version  >/dev/null || { echo "Please \$ brew install rsync" ; exit 2; }
unzip -v         >/dev/null || { echo "Please \$ brew install unzip" ; exit 2; }
rapper --version >/dev/null || { echo "Please \$ brew install raptor" ; exit 2; }

me="$(dirname "${0}")"
mkdir -p "${me}/tmp/" || exit 4
unzip -p "${1}" "Payload/*.app/Info.plist" > "${me}/tmp/Info.plist" || {
  cat <<HELPEND
Upload an IPA for testing to webserver.

Give me the IPA as created by Xcode -> Window -> Organizer -> Archives -> Distribute App -> Ad-Hoc

SYNOPSIS

    \$ $0 <path to ipa>
HELPEND
  [ -r "${1}" ] || exit 3
  exit 3
}
DateCreated="$(date -r "${1}" +%FT%T%z)"
cd "${me}/tmp/" || exit 3

CFBundleIdentifier="$("${pb}" -c "Print :CFBundleIdentifier" Info.plist)"
CFBundleName="$("${pb}" -c "Print :CFBundleName" "Info.plist")"
CFBundleExecutable="$("${pb}" -c "Print :CFBundleExecutable" "Info.plist")"
CFBundleShortVersionString="$("${pb}" -c "Print :CFBundleShortVersionString" "Info.plist")"
CFBundleVersion="$("${pb}" -c "Print :CFBundleVersion" "Info.plist")"
CFBundleVersionGitSHA="$("${pb}" -c "Print :CFBundleVersionGitSHA" "Info.plist")"

ver="${CFBundleShortVersionString}.${CFBundleVersion}+${CFBundleVersionGitSHA}"
baseurl="${baseurl}${CFBundleExecutable}/"
basedir="${basedir}${CFBundleExecutable}/"
relurl="v${ver}/"

cat > manifest.plist <<MANI
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key> <string>software-package</string>
          <key>url</key>  <string>${baseurl}${relurl}app.ipa</string>
        </dict>
        <dict>
          <key>kind</key> <string>display-image</string>
          <key>url</key>  <string>${baseurl}/iTunesArtwork.png</string>
        </dict>
        <dict>
          <key>kind</key> <string>full-size-image</string>
          <key>url</key>  <string>${baseurl}/iTunesArtwork.png</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key> <string>${CFBundleIdentifier}</string>
        <key>bundle-version</key>    <string>${CFBundleVersion}</string>
        <key>kind</key>              <string>software</string>
        <key>title</key>             <string>${CFBundleName} ${ver}β</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
MANI

ssh "${host}" mkdir -p "${basedir}${relurl}"
rsync -avPz manifest.plist "${host}:${basedir}${relurl}manifest.plist"
rsync -avPz "${1}"         "${host}:${basedir}${relurl}app.ipa"

cat > "../v${ver}.ttl" <<RELE
<> doap:release <${relurl}> .

<${relurl}>
    a doap:Version ;
    doap:revision "${ver}" ;
    doap:created "${DateCreated}"^^xsd:dateTime ;
    doap:file-release <${relurl}manifest.plist> ;
    doap:specification <> ;
    foaf:img <iTunesArtwork.png> .

RELE

echo '<?xml-stylesheet type="text/xsl" href="assets/rdf2html.de.xslt"?>' > index.xml
cat ../index.ttl ../v*.ttl | rapper -i turtle -o rdfxml-abbrev - "${baseurl}" | tail -n +2 >> index.xml
rsync -avPz index.xml ../../iTunesArtwork.png ../*.ttl ../assets "${host}:${basedir}"

echo ""
echo "${baseurl}"

say sodala
