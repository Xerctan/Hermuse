# Changelog

Semua perubahan penting di repo ini dicatat di sini, format ala Keep a Changelog.

## Kandidat update berikutnya
- Script autopanen: panen endpoint AI gratisan (OpenAI-compatible) secara berkala dan daftarkan otomatis sebagai provider 9Router. Arsitektur routing: **hasil panen sebagai jalur utama, Nous sebagai fallback** (kebalik dari asumsi awal).
- `hermuse-doctor`: script cek kesehatan all-in-one.
- Installer satu baris.

## [Unreleased]

### Ditambahkan
- `LICENSE` (MIT) — repo publik akhirnya punya lisensi biar orang berani fork/kontribusi.
- `scripts/start-all.sh` — starter idempoten semua komponen Hermuse (9Router, tunnel client, Telegram gateway); yang sudah jalan nggak disentuh. Siap dipanggil dari `@reboot` cron / systemd.
- Section "Auto-start" di README — contoh `@reboot` cron dan systemd user unit.
- `CHANGELOG.md` ini sendiri.

### Diperbaiki
- README: diagram arsitektur "polling tiap ~400ms" → "long-poll ~20 detik", plus paragraf penjelasan kenapa long-poll ada (hemat jatah 100k request/hari Workers free tier).
- README: verifikasi `curl /dashboard` "harus 200" → "harus 200/307" (9Router balikin 307 redirect ke login, itu normal).
- `scripts/install.sh`: 9Router diinstall ke `$HOME/.npm-global` (konsisten sama PATH di script lain, aman tanpa root) + PATH dipersisten ke `~/.bashrc`.
- `scripts/install.sh`: flag manual `9router` disamakan dengan `start-9router.sh` (tambah `-l`).
- `restart-tunnel.sh`: pola kill dipersempit jadi exact `tunnel-client[.]mjs` — nggak ikut ngebunuh tunnel client lain di setup multi-tunnel.
- `tunnel-client.mjs`: komentar `TUNNEL_POLL_MS` diperjelas (sejak long-poll, ini cuma jeda tambahan antar long-poll, bukan interval polling utama).
- `watchdog.sh`: pola `pgrep` di-escape (`tunnel-client[.]mjs`) biar exact.
- `.gitignore`: tambah pola `.tunnel-key*` (varian key multi-tunnel nggak lolos ke-commit).
