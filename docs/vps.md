# VPS replica: `srv1696671`

Snapshot of the live Hostinger VPS as of **2026-09-29**, so a new box can match roles, packages, and configs.

This file is a rebuild guide, not a secret store. Do not paste private keys, account passwords, or the Pi-hole admin password here.

## What this box is for

| Role | How it runs | Who can reach it |
|---|---|---|
| SSH jump / admin | `sshd` on port 22 | Public internet (key login) |
| WireGuard VPN hub | `wg-quick@wg0` on UDP 51820 | Public internet; clients get `10.8.0.0/24` |
| Pi-hole DNS + admin UI | Docker `pihole/pihole:latest`, host network | VPN only (`wg0`). Ports 53/80/443 are firewalled from the WAN |
| Transmission | `transmission-roberto.service` | RPC on `127.0.0.1:9091` (SSH tunnel). Peer port 51413 |
| Dev workstation | Pacman toolchains, zsh, nvim, Docker, uv | SSH as `roberto` |

Mac-side helpers live in this repo: alias `vps` / `vps-root`, plus `vps-transmission` (tunnels local `9091` to the daemon).

## Live snapshot

| Item | Value |
|---|---|
| Provider hostname | `srv1696671.hstgr.cloud` (`srv1696671`) |
| Public IPv4 | `168.231.69.27/24`, gateway `168.231.69.254` |
| Public IPv6 | `2a02:4780:2d:7d4f::1/48`, gateway `2a02:4780:2d::1` |
| OS | Arch Linux (rolling), kernel `7.1.2-arch3-1` |
| Virt | KVM (QEMU), Hostinger cloud image + cloud-init |
| CPU / RAM | 2 vCPU (AMD EPYC 9355P), 7.7 GiB RAM |
| Disk | 100 GiB GPT on `/dev/sda`, btrfs root (`zstd:1`, `discard=async`) |
| Swap | `/swap/swapfile` 512 MiB (btrfs subvolume `swap`) |
| Timezone | UTC, NTP via `systemd-timesyncd` |
| Locale / keymap | `en_US.UTF-8`, `us` |
| Users | `root` (`/bin/zsh`), `roberto` uid 1000 (`wheel`, `docker`, `/bin/zsh`) |
| Sudo | `%wheel ALL=(ALL:ALL) NOPASSWD: ALL` |

Partition layout:

```
sda1  1M    BIOS boot
sda2  300M  EFI System (vfat, mounted at /efi, unused for boot today)
sda3  99.7G Linux root (btrfs UUID ab3dd9c5-112a-4e31-99da-d8b540e1aeee)
```

Boot is **BIOS/GRUB**, not EFI. Kernel cmdline:

```
root=UUID=<root-uuid> rw net.ifnames=0 rootflags=compress=zstd:1 console=tty0 console=ttyS0,115200
```

`net.ifnames=0` keeps the NIC named `eth0`. Keep that on a rebuild or every WireGuard/nftables/networkd file that says `eth0` will break.

## Rebuild order

1. Provision an Arch (or Hostinger Arch) VPS with a public IPv4, optional IPv6, and similar CPU/RAM/disk.
2. Create user `roberto`, add to `wheel` and `docker`, set zsh, enable passwordless sudo for `wheel`.
3. Install SSH keys, then lock in `sshd` (pubkey on, root login as you prefer).
4. Install packages (roles first, then the extra toolchain if you want the same workstation).
5. Enable IP forwarding, nftables, WireGuard, Docker, Transmission.
6. Bring up Pi-hole with compose on host networking.
7. Point the WireGuard client DNS at `10.8.0.1`.
8. Copy torrent data and Pi-hole gravity/config from backup if you need the old state.

## 1. Users, sudo, SSH

```bash
useradd -m -G wheel,docker -s /bin/zsh roberto
passwd roberto
passwd root
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-wheel-nopasswd
chmod 440 /etc/sudoers.d/99-wheel-nopasswd
```

