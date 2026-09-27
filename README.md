# Tutorial: Hermes Agent + 9Router + Telegram Gateway di VPS

Panduan instalasi **Hermes Agent** (AI agent dari Nous Research) + **9Router** (model gateway/router) + **Telegram gateway** di VPS Linux milik sendiri, dalam Bahasa Indonesia.

Tutorial ini ditulis berdasarkan setup yang sudah berjalan dan terverifikasi di sebuah VM Linux. Semua langkah di bawah sudah dipraktikkan — termasuk bagian *keterbatasan* di mana kami jujur soal apa yang gagal.

```
Telegram (kamu) ──▶ Hermes Gateway ──▶ Model
                                        ├─▶ Nous (langsung, via OAuth/API key)
                                        └─▶ 9Router (127.0.0.1:20128, OpenAI-compatible)
```

---

## 1. Syarat VPS

| Kebutuhan | Minimum | Rekomendasi |
|---|---|---|
| OS | Linux x86_64 (Ubuntu/Debian) | Ubuntu 22.04 / 24.04 LTS |
| CPU | 1 vCPU | 2 vCPU |
| RAM | 2 GB | 4 GB |
| Disk | 10 GB bebas | 20 GB bebas |
| Jaringan | IPv4 publik (untuk SSH; inbound tidak wajib) | — |

Hermes sendiri ringan (CLI + gateway). Yang memakan RAM/disk adalah dependensi opsional (browser/Chromium bila dipasang). Setup referensi kami berjalan di 2 vCPU / 7,7 GB RAM / 7,5 GB disk.

> Catatan: kamu **tidak** butuh IP publik yang bisa diakses dari internet untuk Telegram gateway — gateway memakai *polling* ke server Telegram (koneksi keluar), bukan menerima koneksi masuk.

---

## 2. Install Hermes Agent

Installer resmi dari Nous Research:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

Prasyarat: `git`, `curl`, `tar`, dan utilitas SHA-256 (biasanya sudah ada di Ubuntu/Debian; kalau belum: `sudo apt install -y git curl tar`).

Installer akan mengurus Python 3.14, Node.js, npm, ripgrep, dan FFmpeg sendiri. Browser/Chromium ikut terpasang secara default; lewati dengan `--skip-browser` bila tidak butuh:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser
```

Verifikasi instalasi:

```bash
hermes doctor
```

Semua cek harus hijau. Kalau `hermes: command not found` setelah install, jalankan `source ~/.bashrc` (atau buka terminal baru).

> Atau jalankan `scripts/install.sh` di repo ini untuk instalasi otomatis (Hermes + Node.js + 9Router).

---

## 3. Setup Provider Model

### Opsi A — Nous (direkomendasikan untuk mulai)

Login via OAuth (satu akun mencakup ratusan model):

```bash
hermes setup --portal
```

Ikuti alur login di browser. Alternatif: API key statis dari Nous Portal, lalu:

```bash
hermes model
```

Pilih provider `nous` dan model yang diinginkan (mis. model gratis bertanda `:free` bila tersedia di akunmu).

Cek cepat:

```bash
hermes -p "jawab singkat: 7 dikali 8 berapa?"
```

### Opsi B — via 9Router (lihat bagian 4)

---

## 4. Install & Konfigurasi 9Router

9Router adalah model gateway (paket npm) yang berjalan lokal dan menyediakan endpoint OpenAI-compatible. Install:

```bash
npm install -g 9router
```

Jalankan (bind ke localhost saja):

```bash
9router -p 20128 -H 127.0.0.1 -n --skip-update
```

Flag yang dipakai:
- `-p 20128` — port (default 20128)
- `-H 127.0.0.1` — hanya dengar di localhost (jangan expose ke internet tanpa proteksi)
- `-n` — jangan buka browser otomatis
- `--skip-update` — lewati cek update otomatis

Dashboard: buka `http://127.0.0.1:20128` di browser (via SSH tunnel bila VPS remote: `ssh -L 20128:127.0.0.1:20128 user@vps`).

Agar Hermes memakai 9Router, daftarkan sebagai **custom provider** di `~/.hermes/config.yaml`:

