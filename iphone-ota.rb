# requires the shell commands
# - file
# - zip
# - unzip
# and gems
require 'rubygems'
require 'cfpropertylist' # https://github.com/ckruse/CFPropertyList

def find_max_version_ipa variant = :Debug
	v = -1
	vpath = '-'
	Dir["deploy/v*/#{variant}/*.ipa"].each do |d|
		m = /deploy\/v([0-9]+)\//.match( d )
		if ! m.nil?
			no = m[1].to_i
			if no > v
				v = no
				vpath = d
			end
		end
	end
	vpath
end

	@BASE_URL = 'http://' << ENV['HTTP_HOST'] << ENV['REQUEST_URI'].gsub(/\/(index\.[^\/]+)?$/, '') << '/'
	# find max. version
	@IPA_PATH = find_max_version_ipa
	# optional: link to changes (doxygen docs)
	@CHANGE_PATH = @IPA_PATH.gsub( /Debug.*\.ipa/, 'html/main.html#change' )

def info_plist_to_manifest ipa_url, info = 'Info.plist'
	info = CFPropertyList.native_types(CFPropertyList::List.new(:file => info).value) if info.kind_of? String
	ret = {'metadata' => {}, 'assets' => [] }
	ret['metadata']['kind'] = 'software'
	ret['metadata']['title'] = info['CFBundleName']
	ret['metadata']['subtitle'] = info['CFBundleIdentifier']
	ret['metadata']["bundle-identifier"] = info['CFBundleIdentifier']
	ret['metadata']["bundle-version"] = info['CFBundleVersion']
	ret['assets'] << {'kind' => "software-package", 'url' => "#{ipa_url}"}
	ret['assets'] << {'kind' => "display-image", 'url' => "#{File.dirname(ipa_url)}/Icon.png", "needs-shine" => true}
	ret['assets'] << {'kind' => "full-size-image", 'url' => "#{File.dirname(ipa_url)}/iTunesArtwork", "needs-shine" => true}
	ret = {'items' => [ret]}
end

# How to create stuff from just the ipa
# 1. extract Info.plist and create manifest.plist
# 2. extract Mobileprovision and create zip
# 3. extract Icon.png and iTunesArtwork
def build_ota ipa_path, ipa_url
	cwd = Dir.pwd
	Dir.chdir File.dirname(ipa_path)
	base_url = "#{File.dirname(ipa_url)}"
	ret = {:ipa => ipa_url}
	
	if ! FileTest.exist?('embedded.mobileprovision')
		%x{ unzip -j *.ipa Payload/*.app/embedded.mobileprovision; chmod a+w embedded.mobileprovision} 
		raise "Couldn't unzip embedded.mobileprovision from '#{ipa_path}'" if $? != 0
	end
	File.rename('embedded.mobileprovision', File.basename(ipa_path, '.ipa') << '.mobileprovision')
	%x{ zip dst.zip *.ipa *.mobileprovision; chmod a+w dst.zip} 
	raise "Couldn't zip '#{File.basename(ipa_path, '.ipa')}.zip'" if $? != 0
	File.rename('dst.zip', File.basename(ipa_path, '.ipa') << '.zip')
	ret[:zip] = "#{base_url}/#{File.basename(ipa_path, '.ipa')}.zip"
	
	if ! FileTest.exist?('Info.plist')
		%x{ unzip -j *.ipa Payload/*.app/Info.plist; chmod a+w Info.plist } 
		raise "Couldn't unzip Info.plist from '#{ipa_path}'" if $? != 0
	end
	if ! FileTest.exist?('Icon.png')
		%x{ unzip -j *.ipa Payload/*.app/Icon.png; chmod a+w Icon.png } 
		raise "Couldn't unzip Icon.png from '#{ipa_path}'" if $? != 0
	end
	ret[:icon] = "#{base_url}/Icon.png"
	
	if ! FileTest.exist?('iTunesArtwork')
		%x{ unzip -j *.ipa Payload/*.app/iTunesArtwork; chmod a+w iTunesArtwork } 
		raise "Couldn't unzip iTunesArtwork from '#{ipa_path}'" if $? != 0
	end
	art = nil
	IO.popen("file --brief --mime-type iTunesArtwork") { |f| art = f.read }
	art = 'iTunesArtwork' << case art.strip
		when 'image/png'    then '.png'
		when 'image/jpeg'   then '.jpg'
		else                raise "strange image mime: '#{art}'"
    end
	File.rename('iTunesArtwork', art)
	ret[:artwork] = "#{base_url}/#{art}"

	if ! FileTest.exist?('manifest.plist')
		manifest = info_plist_to_manifest ipa_url, 'Info.plist'
		plist = CFPropertyList::List.new
		plist.value = CFPropertyList.guess(manifest)
		plist.save("manifest.plist", CFPropertyList::List::FORMAT_BINARY)
	end
	ret[:manifest] = "#{base_url}/manifest.plist"
	
	Dir.chdir cwd
	ret
end

@META = build_ota(@IPA_PATH, "#{@BASE_URL}#{@IPA_PATH}")

def link_to_ota_manifest text
	"<a href='itms-services://?action=download-manifest&amp;url=#{@META[:manifest]}'>#{text}</a>"
end

def link_to_zip text
	"<a href='#{@META[:zip]}'>#{text}</a>"
end

def link_to_change text
	"<a href='#{@CHANGE_PATH}'>#{text}</a>"
end

def img_qr_code opts={}
	opts[:url] = @BASE_URL if opts[:url].nil?
	opts[:size] = 150 if opts[:size].nil?
	opts[:alt] = 'QR Code' if opts[:alt].nil?
	opts[:title] = opts[:alt] if opts[:title].nil?
	"<img src='http://chart.apis.google.com/chart?cht=qr&amp;chs=#{opts[:size]}x#{opts[:size]}&amp;chl=#{opts[:url]}' alt='#{opts[:alt]}' title='#{opts[:title]}' />"
end