Install this MacBook Pro public key on **both** `roberto` and `root`:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF2ln/odfGwlr8C3fA7lr4OwK1ijh1WTbaxVwIsM54GL jrgsx@icloud.com
```

```bash
install -d -m 700 /home/roberto/.ssh /root/.ssh
# paste the key into both authorized_keys
chmod 600 /home/roberto/.ssh/authorized_keys /root/.ssh/authorized_keys
chown -R roberto:roberto /home/roberto/.ssh
```

`sshd` effective settings on the live box:

- Port 22
- `PubkeyAuthentication yes`
- `PermitRootLogin yes`
- `PasswordAuthentication yes` (cloud-init drop-in `/etc/ssh/sshd_config.d/50-cloud-init.conf`)
- `KbdInteractiveAuthentication no`
- `UsePAM yes`

On a new box, generate a **new** host keypair under `/home/roberto/.ssh/id_ed25519` if the VPS itself needs outbound SSH. Do not reuse the old private key unless you restore it from backup.

Local SSH aliases (this laptop):

```
Host vps
  HostName <new-ip>
  User roberto
  IdentityFile ~/.ssh/macbook_pro/macbook_pro
  IdentitiesOnly yes

Host vps-root
  HostName <new-ip>
  User root
  IdentityFile ~/.ssh/macbook_pro/macbook_pro
  IdentitiesOnly yes
```

## 2. Network

`systemd-networkd` + `systemd-resolved`. Live unit: `/etc/systemd/network/10-cloud-init-eth0.network`.

On a new Hostinger-like image, cloud-init will write a similar file. Match this shape and put the **new** addresses in:

```ini
[Match]
Name=eth0

[Network]
DHCP=no
DNS=1.1.1.1 9.9.9.9

[Address]
Address=<public-ipv4>/24

[Address]
Address=<public-ipv6>/48

[Route]
Gateway=<ipv4-gateway>

[Route]
Gateway=<ipv6-gateway>
```

The live box also lists Hostinger DNS `153.92.2.6` and `8.8.4.4` on `eth0`. Resolved’s global servers are `1.1.1.1` and `9.9.9.9`.

`/etc/hosts`:

```
::1	localhost
127.0.0.1	localhost
127.0.0.1	srv1696671.hstgr.cloud	srv1696671
```

Enable forwarding (WireGuard NAT):

```bash
cat >/etc/sysctl.d/99-wireguard.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
sysctl --system
```

## 3. Firewall (nftables)

Service: `nftables.service` enabled. File: `/etc/nftables.conf`.

Default input/forward policy is **drop**. WAN is only SSH, WireGuard, and (intended) Transmission peer ports. Pi-hole and Transmission RPC are not opened on the WAN. VPN clients are allowed via `iifname "wg0"`.

```nft
#!/usr/bin/nft -f
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    iif "lo" accept
    ct state established,related accept
    ct state invalid drop
    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept

    tcp dport 22 accept
    udp dport 51820 accept
    tcp dport 51413 accept
    udp dport 51413 accept
    iifname "wg0" accept
  }

  chain forward {
    type filter hook forward priority 0; policy drop;

    ct state established,related accept
    iifname "wg0" accept
    oifname "wg0" accept
  }
}
```

**Live mismatch:** the running file still allows **51412**, while Transmission listens on **51413**. Use 51413 on a rebuild (as above) unless you change the daemon port.

Docker adds its own iptables/nft NAT tables. WireGuard `PostUp` also adds iptables MASQUERADE on `eth0`. That is expected.

```bash
systemctl enable --now nftables
```

## 4. WireGuard

Packages: `wireguard-tools`, plus userspace `wireguard-go` at `/usr/local/bin/wireguard-go` (`v0.0.20250522`).

Live overlay:

```
# /etc/systemd/system/wg-quick@wg0.service.d/override.conf
[Service]
Environment=WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go
```

Kernel `wireguard` is loaded too. Keep the overlay if you want the same userspace path.

Layout under `/etc/wireguard/` (mode `700`):

| File | Purpose |
|---|---|
| `server.key` / `server.pub` | Server keypair |
| `iphone.key` / `iphone.pub` | Phone client keypair |
| `wg0.conf` | Server interface |
| `iphone.conf` | Phone profile |

Generate **new** keys on a new VPS (or restore the old ones if you must keep existing clients):

```bash
cd /etc/wireguard
umask 077
wg genkey | tee server.key | wg pubkey > server.pub
wg genkey | tee iphone.key | wg pubkey > iphone.pub
```

Server config template (`wg0.conf`):

```ini
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = <server private key>

PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT

[Peer]
PublicKey = <iphone public key>
AllowedIPs = 10.8.0.2/32
```

Phone profile template (`iphone.conf`):

```ini
[Interface]
PrivateKey = <iphone private key>
Address = 10.8.0.2/32
DNS = 10.8.0.1

[Peer]
PublicKey = <server public key>
Endpoint = <public-ipv4>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

Live public keys (for matching existing clients, not for a clean rebuild):

- Server: `maDzapewSSiJFkFTiDQNo72cvJDG0mqdDqFMuzXw9S0=`
- iPhone peer: `jbllBxHYDBVAhf1zbYCyYqIDwMWMSyeaqfIj/wNiHW4=`

```bash
systemctl enable --now wg-quick@wg0
```

`qrencode` is installed for phone QR codes (`qrencode -t ansiutf8 < iphone.conf`).

## 5. Docker + Pi-hole

Packages: `docker`, `docker-compose`, `docker-buildx`. Enable `docker.service`. Storage: overlayfs, cgroup v2, root `/var/lib/docker`. No `/etc/docker/daemon.json`.

Live container:

- Name: `pihole`
- Image: `pihole/pihole:latest` (created 2026-07-06, FTL v6.6.2 in volume)
- `network_mode: host`
- Restart: `unless-stopped`
- Volume: `/opt/pihole/etc-pihole` → `/etc/pihole`

`/opt/pihole/docker-compose.yml`:

```yaml
services:
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    network_mode: host
    environment:
      TZ: UTC
      FTLCONF_webserver_api_password: "<generate-or-restore>"
      FTLCONF_dns_listeningMode: all
      FTLCONF_dns_upstreams: 1.1.1.1;9.9.9.9
    volumes:
      - ./etc-pihole:/etc/pihole
    restart: unless-stopped
```

The live admin password is in `/opt/pihole/.admin_password` and in that compose env. Generate a new one on rebuild; do not copy it into git.

Pi-hole settings that matter:

- Upstream DNS: `1.1.1.1`, `9.9.9.9`
- Listening mode: `ALL`
- DNS port 53
- Web: `80` and `443` (HTTP + HTTPS), path `/admin/`
- DHCP: off (the `[dhcp] active = false` service setting)
- Adlist: `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
- No custom DNS hosts

```bash
mkdir -p /opt/pihole
# write compose, set password
cd /opt/pihole && docker compose up -d
```

Admin UI from a VPN client: `https://10.8.0.1/admin/` (or HTTP on 80). From the Mac, use WireGuard or an SSH SOCKS/tunnel; it is not open on the WAN.

To copy block history/gravity, rsync `/opt/pihole/etc-pihole/` after the new container exists, then `docker compose restart`.

## 6. Transmission

Package: `transmission-cli` (daemon binary is `transmission-daemon`).

Directories (owner `roberto`):

```
/home/roberto/downloads/torrents/complete
/home/roberto/downloads/torrents/incomplete
/home/roberto/downloads/torrents/watch
/home/roberto/.config/transmission-daemon
```

Live complete dir was about **2.1 GiB** at snapshot time. Copy it with rsync if you want the same files.