```yaml
model:
  provider: "custom"
  base_url: "http://127.0.0.1:20128/v1"
  api_key: "ISI_CLIENT_KEY_9ROUTER_DI_SINI"
```

(Client key dibuat/dilihat di dashboard 9Router.) Atau via wizard:

```bash
hermes model
```

Pilih tambah provider custom → base URL `http://127.0.0.1:20128/v1` → pilih model yang tersedia di 9Router.

**Penting:** koneksikan akun provider (Anthropic/Google/dll) di dashboard 9Router dulu — tanpa itu request model gagal dengan error `No active credentials for provider`. Dan **ganti password dashboard 9Router dari default** segera setelah install.

> Kami awalnya memakai pola ini, lalu beralih ke provider `nous` langsung. Keduanya valid — pilih yang paling stabil di tempatmu.

---

## 4b. (Opsional tapi direkomendasikan) Cloudflare Polling Tunnel — akses dashboard 9Router dari internet

### Kenapa tunnel ini ada

9Router hanya di-bind ke `127.0.0.1` (aman), tapi kadang kamu butuh buka dashboard-nya dari HP/browser di luar VPS. Cara normal: **Cloudflare Tunnel (`cloudflared`)**. Masalahnya, di jaringan tertentu `cloudflared` **gagal total**:

- UDP/QUIC diblokir → transport QUIC mati.
- Koneksi TLS langsung ke IP edge Cloudflare di-intercept (MITM) → handshake edge gagal.
- WebSocket juga diblokir.

(Tailscale gagal dengan alasan serupa: control plane-nya tidak lolos MITM.)

Solusinya: **tunnel polling via HTTPS murni** — tanpa WebSocket, tanpa QUIC, tanpa koneksi edge khusus. Hanya `fetch()` biasa yang lolos di hampir semua jaringan. Arsitekturnya:

```
Browser (internet)
   │ HTTPS biasa
   ▼
Cloudflare Pages Functions (<project>.pages.dev)
   │ antrean request/response
   ▼
D1 database (tabel tunnel_requests / tunnel_responses)
   ▲ polling HTTPS tiap ~400ms (dari VPS)
   │
tunnel-client.mjs (di VPS)
   │ forward
   ▼
9Router di 127.0.0.1:20128
```

Alur satu request:
1. Browser buka `https://<project>.pages.dev/dashboard`.
2. Function `[[path]].js` menyimpan request ke D1 (`tunnel_requests`, status `pending`), lalu menunggu maksimal 25 detik.
3. `tunnel-client.mjs` di VPS mem-poll `__tunnel/poll`, mengambil request antre, meneruskannya ke 9Router lokal, lalu POST hasilnya ke `__tunnel/respond`.
4. Function melihat response di D1 dan mengembalikannya ke browser. Latensi tipikal ~1 detik.

Keamanan: setiap panggilan `__tunnel/*` wajib menyertakan `TUNNEL_KEY` yang cocok dengan Pages secret — tanpa itu ditolak 403. Key dibuat dengan `openssl rand -hex 32`, disimpan sebagai Pages secret **dan** file `~/.tunnel-key` (600) di VPS. Jangan pernah commit key ini.

### Setup langkah-demi-langkah

**Di Cloudflare (butuh API token — dipakai transient, tidak disimpan):**

```bash
# 1. Install wrangler bila belum ada
npm install -g wrangler

# 2. Jalankan setup otomatis (dari root repo ini)
CLOUDFLARE_API_TOKEN='token_kamu' bash scripts/setup-tunnel.sh 9router-tunnel-kamu tunnel-9router
```

Script itu melakukan: generate key → buat D1 → terapkan `tunnel/schema.sql` → buat `wrangler.toml` → set `TUNNEL_KEY` sebagai Pages secret → deploy Functions. Kalau mau manual, langkahnya sama (lihat `scripts/setup-tunnel.sh` sebagai referensi perintah).

**Di VPS:**

