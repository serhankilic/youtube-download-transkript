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

## `Subly.app` ve DMG olarak paketleme

Bu repo hızlı dağıtım için gerçek bir macOS `.app` bundle ve isteğe bağlı DMG üretebilir. Bu paketleme yöntemi uygulamayı çift tıklanabilir hale getirir, ama hedef Mac'te aşağıdaki sistem araçları yine kurulu olmalıdır:

```bash
brew install python@3.14 ffmpeg hf
hf auth login
```

Kaynak kodu indiren kişinin bilmesi gereken kritik nokta:

- GitHub'daki `Code > Download ZIP` sadece kaynak kodu indirir.
- `Subly.app` ve `Subly.dmg` kaynak dosya olarak repoda tutulmaz; build sırasında `dist/` içine üretilir.
- Son kullanıcıya verilecek tıklanabilir paket için GitHub `Releases` altındaki artifact veya release asset indirilmelidir.

`.app` üretmek için:

```bash
./scripts/build-macos-app.sh
```

Çıktı:

```text
dist/Subly.app
```

DMG üretmek için:

```bash
./scripts/build-dmg.sh
```

Çıktı:

```text
dist/Subly.dmg
```

Dağıtım notları:

- Hedef kullanıcı `.app` dosyasını `Applications` klasörüne sürükleyip açabilir.
- Uygulama ilk kullanımda yine kendi backend sanal ortamını kurar.
- Bu hızlı paketleme akışı notarization içermez; başka bir Mac'te ilk açılışta Gatekeeper uyarısı görülebilir. Gerekirse uygulamayı sağ tıklayıp `Open` ile başlatmak gerekir.
- Repo artık `.github/workflows/macos-release.yml` ile manuel veya tag üzerinden macOS build artifact üretmek için hazırdır.
