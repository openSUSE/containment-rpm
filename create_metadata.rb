#! /usr/bin/ruby

require "rexml/document"
require "fileutils"
require "json"

IMAGE_TYPES = ["oem", "iso", "net", "vmx"]
KIWI_DIR = "/usr/share/kiwi/image"
METADATA_DIR = "/usr/share/studio/metadata"

def get_profiles(node)
  REXML::XPath.each(node, "//image/profiles/profile/@name").map(&:value)
end

def get_packages(node, options = {})
  matcher = "@type='image'"
  if options[:only_bootstrap]
    matcher << " @type='bootstrap'"
  end
  if options[:profile]
    matcher << " @profiles=#{options[:profile]}"
  end

  REXML::XPath.each(node, "//image/packages[#{matcher}]/package/@name").map(&:value)
end

def create_profiles(node)
  get_profiles(node).map do |profile|
    {
      :name => profile,
      :packages => get_packages(node, :profile => profile)
    }
  end
end

# {
#   "profiles": [
#     {
#       "name": "...",
#       "packages": [...]
#     },
#     {
#       ...
#     }
#   ],
#   "packages": {
#     "image": [...],
#     "bootstrap": [...]
#   }
# }
def create_pkgs_for_image_type(node, image_type)
  {
    :image_type => image_type,
    :data       => {
      :profiles => create_profiles(node),
      :packages => {
        :image     => get_packages(node),
        :bootstrap => get_packages(node, { :only_bootstrap => true })
      }
    }
  }
end

def create_json(node)
  IMAGE_TYPES.map do |image_type|
    create_pkgs_for_image_type(node, image_type)
  end.to_json
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
    next unless File.directory?(config_path)

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

unless ARGV[1] =~ /\A[\w\-]*\Z/
  abort("Invalid containment name\n")
end

create_metadata(ARGV[0], ARGV[1])