```bash
# 1. Pastikan 9Router jalan di 127.0.0.1:20128 (lihat bagian 4)

# 2. Jalankan tunnel client (contoh systemd unit di bawah)
TUNNEL_BASE_URL=https://9router-tunnel-kamu.pages.dev \
TUNNEL_KEY_FILE=$HOME/.tunnel-key \
node tunnel/tunnel-client.mjs
```

Contoh `/etc/systemd/system/tunnel-client.service`:

```ini
[Unit]
Description=Cloudflare polling tunnel client (9Router)
After=network.target 9router.service

[Service]
Type=simple
User=hermes
Environment=TUNNEL_BASE_URL=https://9router-tunnel-kamu.pages.dev
Environment=TUNNEL_KEY_FILE=/home/hermes/.tunnel-key
ExecStart=/usr/bin/node /home/hermes/hermes-9router-tutorial/tunnel/tunnel-client.mjs
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tunnel-client
```

**Verifikasi:** buka `https://<project>.pages.dev` di browser — harusnya dashboard 9Router muncul. Kalau dapat `504 tunnel timeout (client offline?)`, berarti tunnel client di VPS belum jalan.

**Kapan kamu TIDAK butuh ini:** kalau `cloudflared` bisa jalan normal di VPS-mu (VPS sungguhan biasanya bisa), pakai Cloudflare Tunnel biasa saja — lebih sederhana dan lebih cepat:

```bash
cloudflared tunnel login
cloudflared tunnel create 9router
cloudflared tunnel route dns 9router 9router.<domainmu>
cloudflared tunnel run --url http://127.0.0.1:20128 9router
```

---

## 5. Setup Telegram Gateway

### 5.1. Buat bot

