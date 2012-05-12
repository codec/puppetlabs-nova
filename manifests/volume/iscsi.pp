# Class: nova::volume::iscsi
#
# iscsi is the default volume driver for OpenStack. 
#
# [*Parameters*]
#
# [real_lvm] If set to true, will use real physical volumes and volume groups.
#  Optional. Defaults to true.
#  When set to false, it will use a file-based lvm solution.
#
# [volume_group] Name of the volume group to use.
#  Optional. Defaults to 'nova-volumes' - the OpenStack default.
#
# [iscsi_helper] Name of the iscsi helper to use.
#  Optional. Defaults to 'tgtadm' - the OpenStack default. 
#
# [iscsi_ip_prefix] Sets the equivalent OpenStack nova.conf option
#   Optional. Defaults to undef.
# 
# [config_hash] Sloppy way of providing extra needed values.
#   Required. 
#   When using real_lvm:
#     * config_hash['pv']: name of the physical volume where $volume_group 
#       will reside.
#   When not using real_lvm:
#     * config_hash['location']: path to the file-based img file.
#     * config_hash['size']: the size of the img file.
#       * Example: value of 20k means 20,000mb. Possibly confusing this way,
#         but is compatible with "dd" command.
#
# Example when using real_lvm:
#   class { 'nova::volume::iscsi':
#     config_hash => {
#       'pv' => '/dev/md1',
#     }
#   }
#   
# Example when using file-based lvm:
#   class { 'nova::volume::iscsi':
#     real_lvm     => false,
#     config_hash  => {
#       'location' => '/tmp/nova-volumes.img',
#       'size'     => '20k',
#     }
#   }
#

class nova::volume::iscsi (
  $real_lvm        = true,
  $volume_group    = 'nova-volumes',
  $iscsi_helper    = 'tgtadm',
  $iscsi_ip_prefix = undef,
  $config_hash
) {

  include 'nova::params'
  
  if $real_lvm {
    if !has_key($config_hash, 'pv') {
      fail('config_hash requires pv key when using real_lvm')
    } 

    $command = "vgcreate ${volume_group} ${config_hash['pv']}"
    $onlyif  = "pvs ${config_hash['pv']} && ! vgs ${volume_group}"
  } else {
    if !has_key($config_hash, 'location') {
      fail('config_hash requires location key when using file-based lvm')
    }
    if !has_key($config_hash, 'size') {
      fail('config_hash requires size key when using file-based lvm')
    }

    $command = "dd if=/dev/zero of=${config_hash['location']} bs=1M seek=${config_hash['size']} count=0 && vgcreate ${volume_group} `/sbin/losetup --show -f ${config_hash['location']}`"
    $onlyif  = "test ! -e ${config_hash['location']}"
  }

  exec { 'volumes':
    command => $command,
    onlyif  => $onlyif,
    path    => ['/bin', '/usr/bin', '/usr/local/bin', '/sbin'],
    before  => Service['nova-volume'],
  }

  if $iscsi_ip_prefix {
    nova_config { 'iscsi_ip_prefix': value => $iscsi_ip_prefix }
  }

  case $iscsi_helper {
    'tgtadm': {
      package { 'tgt':
        name   => $::nova::params::tgt_package_name,
        ensure => present,
      }
      service { 'tgtd':
        name     => $::nova::params::tgt_service_name,
        provider => $::nova::params::special_service_provider,
        ensure   => running,
        enable   => true,
        require  => [Nova::Generic_service['volume'], Package['tgt']],
      }
      # This is the default, but might as well be verbose
      nova_config { 'iscsi_helper': value => 'tgtadm' }
    }

    default: {
        fail("Unsupported iscsi helper: ${iscsi_helper}. The supported iscsi helper is tgtadm.")
    }
  }
}
