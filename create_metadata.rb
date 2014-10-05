#! /usr/bin/ruby

require "rexml/document"
require "fileutils"
require "rubygems"
require "json"

IMAGE_TYPES = ["oem", "iso", "net", "vmx"]
KIWI_DIR = "/usr/share/kiwi/image"
METADATA_DIR = "/usr/share/studio/metadata"

def get_profiles(node)
  REXML::XPath.each(node, "//image/profiles/profile/@name").map(&:value)
end

def get_packages(node, options = {})
  matcher = if options[:bootstrap]
    "@type='bootstrap'"
  else
    "@type='image'"
  end

  if options[:profile]
    matcher << " and @profiles='#{options[:profile]}'"
  end

  REXML::XPath.each(node, "//image/packages[#{matcher}]/package/@name").map(&:value)
end

def create_profile_packages(node)
  profile_packages = {}
  get_profiles(node).each do |profile|
    profile_packages[profile.to_sym] = {
      :image     => get_packages(node, :profile => profile),
      :bootstrap => get_packages(node, { :bootstrap => true, :profile => profile })
    }
  end

  profile_packages
end

# {
#   "image_type": "oem",
#   "data": {
#     "profiles": [...],
#     "profile_packages": {
#       "std" => {
#         "bootstrap": [...],
#         "image": [...]
#       }, {
#         ...
#       },
#     },
#     "packages": {
#       "image": [...],
#       "bootstrap": [...]
#     }
#   }
# }
def create_pkgs_for_image_type(node, image_type)
  {
    :image_type => image_type,
    :data       => {
      :profiles         => get_profiles(node),
      :profile_packages => create_profile_packages(node),
      :packages         => {
        :image     => get_packages(node),
        :bootstrap => get_packages(node, { :bootstrap => true })
      }
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

def create_metadata(build_dir, containment_name)
  Dir["#{build_dir}/#{KIWI_DIR}/*boot/suse-*"].each do |config_path|
    next unless File.directory?(config_path) && File.exists("#{config_path}/config.xml")

    # The path were we will store the created metadata
    path = "#{build_dir}/#{METADATA_DIR}/#{containment_name}"
    FileUtils.mkdir_p(path)

    basesystem = File.basename(config_path)
    File.open("#{path}/#{basesystem}.json", 'w') do |file|
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

unless ARGV[1] =~ /\A\S*\Z/
  abort("Invalid containment name\n")
end

create_metadata(ARGV[0], ARGV[1])