Systemd unit `/etc/systemd/system/transmission-roberto.service`:

```ini
[Unit]
Description=Transmission BitTorrent Daemon for roberto
Wants=network-online.target
After=network-online.target
Documentation=man:transmission-daemon(1)

[Service]
User=roberto
Group=roberto
Environment=HOME=/home/roberto
Type=notify-reload
ExecStart=/usr/bin/transmission-daemon -f --log-level=error --config-dir /home/roberto/.config/transmission-daemon
Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=/home/roberto/.config/transmission-daemon /home/roberto/downloads/torrents
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6

[Install]
WantedBy=multi-user.target
```

Important `settings.json` values:

| Key | Value |
|---|---|
| `download-dir` | `/home/roberto/downloads/torrents/complete` |
| `incomplete-dir` | `/home/roberto/downloads/torrents/incomplete` (enabled) |
| `watch-dir` | `/home/roberto/downloads/torrents/watch` (enabled) |
| `peer-port` | `51413` (fixed, not random) |
| `rpc-bind-address` | `127.0.0.1` |
| `rpc-port` | `9091` |
| `rpc-whitelist` | `127.0.0.1,::1` (enabled) |
| `rpc-authentication-required` | `false` |
| `umask` | `002` |
| `dht-enabled` | `true` |
| `pex-enabled` | `true` |
| `port-forwarding-enabled` | `false` |
| `download-queue-size` | `5` |
| `encryption` | `1` (preferred) |

RPC has no auth because it is localhost-only. Reach it from the Mac with `vps-transmission` (SSH `-L 9091:127.0.0.1:9091`). Do not bind RPC to `0.0.0.0`.

```bash
install -d -o roberto -g roberto \
  /home/roberto/downloads/torrents/{complete,incomplete,watch} \
  /home/roberto/.config/transmission-daemon
systemctl enable --now transmission-roberto
```

## 7. Boot, disks, guests

- GRUB from `/etc/default/grub` as quoted above, then `grub-mkconfig -o /boot/grub/grub.cfg`
- mkinitcpio `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)`
- `qemu-guest-agent` active (Hostinger/QEMU)
- cloud-init units enabled on the live image; leave them if you stay on that image
- `fstrim.timer` enabled
- Pacman mirrors: `https://fastly.mirror.pkgbuild.com` and `https://geo.mirror.pkgbuild.com`

Swap on btrfs:

```bash
btrfs subvolume create /swap
btrfs filesystem mkswapfile --size 512M /swap/swapfile
echo '/swap/swapfile none swap defaults 0 0' >> /etc/fstab
swapon -a
```

## 8. Packages

### Role-required

```bash
pacman -S --needed \
  base base-devel linux btrfs-progs dosfstools efibootmgr gptfdisk grub \
  openssh sudo zsh nftables wireguard-tools qrencode \
  docker docker-compose docker-buildx \
  transmission-cli rsync git \
  qemu-guest-agent cloud-init cloud-guest-utils \
  inetutils net-tools lsof nmap tcpdump wget unzip zip 7zip \
  which less man-db man-pages
```

AUR helper on the live box: `yay 13.0.1-1` (and `yay-debug`). Only foreign packages.

### Dev workstation extras (explicitly installed on the live box)

```
age bat bash-language-server bind btop bun clang cmake deno direnv
eslint eza fastfetch fd ffmpeg fzf gcc gdb git-delta github-cli go
gradle htop jdk-openjdk jq lazygit lldb lua lua-language-server luarocks
make mariadb-clients maven nano neovim ninja nodejs npm pass pkgconf
pnpm postgresql-libs prettier protobuf pyright python-pip python-pipx
python-virtualenv ripgrep rustup shellcheck shfmt socat starship stow
strace stylua tealdeer tmux trash-cli tree tree-sitter-cli
typescript-language-server uv valkey vim yarn yq yt-dlp zoxide
zsh-autosuggestions zsh-completions zsh-history-substring-search
zsh-syntax-highlighting
```

