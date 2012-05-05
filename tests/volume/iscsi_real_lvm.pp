class { 'nova': }
class { 'nova::volume': 
  enabled => true,
}
class { 'nova::volume::iscsi':
  config_hash => {
    'pv' => '/dev/md1',
  }
}
