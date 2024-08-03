#!/bin/bash
# APT 软件更新、默认软件安装
function app_update_init() {
  echo
  echo "---------- APT 软件更新、默认软件安装 ----------"
  echo
  sudo apt install curl wget lsb-release -y
  sudo apt update -y  # 更新软件列表
  sudo apt upgrade -y # 更新所有软件
  # 默认安装：
  #   zsh - 命令行界面
  #   git - 版本控制工具
  #   vim - 文本编辑器
  #   unzip - 解压缩zip文件
  #   bc - 计算器
  #   curl - 网络文件下载
  #   wget - 网络文件下载
  #   rsync - 文件同步
  #   bottom - 图形化系统监控
  #   neofetch - 系统信息工具
  sudo apt install zsh git vim unzip bc rsync jq bzip2 lsof telnet htop screen tree make net-tools lrzsz psmisc hwloc gsmartcontrol chrony -y

  if ! type btm >/dev/null 2>&1; then                                                                 # 如果没有安装 bottom
    wget https://github.com/ClementTsang/bottom/releases/download/0.9.6/bottom_0.9.6_amd64.deb -P ~ # 从官方仓库下载安装包
    sudo dpkg -i ~/bottom_0.9.6_amd64.deb                                                             # 使用 Debian 软件包管理器，安装 bottom
  else
    echo "已安装 bottom"
  fi

  if ! type neofetch >/dev/null 2>&1; then
    if ! sudo apt install neofetch -y; then
      git clone https://$github_repo/dylanaraps/neofetch
      sudo make -C ~/neofetch install # 手动从 makefile 编译安装
    fi
  else
    echo "已安装 neofetch"
  fi

  # 下载 vim 自定义配置文件
  wget https://raw.githubusercontent.com/dylan2012/ubuntu_init/main/.vimrc -P ~

  neofetch
}

# Docker 安装/更新
function docker_init() {
  echo
  echo "---------- 安装/更新 Docker ----------"
  echo
  release_ver=$(awk '/Ubuntu/ {print $2}' /etc/issue | awk -F. '{printf "%2s.%s\n",$1,$2}') # 获得 Ubuntu 版本号（如：20.04）
  if echo "$(echo "$release_ver" | bc) >= 18.04" | bc; then                                 # 如果版本符合要求
    echo "安装/更新 Docker 环境..."

    if docker -v; then # 如果 docker 已安装
      echo "删除现有容器"
      docker rm -f "$(docker ps -q)"
    fi

    # sudo apt-get remove docker docker-engine docker.io containerd runc && \
    sudo apt-get install \
      ca-certificates \
      curl \
      gnupg \
      lsb-release -y                                                                                                # 预装 Docker 需要的软件
    sudo mkdir -p /etc/apt/keyrings                                                                                 # 创建公钥文件夹
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && # 添加 Docker 官方的 GPG 密钥
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null # 重新建立 apt 仓库
    sudo apt-get update -y                                                               # 更新 apt 仓库
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y  # 安装 docker 相关软件
    service docker restart                                                               # 重启 docker 环境
	curl -L "https://github.com/docker/compose/releases/download/v2.2.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
    echo "安装/更新 docker 环境完成!"
  else
    echo "Ubuntu 版本低于 18.04 无法安装 Docker"
  fi
}

function setssh() {
	sed -ri 's/^(PasswordAuthentication).*/\1 yes/' /etc/ssh/sshd_config
	sed -ri 's/.*(PermitRootLogin).*/\1 yes/' /etc/ssh/sshd_config
	service sshd restart
}

setSYSCTL() {
	cp /etc/sysctl.conf{,_$(date "+%Y%m%d_%H%M%S")_backup}
	cat > /etc/sysctl.conf <<EOF
		fs.file-max=65535
		net.ipv4.tcp_max_tw_buckets = 60000
		net.ipv4.tcp_sack = 1
		net.ipv4.tcp_window_scaling = 1
		net.ipv4.tcp_rmem = 4096 87380 4194304
		net.ipv4.tcp_wmem = 4096 16384 4194304
		net.ipv4.tcp_max_syn_backlog = 65536
		net.core.netdev_max_backlog = 32768
		net.core.somaxconn = 32768
		net.core.wmem_default = 8388608
		net.core.rmem_default = 8388608
		net.core.rmem_max = 16777216
		net.core.wmem_max = 16777216
		net.ipv4.tcp_timestamps = 0
		net.ipv4.tcp_synack_retries = 2
		net.ipv4.tcp_syn_retries = 2
		#net.ipv4.tcp_tw_recycle = 1
		#net.ipv4.tcp_tw_len = 1
		net.ipv4.tcp_tw_reuse = 1
		net.ipv4.tcp_mem = 94500000 915000000 927000000
		net.ipv4.tcp_max_orphans = 3276800
		net.ipv4.ip_local_port_range = 1024 65000

		net.nf_conntrack_max = 6553500
		net.netfilter.nf_conntrack_max = 6553500
		net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
		net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
		net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
		net.netfilter.nf_conntrack_tcp_timeout_established = 3600

		net.ipv4.conf.all.rp_filter = 2
		net.ipv4.ip_forward = 1
	EOF
	sysctl -p
	
	#设置
	cat >> /etc/security/limits.conf <<EOF
	*           soft   nofile       65535
	*           hard   nofile       65535
	EOF
	
	#设置上海时区
	timedatectl set-local-rtc 1
	timedatectl set-timezone Asia/Shanghai
	systemctl start chrony
	systemctl enable chrony
	
}

main() {
	app_update_init
	docker_init
	setssh
	setSYSCTL
}

main && clear; neofetch
