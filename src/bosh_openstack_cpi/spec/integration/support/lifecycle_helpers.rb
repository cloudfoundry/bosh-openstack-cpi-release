module Support
  module LifecycleHelpers
    def volumes(vm_id)
      openstack.compute.servers.get(vm_id).volume_attachments
    end

    def vm_lifecycle(stemcell_id, network_spec, disk_id = nil, cloud_properties = {}, resource_pool = {})
      vm_id = create_vm(stemcell_id, network_spec, Array(disk_id), resource_pool)

      if disk_id
        @config.logger.info("Reusing disk #{disk_id} for VM vm_id #{vm_id}")
      else
        @config.logger.info("Creating disk for VM vm_id #{vm_id}")
        disk_id = cpi.create_disk(2048, cloud_properties, vm_id)
        expect(disk_id).to be
      end

      @config.logger.info("Checking existence of disk vm_id=#{vm_id} disk_id=#{disk_id}")
      expect(cpi.has_disk?(disk_id)).to be(true)

      @config.logger.info("Attaching disk vm_id=#{vm_id} disk_id=#{disk_id}")
      cpi.attach_disk(vm_id, disk_id)

      @config.logger.info("Detaching disk vm_id=#{vm_id} disk_id=#{disk_id}")
      cpi.detach_disk(vm_id, disk_id)

      disk_snapshot_id = create_disk_snapshot(disk_id) unless @config.disable_snapshots
    rescue Exception => create_error
    ensure
      funcs = [
        -> { clean_up_disk(disk_id) },
        -> { clean_up_vm(vm_id) },
      ]
      funcs.unshift(-> { clean_up_disk_snapshot(disk_snapshot_id) }) unless @config.disable_snapshots
      run_all_and_raise_any_errors(create_error, funcs)
    end

    def create_vm(stemcell_id, network_spec, disk_locality, resource_pool = {}, environment = { 'bosh' => { 'group' => 'instance-group-1' } })
      @config.logger.info("Creating VM with stemcell_id=#{stemcell_id}")
      vm_id = cpi.create_vm(
        'agent-007',
        stemcell_id,
        { 'instance_type' => @config.instance_type,
          'availability_zone' => @config.availability_zone}.merge(resource_pool),
      network_spec,
      disk_locality,
      environment,
      )
      expect(vm_id).to be

      @config.logger.info("Checking VM existence vm_id=#{vm_id}")
      expect(cpi).to have_vm(vm_id)

      @config.logger.info("Setting VM metadata vm_id=#{vm_id}")
      cpi.set_vm_metadata(vm_id, {
        'deployment' => 'deployment',
        'name' => 'openstack_cpi_spec/instance_id',
      })

      vm_id
    end

    def clean_up_vm(vm_id)
      if vm_id
        @config.logger.info("Deleting VM vm_id=#{vm_id}")
        cpi.delete_vm(vm_id)

        @config.logger.info("Checking VM existence vm_id=#{vm_id}")
        expect(cpi).to_not have_vm(vm_id)
      else
        @config.logger.info('No VM to delete')
      end
    end

    def clean_up_disk(disk_id)
      if disk_id
        @config.logger.info("Deleting disk disk_id=#{disk_id}")
        cpi.delete_disk(disk_id)
      else
        @config.logger.info('No disk to delete')
      end
    end

    def create_disk_snapshot(disk_id)
      @config.logger.info("Creating disk snapshot disk_id=#{disk_id}")
      disk_snapshot_id = cpi.snapshot_disk(disk_id, {
        deployment: 'deployment',
        job: 'openstack_cpi_spec',
        index: '0',
        instance_id: 'instance',
        agent_id: 'agent',
        director_name: 'Director',
        director_uuid: '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
      })
      expect(disk_snapshot_id).to be

      @config.logger.info("Created disk snapshot disk_snapshot_id=#{disk_snapshot_id}")
      disk_snapshot_id
    end

    def clean_up_disk_snapshot(disk_snapshot_id)
      if disk_snapshot_id
        @config.logger.info("Deleting disk snapshot disk_snapshot_id=#{disk_snapshot_id}")
        cpi.delete_snapshot(disk_snapshot_id)
      else
        @config.logger.info('No disk snapshot to delete')
      end
    end

    def run_all_and_raise_any_errors(existing_errors, funcs)
      exceptions = Array(existing_errors)
      funcs.each do |f|
        begin
          f.call
        rescue Exception => e
          exceptions << e
        end
      end
      # Prints all exceptions but raises original exception
      exceptions.each { |e| @config.logger.info("Failed with: #{e.inspect}\n#{e.backtrace.join("\n")}\n") }
      raise exceptions.first if exceptions.any?
    end
  end
end

RSpec.configure do |config|
  config.include(Support::LifecycleHelpers)
end