1. Chat ke [@BotFather](https://t.me/BotFather) di Telegram → `/newbot`.
2. Isi nama tampilan + username (harus berakhiran `bot`).
3. Simpan **token bot** yang diberikan. Kalau bocor, `/revoke` di BotFather.

### 5.2. Dapatkan numeric Telegram ID milikmu

Chat ke [@userinfobot](https://t.me/userinfobot) — catat angka ID-nya (bukan username).

### 5.3. Konfigurasi Hermes

Cara mudah (wizard interaktif):

```bash
hermes gateway setup
```

Atau manual — buat file `~/.hermes/.env` (permission 600!):

```bash
mkdir -p ~/.hermes
cat > ~/.hermes/.env << 'EOF'
TELEGRAM_BOT_TOKEN=isi_token_bot_kamu_di_sini
TELEGRAM_ALLOWED_USERS=isi_numeric_id_kamu_di_sini
EOF
chmod 600 ~/.hermes/.env
```

Prinsip keamanan: **default-deny**. Hanya ID di `TELEGRAM_ALLOWED_USERS` yang bisa memakai bot. Jangan pernah set `GATEWAY_ALLOW_ALL_USERS=true` di bot yang punya akses terminal.

### 5.4. Jalankan gateway

```bash
hermes gateway run
```

Tunggu tulisan `Connected to Telegram (polling mode)`, lalu chat bot-mu di Telegram untuk verifikasi.

---

## 6. Autostart + Watchdog

### 6.1. Service resmi Hermes (disarankan)

```bash
hermes gateway install          # user service (butuh login session)
sudo hermes gateway install --system   # system service (jalan saat boot)
sudo loginctl enable-linger $USER      # agar user service tetap jalan setelah logout
```

Untuk 9Router, buat systemd unit sendiri, contoh `/etc/systemd/system/9router.service`:

```ini
[Unit]
Description=9Router model gateway
After=network.target

[Service]
Type=simple
User=hermes
ExecStart=/usr/local/bin/9router -p 20128 -H 127.0.0.1 -n --skip-update
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now 9router
```

### 6.2. Watchdog sederhana (alternatif tanpa systemd)

`scripts/watchdog.sh` di repo ini mengecek 9Router, gateway Telegram, lalu me-restart yang mati. Jalankan tiap 5 menit via cron:

```bash
crontab -e
# tambahkan:
*/5 * * * * /path/ke/scripts/watchdog.sh >> ~/.hermes/watchdog.log 2>&1
```

Sesuaikan variabel di bagian atas `watchdog.sh` (port, nama proses, perintah start) dengan setup-mu.

---

## 7. Troubleshooting Umum

| Gejala | Kemungkinan penyebab / solusi |
|---|---|
| `hermes: command not found` | `source ~/.bashrc` atau buka terminal baru |
| `hermes doctor` ada yang merah | Ikuti saran per-baris; biasanya dependensi (`hermes pm install`) |
| Gateway tidak connect ke Telegram | Cek token bot; pastikan jam server benar; cek log gateway |
| Bot tidak merespons | Pastikan numeric ID-mu benar di `TELEGRAM_ALLOWED_USERS`; kirim `/whoami` |
| 9Router tidak bisa diakses | Cek `9router` jalan (`curl 127.0.0.1:20128`); cek firewall VPS |
| Model error 401/402 | Kredensial provider kedaluwarsa — ulangi `hermes setup --portal` atau perbarui API key |
| Service mati setelah reboot | Pastikan `systemctl enable` / `loginctl enable-linger` sudah dijalankan |

---

## 8. Keterbatasan yang Kami Temui (jujur)

Setup referensi berjalan di VM sandbox dengan keterbatasan jaringan. Ini yang **gagal** di sana dan perlu kamu tahu:

- **Tailscale tidak bisa connect.** Control plane Tailscale gagal menembus jaringan sandbox (koneksi tersadap/di-MITM). Di VPS normal biasanya fine.
- **Cloudflare Tunnel (`cloudflared`) gagal.** Konektor tidak bisa membangun koneksi edge — QUIC/UDP diblokir dan TLS langsung ke IP edge Cloudflare di-intercept. Solusi kami: tunnel polling kustom via HTTPS biasa (Pages Functions + D1 sebagai antrean). Di VPS normal, `cloudflared` umumnya bekerja.
- **Tidak ada IP publik / inbound langsung.** Itu sebabnya Telegram gateway memakai polling (koneksi keluar) — dan itu memang cara yang didukung, jadi bukan masalah.
- **VM kecil (2 vCPU).** Cukup untuk Hermes + 9Router + gateway, tapi jangan harapkan inference lokal yang berat.

Intinya: di VPS sungguhan (DigitalOcean, Hetzner, Contabo, dsb.) langkah-langkah di atas berjalan lebih mulus daripada di sandbox kami.

---

## 9. Keamanan — Jangan Dilewatkan

- File `.env` berisi token → selalu `chmod 600`, jangan commit ke git (sudah ada di `.gitignore`).
- Allowlist Telegram: hanya ID-mu. Default-deny.
- Jangan expose dashboard 9Router (port 20128) ke internet tanpa autentikasi/reverse proxy.
- Kalau token bot bocor: segera `/revoke` di @BotFather dan ganti di `.env`.

---

## Struktur Repo

```
hermes-9router-tutorial/
├── README.md                    # tutorial ini
├── scripts/
│   ├── install.sh               # install otomatis: prereq + Hermes + Node + 9Router
│   ├── setup-tunnel.sh          # setup tunnel: D1 + secret + deploy Pages
│   └── watchdog.sh              # watchdog cron: restart 9Router/gateway yang mati
├── tunnel/
│   ├── tunnel-client.mjs         # client polling di VPS (HTTPS murni)
│   ├── schema.sql                 # skema D1 (tunnel_requests / tunnel_responses)
│   └── pages-tunnel/
│       ├── wrangler.toml.example  # template (isi nama project + D1 id sendiri)
│       └── functions/
│           ├── [[path]].js        # catch-all: browser -> antrean D1 -> tunggu response
│           └── __tunnel/
│               ├── poll.js        # client ambil request antre (auth TUNNEL_KEY)
│               └── respond.js     # client kirim response balik
└── .gitignore                   # .env, log, node_modules, .tunnel-key, dsb.
```

Referensi resmi: installer `https://hermes-agent.nousresearch.com/install.sh`, repo `https://github.com/NousResearch/hermes-agent`, dan dokumentasi di `https://hermes-agent.nousresearch.com/docs/`.
