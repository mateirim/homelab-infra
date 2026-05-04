# profile::k8s_worker
#
# Prepares a node to join the Homelab-K8s-piCluster as a worker.
# Managed by Puppet — do NOT manually modify containerd/kubelet on these nodes.
#
# What this profile does:
#   1. Kernel modules  : overlay, br_netfilter  (required by containerd + Cilium)
#   2. sysctl          : IP forwarding, bridge iptables, conntrack tuning
#   3. Package repos   : Kubernetes apt/yum repo (version-pinned)
#   4. Packages        : containerd, kubelet, kubeadm, kubectl  (all version-pinned)
#   5. containerd      : drop-in config for SystemdCgroup = true + no-proxy settings
#   6. kubelet         : drop-in extra-args (node-ip, container-runtime-endpoint)
#   7. Services        : containerd + kubelet enabled and running
#
# Joining the cluster is intentionally NOT automated here — run kubeadm join
# manually (or via an Exec with a join token) once the node is ready.

class profile::k8s_worker (
  # Kubernetes minor version to install (e.g. '1.35')
  String $k8s_minor    = lookup('profile::k8s_worker::k8s_minor',    String, 'first', '1.35'),
  # Full package version string used to pin pkgs (e.g. '1.35.0-*' on Debian)
  String $k8s_pkg_ver  = lookup('profile::k8s_worker::k8s_pkg_ver',  String, 'first', '1.35*'),
  # Containerd package version pin (empty string = latest)
  String $ctr_pkg_ver  = lookup('profile::k8s_worker::ctr_pkg_ver',  String, 'first', '1.7*'),
  # CRI socket path
  String $cri_socket   = lookup('profile::k8s_worker::cri_socket',   String, 'first', 'unix:///var/run/containerd/containerd.sock'),
  # Cluster API endpoint (control-plane LB / DNS)
  String $api_endpoint = lookup('profile::k8s_worker::api_endpoint', String, 'first', 'kube.REPLACE_WITH_YOUR_DOMAIN:6443'),
  # Pod CIDR  (must match kubeadm ClusterConfiguration + Cilium)
  String $pod_cidr     = lookup('profile::k8s_worker::pod_cidr',     String, 'first', '10.200.0.0/16'),
) {

  # ── 1. Kernel modules ──────────────────────────────────────────────────────
  # Persist via /etc/modules-load.d so they survive reboots
  file { '/etc/modules-load.d/k8s.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "overlay\nbr_netfilter\n",
  }

  # Load them immediately if not already loaded
  exec { 'modprobe overlay':
    command => '/sbin/modprobe overlay',
    unless  => '/bin/grep -q "^overlay" /proc/modules',
    require => File['/etc/modules-load.d/k8s.conf'],
  }

  exec { 'modprobe br_netfilter':
    command => '/sbin/modprobe br_netfilter',
    unless  => '/bin/grep -q "^br_netfilter" /proc/modules',
    require => File['/etc/modules-load.d/k8s.conf'],
  }

  # ── 2. sysctl — networking ─────────────────────────────────────────────────
  file { '/etc/sysctl.d/99-k8s.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("SYSCTL"),
      # Kubernetes / Cilium required sysctl settings
      # Managed by Puppet — do not edit manually

      # IP forwarding (required for pod-to-pod routing)
      net.ipv4.ip_forward                 = 1
      net.ipv6.conf.all.forwarding        = 1

      # Bridge sees iptables rules (required even with Cilium kube-proxy replacement)
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.bridge.bridge-nf-call-arptables = 1

      # Conntrack table size — increase for heavy workloads
      net.netfilter.nf_conntrack_max      = 524288
      net.nf_conntrack_max                = 524288

      # Reverse path filtering — loose mode for multi-NIC nodes / Cilium native routing
      net.ipv4.conf.all.rp_filter         = 0
      net.ipv4.conf.default.rp_filter     = 0

      # Increase socket / file limits
      fs.inotify.max_user_instances       = 8192
      fs.inotify.max_user_watches         = 524288

      # Required by Cilium's eBPF programs
      kernel.panic                        = 10
      kernel.panic_on_oops                = 1
      | SYSCTL
    notify  => Exec['sysctl-reload-k8s'],
  }

  exec { 'sysctl-reload-k8s':
    command     => '/sbin/sysctl --system',
    refreshonly => true,
    require     => [
      Exec['modprobe overlay'],
      Exec['modprobe br_netfilter'],
    ],
  }

  # ── 3. Package repos ────────────────────────────────────────────────────────
  if $facts['os']['family'] == 'Debian' {

    # containerd from Docker's official repo (more up-to-date than distro pkg)
    exec { 'add-docker-gpg':
      command => '/bin/bash -c "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"',
      creates => '/etc/apt/keyrings/docker.gpg',
      path    => ['/usr/bin', '/bin'],
    }

    file { '/etc/apt/sources.list.d/docker.list':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${facts['os']['distro']['codename']} stable\n",
      require => Exec['add-docker-gpg'],
      notify  => Exec['apt-update-docker'],
    }

    exec { 'apt-update-docker':
      command     => '/usr/bin/apt-get update -o Dir::Etc::sourcelist="sources.list.d/docker.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"',
      refreshonly => true,
    }

    # Kubernetes apt repo (pkgs.k8s.io)
    exec { 'add-k8s-gpg':
      command => "/bin/bash -c \"curl -fsSL https://pkgs.k8s.io/core:/stable:/v${k8s_minor}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg\"",
      creates => '/etc/apt/keyrings/kubernetes-apt-keyring.gpg',
      path    => ['/usr/bin', '/bin'],
    }

    file { '/etc/apt/sources.list.d/kubernetes.list':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_minor}/deb/ /\n",
      require => Exec['add-k8s-gpg'],
      notify  => Exec['apt-update-k8s'],
    }

    exec { 'apt-update-k8s':
      command     => '/usr/bin/apt-get update -o Dir::Etc::sourcelist="sources.list.d/kubernetes.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"',
      refreshonly => true,
    }

    # ── 4. Packages ─────────────────────────────────────────────────────────
    package { 'containerd.io':
      ensure  => $ctr_pkg_ver,
      require => Exec['apt-update-docker'],
    }

    package { ['kubelet', 'kubeadm', 'kubectl']:
      ensure  => $k8s_pkg_ver,
      require => Exec['apt-update-k8s'],
    }

    # Hold Kubernetes packages to prevent accidental upgrades
    exec { 'hold-k8s-packages':
      command => '/usr/bin/apt-mark hold kubelet kubeadm kubectl',
      unless  => '/usr/bin/apt-mark showhold | /bin/grep -q kubelet',
      require => Package['kubelet', 'kubeadm', 'kubectl'],
    }

  } elsif $facts['os']['family'] == 'RedHat' {

    yumrepo { 'kubernetes':
      ensure   => present,
      baseurl  => "https://pkgs.k8s.io/core:/stable:/v${k8s_minor}/rpm/",
      gpgkey   => "https://pkgs.k8s.io/core:/stable:/v${k8s_minor}/rpm/repodata/repomd.xml.key",
      gpgcheck => true,
      enabled  => true,
      descr    => "Kubernetes v${k8s_minor}",
    }

    yumrepo { 'docker-ce':
      ensure   => present,
      baseurl  => 'https://download.docker.com/linux/centos/$releasever/$basearch/stable',
      gpgkey   => 'https://download.docker.com/linux/centos/gpg',
      gpgcheck => true,
      enabled  => true,
      descr    => 'Docker CE Stable',
    }

    package { 'containerd.io':
      ensure  => $ctr_pkg_ver,
      require => Yumrepo['docker-ce'],
    }

    package { ['kubelet', 'kubeadm', 'kubectl']:
      ensure  => $k8s_pkg_ver,
      require => Yumrepo['kubernetes'],
    }

    # Disable SELinux enforcement for Kubernetes (permissive)
    file_line { 'selinux-permissive':
      path  => '/etc/selinux/config',
      line  => 'SELINUX=permissive',
      match => '^SELINUX=',
    }

    exec { 'setenforce-permissive':
      command => '/usr/sbin/setenforce 0',
      onlyif  => '/usr/sbin/getenforce | /bin/grep -q Enforcing',
    }

    # Disable swap (k8s requirement)
    exec { 'disable-swap':
      command => '/sbin/swapoff -a',
      onlyif  => '/sbin/swapon --show | /usr/bin/wc -l | /bin/grep -v "^0$"',
    }

    file_line { 'remove-swap-fstab':
      path              => '/etc/fstab',
      match             => '^\S+\s+\S+\s+swap\s',
      match_for_absence => true,
    }
  }

  # ── 5. containerd configuration ────────────────────────────────────────────
  # Create the config directory before writing the config
  file { '/etc/containerd':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Full containerd config with SystemdCgroup enabled (required for kubeadm clusters)
  file { '/etc/containerd/config.toml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("TOML"),
      # containerd configuration
      # Managed by Puppet — do not edit manually
      version = 2

      [plugins]
        [plugins."io.containerd.grpc.v1.cri"]
          sandbox_image = "registry.k8s.io/pause:3.10"

          [plugins."io.containerd.grpc.v1.cri".containerd]
            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
              [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
                runtime_type = "io.containerd.runc.v2"

                [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
                  # SystemdCgroup MUST be true when using kubeadm + systemd cgroup driver
                  SystemdCgroup = true

          [plugins."io.containerd.grpc.v1.cri".registry]
            [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
              [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
                endpoint = ["https://registry-1.docker.io"]
      | TOML
    require => File['/etc/containerd'],
    notify  => Service['containerd'],
  }

  # ── 6. kubelet drop-in ─────────────────────────────────────────────────────
  file { '/etc/systemd/system/kubelet.service.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/systemd/system/kubelet.service.d/20-k8s-worker.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("UNIT"),
      # Kubelet drop-in — Managed by Puppet
      [Service]
      Environment="KUBELET_EXTRA_ARGS=--container-runtime-endpoint=${cri_socket} --node-ip=$(hostname -I | awk '{print $1}')"
      | UNIT
    require => File['/etc/systemd/system/kubelet.service.d'],
    notify  => Exec['systemd-daemon-reload'],
  }

  exec { 'systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  # Disable swap (universal — Kubernetes hard requirement)
  exec { 'swapoff':
    command => '/sbin/swapoff -a',
    onlyif  => '/usr/bin/test -n "$(swapon --show 2>/dev/null)"',
  }

  # Comment out swap entries in /etc/fstab to persist across reboots
  exec { 'comment-swap-fstab':
    command => "/bin/sed -i.bak '/\\bswap\\b/s/^/# DISABLED_BY_PUPPET /' /etc/fstab",
    onlyif  => "/bin/grep -qP '^[^#].*\\bswap\\b' /etc/fstab",
  }

  # ── 7. Services ────────────────────────────────────────────────────────────
  service { 'containerd':
    ensure  => running,
    enable  => true,
    require => [
      Package['containerd.io'],
      File['/etc/containerd/config.toml'],
    ],
  }

  service { 'kubelet':
    ensure  => running,
    enable  => true,
    require => [
      Package['kubelet'],
      Service['containerd'],
      Exec['systemd-daemon-reload'],
    ],
  }

  # ── 8. Useful tools on worker nodes ────────────────────────────────────────
  $worker_tools = [
    'curl', 'wget', 'jq', 'socat', 'conntrack', 'ipset',
    'iptables', 'iproute2', 'ethtool', 'nfs-common',
    'open-iscsi', 'lsscsi', 'sg3-utils', 'multipath-tools',
  ]

  package { $worker_tools:
    ensure => installed,
  }

  # Ensure iscsid is running (needed for iSCSI-backed PVs)
  service { 'iscsid':
    ensure  => running,
    enable  => true,
    require => Package['open-iscsi'],
  }

}
