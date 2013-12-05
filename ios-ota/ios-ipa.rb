#
# iOS IPA OTA deployment helper.
#
# https://github.com/mro/iOS-OTA
#
require 'rubygems'
require 'uri'            # http://www.ruby-doc.org/stdlib-1.8.7/libdoc/uri/rdoc/
require 'fileutils'      # http://www.ruby-doc.org/stdlib-1.8.7/libdoc/fileutils/rdoc/
require 'cfpropertylist' # http://cfpropertylist.rubyforge.org/ https://github.com/ckruse/CFPropertyList

class Time
  # ISO8601 by default.
  def to_s
    self.strftime('%FT%T%z').gsub(/(\d\d)$/, ':\1')
  end
end

module Name
  module Mro

    # Ease ipa OTA deployment.
    # 
    # Examine IPA and generate manifest.plist
    # About manifest.plist:
    # - http://help.apple.com/iosdeployment-apps/mac/1.1/#app43ad78b3
    # - http://help.apple.com/iosdeployment-apps/mac/1.1/#app43ad871e
    class IosIpa

      # absolute base uri from cgi ENV[]
      def self.base_uri
        base_url = 'http' << (ENV['HTTPS'] == 'on' ? 's' : '') << '://' << ENV['HTTP_HOST'] << ENV['REQUEST_URI'].gsub(/\/(index\.[^\/]+)?$/, '') << '/'
        raise "base_url is nil" if base_url.nil?
        base_url = URI::parse base_url unless base_url.kind_of? URI
        raise "base_url is unparseable" if base_url.nil?
        base_url
      end

      # array of Release objects for each ipa (recursive)
      def self.releases base_url=nil
        base_url = self.base_uri if base_url.nil?
        Dir.glob('**/*.ipa').collect{|ipa_path| Release.create(base_url, ipa_path)}.compact
      end
    end

    class Release

      # factory
      def self.create base, ipa_path
        begin
          self.new base, ipa_path
        rescue Exception => e
          nil
        end
      end

      attr_reader :base_uri
      attr_reader :ipa_path, :path, :date_created, :manifest_path, :version, :docs_path, :artwork_path
      attr_reader :info_plist_path, :icon_path

      def initialize base, ipa_path
        @base_uri = base
        @ipa_path = ipa_path
        @path = File.join File.dirname(@ipa_path), ''
        @manifest_path = File.join @path, 'manifest.plist'
        @info_plist_path = File.join @path, 'Info.plist'
        @artwork_path = File.join @path, 'iTunesArtwork.png'
        @icon_path = File.join @path, 'Icon.png'

        @manifest = self.make_manifest

        @artwork_path = 'iTunesArtwork.png' unless File.exist?(self.artwork_path)
        @version = @manifest['items'][0]['metadata']["bundle-version"]

        @docs_path = File.join 'docs', 'v' + self.version, ''
        @docs_path = nil unless File.exist? @docs_path

        @date_created = File.mtime self.info_plist_path
      end

    protected

      def make_manifest
        if File.exist?( self.manifest_path )
          return CFPropertyList.native_types(CFPropertyList::List.new(:file => self.manifest_path).value)
        end

        self.unzip_from_ipa ['Info.plist', 'Icon.png', 'iTunesArtwork']

        # todo create iTunesArtwork softlink
        # f = File.join(self.path, 'iTunesArtwork')
        # if File.exist? f
        #  FileUtils.ln_s f, 'iTunesArtwork.png'
        # else
          # FileUtils.ln_s 'iTunesArtwork', self.artwork_path
        # end

        manifest = self.manifest_from_info_plist( self.base_uri + self.ipa_path, self.info_plist_path )
        plist = CFPropertyList::List.new
        plist.value = CFPropertyList.guess(manifest)
        plist.save(self.manifest_path, CFPropertyList::List::FORMAT_XML)
        
        t = File.mtime self.info_plist_path
        File.utime t, t, self.manifest_path
        manifest
      end

    private

      def unzip_from_ipa filenames
        cmd = "unzip "
        cmd <<= '-j' << ' '
        cmd <<= self.ipa_path + ' '
        filenames.each do |filename|
          cmd <<= File.join('Payload', '*.app', filename) << ' '
        end
        cmd <<= '-d' << ' '
        cmd <<= self.path + ' '
        cmd <<= '1>/dev/null' << ' '
        cmd <<= '2>/dev/null' << ' '
        system cmd
      end

      def manifest_from_info_plist ipa_url, info
        raise "ipa_url is nil" if ipa_url.nil?
        ipa_url = URI::parse ipa_url unless ipa_url.kind_of? URI
        raise "ipa_url is unparseable" if ipa_url.nil?

        info = CFPropertyList.native_types(CFPropertyList::List.new(:file => info).value) if info.kind_of? String
        ret = {'metadata' => {}, 'assets' => [] }
        ret['metadata']['kind'] = 'software'
        ret['metadata']['title'] = info['CFBundleName']
        ret['metadata']['subtitle'] = info['CFBundleIdentifier']
        ret['metadata']["bundle-identifier"] = info['CFBundleIdentifier']
        # ret['metadata']["bundle-version"] = info['CFBundleVersion']
        ret['metadata']["bundle-version"] = info['CFBundleShortVersionString']
        ret['assets'] << {
          'kind' => "software-package",
          'url' => ipa_url.to_s
        }
        ret['assets'] << {
          'kind' => "display-image",
          'url' => (ipa_url + 'Icon.png').to_s,
          'needs-shine' => true
        }
        ret['assets'] << {
          'kind' => "full-size-image",
          'url' => (ipa_url + 'iTunesArtwork').to_s,
          'needs-shine' => true
        }
        ret = {'items' => [ret]}
      end

    end

  end
end