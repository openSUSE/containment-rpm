#! /usr/bin/ruby

require "rexml/document"
require "fileutils"
require "rubygems"
require "json"

IMAGE_TYPES = ["oem", "iso", "net", "vmx"]
ARCHS = ["all", "x86_64", "i686"]
KIWI_DIR = "/usr/share/kiwi/image"
METADATA_DIR = "/usr/share/studio/metadata"

def attr_query(name, val)
  if val
    "@#{name}='#{val}'"
  else
    "not(@#{name})"
  end
end

def get_profiles(node)
  REXML::XPath.each(node, "//image/profiles/profile/@name").map(&:value)
end

def get_packages(node, options = {})
  matcher = [
    attr_query("type", options[:type]),
    attr_query("profiles", options[:profile]),
  ].join(" and ")

  arch = attr_query("arch", ["x86_64", "i686"].grep(options[:arch]).pop)

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

def create_json_per_image_type(config_paths)
  IMAGE_TYPES.map do |image_type|
    path = config_paths.find { |f| f =~ /#{image_type}/ }
    file = "#{path}/config.xml"
    next unless File.exists?(file)

    node = REXML::Document.new(File.read(file))
    create_pkgs_for_image_type(node, image_type)
  end.compact
end

def sort_by_base_system(files)
  data = {}

  files.each do |file|
    next unless File.directory?(file)

    base_system = File.basename(file)
    data[base_system] ||= []
    data[base_system] << file
  end

  data
end

def create_metadata(build_dir)
  files = Dir["#{build_dir}/#{KIWI_DIR}/*boot/suse-*"].reject { |f| f =~ /containment$/ }

  sort_by_base_system(files).each do |base_system, files|
    FileUtils.mkdir_p("/tmp/metadata")
    File.open("/tmp/metadata/#{base_system}.json", 'w') do |file|
      file.write(
        JSON.pretty_generate(
          create_json_per_image_type(files)
        )
      )
    end
  end
end


unless File.directory?(ARGV[0])
  abort("Invalid build directory\n")
end

create_metadata(ARGV[0])

