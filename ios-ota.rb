# https://github.com/mro/iOS-OTA
# requires the shell commands
# - file
# - zip
# - unzip
# and gems
require 'rubygems'
# require 'yaml'
require 'uri'
require 'cfpropertylist' # https://github.com/ckruse/CFPropertyList
#
# Generate doc:
# 
# rm -rf doc; rdoc --diagram --charset utf8 --main IphoneOta

# Ease ipa OTA deployment.
class IphoneOta

	def self.most_recent base_url=nil, ipa_files=File.join('deploy','v*', 'Debug', '*.ipa')
		base_url = 'http://' << ENV['HTTP_HOST'] << ENV['REQUEST_URI'].gsub(/\/(index\.[^\/]+)?$/, '') << '/' if base_url.nil?
		raise "base_url is nil" if base_url.nil?
		base_url = URI::parse base_url unless base_url.kind_of? URI
		raise "base_url is unparseable" if base_url.nil?

		each_version(base_url, ipa_files, false) { |ota| return ota }
		nil
	end
	
	def self.each_version base_url, ipa_files=File.join('deploy','v*', 'Debug', '*.ipa'), sort_ascending=false
		raise "base_url is nil" if base_url.nil?
		base_url = URI::parse base_url unless base_url.kind_of? URI
		raise "base_url is unparseable" if base_url.nil?

		ipa_files = Dir[ipa_files] if ipa_files.kind_of? String
		raise "Sry, but I need an array" unless ipa_files.kind_of? Array
		a = ipa_files.collect{|ipa| IphoneOta.new base_url, create_manifest_from_ipa(ipa, base_url, false)}
		if sort_ascending
			a.sort!{ |x,y| x <=> y }
		else
			a.sort!{ |x,y| y <=> x }
		end
		a.each { |ota| yield ota }
	end

	include Comparable

	# Compare version. Eases sorting.
	def <=>(anOther)
		version <=> anOther.version
	end

	# Assumptions:
	# 1. ipa + zip are alongside the manifest.plist
	# 2. ipa timestamp is release date
	# 3. bundle-version is integer
	# 4. first asset entry is the only relevant
	# 5. iTunesArtwork is png
	# 6. iTunesArtwork needs shine
	def initialize base_url, mani_plist_path, info=nil
		raise "base_url is nil" if base_url.nil?
		base_url = URI::parse base_url unless base_url.kind_of? URI
		raise "base_url is unparseable" if base_url.nil?

		@BASE_URL = base_url
		@MANI_PLIST_PATH = mani_plist_path
		plist = CFPropertyList::List.new :file => @MANI_PLIST_PATH
		@MANIFEST = CFPropertyList.native_types plist.value
		# plist = CFPropertyList::List.new :file => File.join(File.dirname(@MANI_PLIST_PATH), 'Info.plist')
		# @INFO = CFPropertyList.native_types plist.value
		# $stderr.puts @MANIFEST.to_yaml
		# $stderr.puts @info.to_yaml
	end

	# Integer version number as created with agvtool.
	def version
		# @INFO[:CFBundleVersion].to_i
		@MANIFEST['items'][0]['metadata']['bundle-version'].to_i
	end

	def full_version info=nil
		info = File.join File.dirname(@MANI_PLIST_PATH), 'Info.plist' if info.nil?
		unless defined? @INFO
			@INFO = CFPropertyList.native_types(CFPropertyList::List.new(:file => info).value)
		end
		"#{@INFO['CFBundleShortVersionString']}.#{@INFO['CFBundleVersion']}"
	end

	def title
		# @INFO[:CFBundleDisplayName]
		@MANIFEST['items'][0]['metadata']['title']
	end

	# iTunesArtwork image url.
	def itunes_artwork_url
		@MANIFEST['items'][0]['assets'].each do |asset|
			# Hack!
			return URI::parse "#{asset['url']}.png" if asset['kind'] == 'full-size-image'
		end
		nil
	end

	# URL for iOS OTA download.
	def ota_url
		m_url = ipa_url + 'manifest.plist'
		"itms-services://?action=download-manifest&amp;url=#{m_url}"
	end

	# Href to doxygen change list.
	def change_url
		URI::parse ipa_url.to_s.gsub(/\/[^\/]+\.ipa$/, '/../html/main.html#change')
	end

	# Zip File with IPA + mobileprovision - ready for iTunes sync.
	def zip_url
		URI::parse ipa_url.to_s.gsub(/\.ipa$/, '.zip')
	end

	def img_qr_code opts={}
		opts[:url] = @BASE_URL if opts[:url].nil?
		opts[:size] = 150 if opts[:size].nil?
		opts[:alt] = 'QR Code' if opts[:alt].nil?
		opts[:title] = opts[:alt] if opts[:title].nil?
		"<img src='http://chart.apis.google.com/chart?cht=qr&amp;chs=#{opts[:size]}x#{opts[:size]}&amp;chl=#{opts[:url]}' alt='#{opts[:alt]}' title='#{opts[:title]}' />"
	end

	# IPA file modification time
	def mtime
		ipa_file = ipa_url.path.gsub(/^.*\//, '')
		File.mtime File.join( File.dirname(@MANI_PLIST_PATH), ipa_file )
	end

private
	# Icon.png URL - not very useful as the image is crypted.
	def icon_url
		@MANIFEST['items'][0]['assets'].each do |asset|
			return URI::parse asset['url'] if asset['kind'] == 'display-image'
		end
		nil
	end

	# IPA download URL, mostly for inclusion in manifest
	def ipa_url #:doc:
		@MANIFEST['items'][0]['assets'].each do |asset|
			return URI::parse asset['url'] if asset['kind'] == 'software-package'
		end
		nil
	end

	# 
	# Parameters
	# +ipa_file+::	path to existing ipa
	# +base_url+::	base_url + ipa_file points to IPA on the Webserver
	# +force+::		create manifest, no matter what the timestamps say
	# +return+::	manifest.plist file path
	def self.create_manifest_from_ipa( ipa_file, base_url, force=false )#:doc:
		mani_file = File.join File.dirname(ipa_file), 'manifest.plist'
		return mani_file unless force || !File.exists?(mani_file) || File.mtime(ipa_file) > File.mtime(mani_file)
		raise "ipa_file is nil" if ipa_file.nil?
		raise "base_url is nil" if base_url.nil?
		base_url = URI::parse base_url unless base_url.kind_of? URI
		raise "base_url is unparseable" if base_url.nil?
#		base_url <<= '/' if base_url.match(/^.*\/$/).nil?
		build_ota ipa_file, base_url + ipa_file
		mani_file
	end
	
	# How to create stuff from just the ipa
	# 1. extract Info.plist and create manifest.plist
	# 2. extract Mobileprovision and create zip
	# 3. extract Icon.png and iTunesArtwork
	def self.build_ota( ipa_path, ipa_url )#:doc:
		raise "ipa_url is nil" if ipa_url.nil?
		ipa_url = URI::parse ipa_url unless ipa_url.kind_of? URI
		raise "ipa_url is unparseable" if ipa_url.nil?

		cwd = Dir.pwd
		Dir.chdir File.dirname(ipa_path)
		# $stderr.puts "IPA url '#{ipa_url}' (#{ipa_url.class})"
		ret = {:ipa => ipa_url.to_s}
		
		if ! FileTest.exist?('embedded.mobileprovision')
			%x{ unzip -j *.ipa Payload/*.app/embedded.mobileprovision; chmod a+w embedded.mobileprovision} 
			raise "Couldn't unzip embedded.mobileprovision from '#{ipa_path}'" if $? != 0
		end
		File.rename('embedded.mobileprovision', File.basename(ipa_path, '.ipa') << '.mobileprovision')
		%x{ zip dst.zip *.ipa *.mobileprovision; chmod a+w dst.zip} 
		raise "Couldn't zip '#{File.basename(ipa_path, '.ipa')}.zip'" if $? != 0
		File.rename('dst.zip', File.basename(ipa_path, '.ipa') << '.zip')
		ret[:zip] = (ipa_url + (File.basename(ipa_path, '.ipa') + '.zip')).to_s
		
		if ! FileTest.exist?('Info.plist')
			%x{ unzip -j *.ipa Payload/*.app/Info.plist; chmod a+w Info.plist } 
			raise "Couldn't unzip Info.plist from '#{ipa_path}'" if $? != 0
		end
#		if ! FileTest.exist?('Icon.png')
#			%x{ unzip -j *.ipa Payload/*.app/Icon.png; chmod a+w Icon.png } 
#			raise "Couldn't unzip Icon.png from '#{ipa_path}'" if $? != 0
#		end
#		ret[:icon] = "#{base_url}/Icon.png"
		
		begin
			if ! FileTest.exist?('iTunesArtwork')
				%x{ unzip -j *.ipa Payload/*.app/iTunesArtwork; chmod a+w iTunesArtwork }
				raise "Couldn't unzip iTunesArtwork from '#{ipa_path}'" if $? != 0
			end
			art = nil
			IO.popen("file --brief --mime-type iTunesArtwork") { |f| art = f.read }
			art = 'iTunesArtwork' << case art.strip
				when 'image/png'	then '.png'
				when 'image/jpeg'	then '.jpg'
				else				raise "strange image mime: '#{art}'"
			end
			File.symlink('iTunesArtwork', art)
			ret[:artwork] = (ipa_url + art).to_s
		rescue
		end

		if ! FileTest.exist?('manifest.plist')
			manifest = info_plist_to_manifest ipa_url, 'Info.plist'
			plist = CFPropertyList::List.new
			plist.value = CFPropertyList.guess(manifest)
			plist.save("manifest.plist", CFPropertyList::List::FORMAT_BINARY)
		end
		ret[:manifest] = (ipa_url + 'manifest.plist').to_s

		Dir.chdir cwd
		ret
	end

	def self.info_plist_to_manifest ipa_url, info = 'Info.plist'
		raise "ipa_url is nil" if ipa_url.nil?
		ipa_url = URI::parse ipa_url unless ipa_url.kind_of? URI
		raise "ipa_url is unparseable" if ipa_url.nil?

		info = CFPropertyList.native_types(CFPropertyList::List.new(:file => info).value) if info.kind_of? String
		ret = {'metadata' => {}, 'assets' => [] }
		ret['metadata']['kind'] = 'software'
		ret['metadata']['title'] = info['CFBundleName']
		ret['metadata']['subtitle'] = info['CFBundleIdentifier']
		ret['metadata']["bundle-identifier"] = info['CFBundleIdentifier']
		ret['metadata']["bundle-version"] = info['CFBundleVersion']
		ret['assets'] << {'kind' => "software-package", 'url' => ipa_url.to_s}
		ret['assets'] << {'kind' => "display-image", 'url' => (ipa_url + 'Icon.png').to_s, "needs-shine" => true}
		ret['assets'] << {'kind' => "full-size-image", 'url' => (ipa_url + 'iTunesArtwork').to_s, "needs-shine" => true}
		ret = {'items' => [ret]}
	end
end