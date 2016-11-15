require 'yaml'
require 'tmpdir'
require 'open3'

class LightStemcellCreator
  def self.run(version, sha1, os, image_uuid, output_directory)
    raise "Output directory '#{output_directory}' does not exist" unless File.exists?(output_directory)
    filename = "light-bosh-stemcell-#{version}-openstack-kvm-#{os}-go_agent.tgz"
    output_path = File.absolute_path(File.join(output_directory, filename))

    Dir.mktmpdir do |tmp_dir|
      Dir.chdir(tmp_dir) do
        system("touch image")

        manifest = {
          'name' => "bosh-openstack-kvm-#{os}-go_agent",
          'version' => version,
          'bosh_protocol' => 1,
          'sha1' => sha1,
          'operating_system' => os,
          'cloud_properties' => {
            'name' => "bosh-openstack-kvm-#{os}-go_agent",
            'version' => version,
            'infrastructure' => 'openstack',
            'hypervisor' => 'kvm',
            'disk' => 3072,
            'disk_format' => 'qcow2',
            'container_format' => 'bare',
            'os_type' => 'linux',
            'os_distro' => extract_distro(os),
            'architecture' => 'x86_64',
            'auto_disk_config' => true,
            'image_uuid' => image_uuid
          }
        }
        File.write('stemcell.MF', YAML.dump(manifest))

        output, status = Open3.capture2e("tar czf #{output_path} .")
        raise output if status.exitstatus != 0
      end
      output_path
    end
  end

  private

  def self.extract_distro(os)
    distro = os.rpartition('-').first
    if distro.empty?
      raise "OS name contains no dash to separate the version from the name, i.e. 'name-version'"
    end
    distro
  end
end
