# youtube-download-transkript

LocalTranscript, YouTube bağlantısından ses indirip `faster-whisper` ile TXT ve SRT transkript çıktısı üretir.

## Kurulum

Önce sistem araçlarını Homebrew ile kur:

```bash
brew install python@3.14 ffmpeg hf
```

Hugging Face hesabınla giriş yap:

```bash
hf auth login
```

Token'ın doğru kaydedildiğini kontrol etmek için:

```bash
hf auth whoami
```

Uygulamanın sandbox dışı Python süreci token'ı doğrudan bulabilsin diye token'ı lokal uygulama env dosyasına kopyala:

```bash
mkdir -p "$HOME/Library/Application Support/LocalTranscript"
printf 'HF_TOKEN=%s\n' "$(cat "$HOME/.cache/huggingface/token")" > "$HOME/Library/Application Support/LocalTranscript/.env"
chmod 600 "$HOME/Library/Application Support/LocalTranscript/.env"
```

Sonra uygulamayı çalıştır:

```bash
swift run
```

Uygulama açılınca ilk çalıştırmada **Backend Kurulumu** butonuna bas. Bu adım uygulamanın kendi Python sanal ortamını oluşturur ve `Backend/requirements.txt` içindeki paketleri indirir:

- `yt-dlp`
- `faster-whisper`

Bu indirmeler tamamlandıktan sonra YouTube linkini yapıştırıp transkript oluşturabilirsin.

## Hugging Face token kaynakları

Whisper modelleri Hugging Face Hub üzerinden indirildiği için daha yüksek limitler ve daha hızlı indirme için token tanımlayabilirsin.

Uygulama token'ı şu kaynaklardan otomatik okur:

- `HF_TOKEN` veya `HUGGING_FACE_HUB_TOKEN` ortam değişkeni
- Uygulama veri klasöründeki `.env` dosyası: `~/Library/Application Support/LocalTranscript/.env`
- Uygulama veri klasöründeki `hf_token` dosyası: `~/Library/Application Support/LocalTranscript/hf_token`
- Hugging Face CLI'ın standart token dosyaları: `~/.cache/huggingface/token` veya `~/.huggingface/token`

Token'ı repoya koyma; `.env` ve `hf_token` git dışında bırakılır.
