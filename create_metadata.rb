#! /usr/bin/ruby

require "rexml/document"
require "fileutils"
require "rubygems"
require "json"

IMAGE_TYPES = ["oem", "iso", "net", "vmx"]
ARCHS = ["all", "x86_64", "i686"] 
KIWI_DIR = "/usr/share/kiwi/image"
METADATA_DIR = "/usr/share/studio/metadata"

def get_profiles(node)
  REXML::XPath.each(node, "//image/profiles/profile/@name").map(&:value)
end

def get_packages(node, options = {})
  matcher = "@type='#{options[:type]}'"

  if options[:profile]
    matcher << " and @profiles='#{options[:profile]}'"
  else
    matcher << " and not(@profiles)"
  end

  case options[:arch]
  when "x86_64", "i686"
    arch = "@arch='#{options[:arch]}'"
  else
    arch = "not(@arch)"
  end

  REXML::XPath.each(node, "//image/packages[#{matcher}]/package[#{arch}]/@name").map(&:value)
end

def create_profile_packages(node)
  profile_packages = {}
  get_profiles(node).each do |profile|
    tmp = create_package_object(node, { :profile => profile })
    profile_packages[profile.to_sym] = tmp unless tmp.empty?
  end

  profile_packages
end

# {
#   "bootstrap": {
#     "all": [...],
#     "x86_64": [...]
#   },
#   "image": {
#     "i686": [...]
#   }
# }
#
def create_package_object(node, options = {})
  data = {}
  [:image, :bootstrap].each do |type|
    tmp = {}

    ARCHS.each do |arch|
      opts = options.update(
        :arch => arch,
        :type => type
      )

      pkgs = get_packages(node, opts)
      # Prevent from writing empty json data
      tmp[arch.to_sym] = pkgs unless pkgs.empty?
    end
    # Prevent from writing empty json data
    data[type] = tmp unless tmp.empty?
  end

  data
end

# {
#   "oem": {
#     "profiles": [...],
#     "profile_packages": {
#       "std" => {
#         "bootstrap": {},
#         "image": {}
#       }, {
#         ...
#       },
#     },
#     "packages": {
#       "image": {},
#       "bootstrap": {}
#     }
#   }
# }
def create_pkgs_for_image_type(node, image_type)
  {
    image_type.to_sym => {
      :profiles         => get_profiles(node),
      :profile_packages => create_profile_packages(node),
      :packages         => create_package_object(node)
    }
  }
end

def create_json(node)
  IMAGE_TYPES.map do |image_type|
    create_pkgs_for_image_type(node, image_type)
  end
end

def load_xml(path)
  if File.exists?(path)
    REXML::Document.new(File.read(path))
  else
    raise "File '#{path}' does not exist."
  end
end

def create_metadata(build_dir)
  Dir["#{build_dir}/#{KIWI_DIR}/*boot/suse-*"].each do |config_path|
    next unless File.directory?(config_path) && File.exists?("#{config_path}/config.xml")

    basesystem = File.basename(config_path)

    FileUtils.mkdir_p("/tmp/metadata")
    File.open("/tmp/metadata/#{basesystem}.json", 'w') do |file|
      file.write(
        JSON.pretty_generate(
          create_json(
            load_xml("#{config_path}/config.xml")
          )
        )
      )
    end
  end
end


unless File.directory?(ARGV[0])
  abort("Invalid build directory\n")
end

create_metadata(ARGV[0])