`valkey` is installed but **disabled**. No fail2ban/ufw.

User-level tools as `roberto`:

- npm global: `@angular/cli`, `eslint`, `prettier`, `tsx`, `typescript`
- rustup: `stable-x86_64-unknown-linux-gnu`
- uv tool: `hermes-agent` v0.19.0 (`hermes`, `hermes-acp`, `hermes-agent` in `~/.local/bin`)
- bun 1.3.14 (pacman)

## 9. Shell and editor (roberto + root)

VPS zsh is **not** the Mac zinit setup. Plugins come from Arch packages.

Files to copy from the current VPS (or recreate):

| Path | Notes |
|---|---|
| `~/.zshenv` | XDG paths, `EDITOR=nvim`, PATH for local/bun/cargo/go |
| `~/.config/zsh/{zshrc,plugins.zsh,aliases.zsh,functions.zsh,prompt.zsh}` | Ghostty TERM fix, starship, fzf, zoxide, direnv |
| `~/.config/starship/starship.toml` | Same prompt as the Mac |
| `~/.tmux.conf` | mouse, 256color, reload bind |
| `~/.config/nvim/` | NvChad-style tree (same idea as this repo) |

`~/.config` on the live VPS is its own git repo with **no remote**. Treat it as local state.

Default shells: `/bin/zsh` for `root` and `roberto`.

## 10. Enabled services to turn on

Minimum for the same roles:

```bash
systemctl enable --now sshd
systemctl enable --now systemd-networkd systemd-resolved systemd-timesyncd
systemctl enable --now nftables
systemctl enable --now wg-quick@wg0
systemctl enable --now docker
systemctl enable --now transmission-roberto
systemctl enable --now qemu-guest-agent
```

Pi-hole is a Docker restart policy, not a systemd unit.

## 11. Open ports (expected)

| Port | Proto | Process | WAN (nftables) |
|---|---|---|---|
| 22 | TCP | sshd | open |
| 51820 | UDP | WireGuard | open |
| 51413 | TCP/UDP | Transmission peers | should be open; live file still has 51412 |
| 53 | TCP/UDP | pihole-FTL | VPN only |
| 80 / 443 | TCP | pihole-FTL web | VPN only |
| 9091 | TCP | Transmission RPC | localhost only |
| 123 | UDP | pihole-FTL NTP helper | VPN/localhost |

## 12. Secrets and data to move by hand

Keep these out of git. Copy from the old VPS or a password manager:

- `root` and `roberto` login passwords
- `/etc/wireguard/*.key` and client profiles (only if you want the same VPN identities)
- `/opt/pihole/.admin_password` and compose `FTLCONF_webserver_api_password`
- `/opt/pihole/etc-pihole/` if you want gravity, TLS certs, and query history
- `/home/roberto/.ssh/id_ed25519` (VPS outbound key)
- `/home/roberto/downloads/torrents/` and `~/.config/transmission-daemon/{torrents,resume,settings.json}`
- Any `pass` / GPG store if you started using `pass` on the box

## 13. Mac follow-up after a new IP

1. Update `HostName` in `~/.ssh/macbook_pro/macbook_pro_config` (and Air if needed).
2. Update WireGuard client `Endpoint`.
3. Confirm `vps`, `vps-root`, and `vps-transmission` still work.
4. Optionally set nftables Transmission ports to 51413 (see mismatch above).

## 14. Smoke test

```bash
ssh vps 'whoami; hostname'
ssh vps-root 'wg show; docker ps --format "{{.Names}} {{.Status}}"; systemctl is-active transmission-roberto nftables wg-quick@wg0'
# from a VPN client
dig @10.8.0.1 flurry.com +short    # should be blocked / 0.0.0.0
dig @10.8.0.1 example.com +short
# from the Mac
vps-transmission                   # opens http://127.0.0.1:9091/transmission/web/
```
