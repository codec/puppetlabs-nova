class { 'nova': }
class { 'nova::volume': 
  enabled => true,
}
class {'nova::volume::iscsi':
  real_lvm     => false,
  config_hash  => {
    'location' => '/tmp/nova-volumes.img',
    'size'     => '20k',
  }
}
