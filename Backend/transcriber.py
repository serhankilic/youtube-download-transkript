#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


ROOT_DIR = Path(__file__).resolve().parent.parent
OUTPUT_ROOT = ROOT_DIR / "outputs"
HF_TOKEN_ENV_KEYS = ("HF_TOKEN", "HUGGING_FACE_HUB_TOKEN")


@dataclass
class UserFacingError(Exception):
    message: str
    step: str
    detail: str

    def __str__(self) -> str:
        return self.message


def emit_stderr_event(payload: dict[str, Any]) -> None:
    sys.stderr.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stderr.flush()


def emit_status(step: str, message: str) -> None:
    emit_stderr_event({"type": "status", "step": step, "message": message})


def emit_error(step: str, message: str, detail: str) -> None:
    emit_stderr_event({"type": "error", "step": step, "message": message, "detail": detail})


def emit_stdout_result(payload: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def clean_token_value(value: str) -> str:
    return value.strip().strip("\"'")


def read_dotenv_token(env_path: Path) -> str | None:
    try:
        lines = env_path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return None

    for raw_line in lines:
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        if key.strip() in HF_TOKEN_ENV_KEYS:
            token = clean_token_value(value)
            if token:
                return token

    return None


def read_plain_token(token_path: Path) -> str | None:
    try:
        token = clean_token_value(token_path.read_text(encoding="utf-8"))
    except OSError:
        return None
    return token or None


def configure_hugging_face_token() -> None:
    existing_token = next((os.environ.get(key) for key in HF_TOKEN_ENV_KEYS if os.environ.get(key)), None)
    token = existing_token or read_dotenv_token(ROOT_DIR / ".env")

    if token is None:
        token = read_plain_token(ROOT_DIR / "hf_token")

    if token is None:
        home = Path.home()
        token = (
            read_plain_token(home / ".cache" / "huggingface" / "token")
            or read_plain_token(home / ".huggingface" / "token")
        )

    if token:
        for key in HF_TOKEN_ENV_KEYS:
            os.environ.setdefault(key, token)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download YouTube audio and create transcript files.")
    parser.add_argument("url", nargs="?", default="", help="Video URL")
    parser.add_argument("--model", default="small", help="faster-whisper model name")
    parser.add_argument("--language", default=None, help="Optional language code")
    parser.add_argument("--output-root", default=str(OUTPUT_ROOT), help="Base output directory")
    parser.add_argument("--auto-delete-audio", action="store_true", help="Accepted for client compatibility.")
    return parser.parse_args()


def ensure_output_directories(output_root: Path) -> tuple[Path, Path]:
    audio_dir = output_root / "audio"
    transcripts_dir = output_root / "transcripts"

    try:
        audio_dir.mkdir(parents=True, exist_ok=True)
        transcripts_dir.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        raise UserFacingError(
            message="Çıktı klasörleri oluşturulamadı.",
            step="checking_backend",
            detail=f"Klasör oluşturma hatası: {exc}",
        ) from exc

    return audio_dir, transcripts_dir


def validate_url(raw_url: str) -> str:
    url = raw_url.strip()
    if not url:
        raise UserFacingError(
            message="Devam etmek için bir YouTube linki yapıştırmalısın.",
            step="checking_backend",
            detail="URL boş geldi.",
        )

    if not url.startswith(("http://", "https://")):
        raise UserFacingError(
            message="Bu geçerli bir YouTube linki gibi görünmüyor.",
            step="checking_backend",
            detail=f"Geçersiz URL şeması: {url}",
        )

    parsed = urlparse(url)
    host = (parsed.netloc or "").lower()
    normalized_host = host[4:] if host.startswith("www.") else host
    allowed_normalized = {"youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"}

    if normalized_host not in allowed_normalized:
        raise UserFacingError(
            message="Bu geçerli bir YouTube linki gibi görünmüyor.",
            step="checking_backend",
            detail=f"Desteklenmeyen alan adı: {host}",
        )

    return url


def ensure_ffmpeg() -> None:
    if shutil.which("ffmpeg"):
        return

    raise UserFacingError(
        message="Ses işleme aracı ffmpeg bulunamadı. Kurulum için: brew install ffmpeg",
        step="checking_backend",
        detail="`shutil.which(\"ffmpeg\")` sonucu boş döndü.",
    )


def map_download_error(exc: Exception) -> UserFacingError:
    detail = str(exc).strip() or exc.__class__.__name__
    lower_detail = detail.lower()

    if "requested format is not available" in lower_detail:
        message = "Video sesi indirilemedi. Bu video için kullanılabilir ses formatı bulunamadı; farklı bir YouTube istemcisiyle yeniden denenecek bir güncelleme gerekebilir."
    elif "http error 403" in lower_detail or "forbidden" in lower_detail:
        message = "Video sesi indirilemedi. YouTube isteği engelledi; yt-dlp güncellemesi veya farklı bir video istemcisi gerekebilir."
    else:
        message = "Video sesi indirilemedi. Link gizli, silinmiş, yaş kısıtlı veya erişilemez olabilir."

    return UserFacingError(message=message, step="downloading_audio", detail=detail)


def map_model_error(exc: Exception, step: str) -> UserFacingError:
    detail = str(exc).strip() or exc.__class__.__name__
    if step == "loading_model":
        message = "Whisper modeli yüklenemedi. İnternet bağlantını kontrol edip tekrar dene."
    else:
        message = "Ses transkripte dönüştürülürken hata oluştu."
    return UserFacingError(message=message, step=step, detail=detail)


def map_write_error(exc: Exception, step: str) -> UserFacingError:
    detail = str(exc).strip() or exc.__class__.__name__
    message = "Çıktı dosyası kaydedilemedi. Disk alanını ve klasör izinlerini kontrol et."
    return UserFacingError(message=message, step=step, detail=detail)


def download_audio(url: str, audio_dir: Path) -> Path:
    emit_status("downloading_audio", "YouTube sesi indiriliyor...")

    try:
        from yt_dlp import YoutubeDL
    except Exception as exc:
        raise UserFacingError(
            message="Python backend kurulmamış. Lütfen önce 'Backend Kurulumu Yap' butonuna bas.",
            step="downloading_audio",
            detail=str(exc) or exc.__class__.__name__,
        ) from exc

    captured_path: Path | None = None

    def capture_postprocessor_status(status: dict[str, Any]) -> None:
        nonlocal captured_path
        filepath = status.get("info_dict", {}).get("filepath") or status.get("filename")
        if filepath:
            captured_path = Path(filepath).resolve()

    base_options = {
        "outtmpl": str(audio_dir / "%(title).120B_%(id)s.%(ext)s"),
        "restrictfilenames": True,
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "extractor_retries": 3,
        "retries": 3,
        "fragment_retries": 3,
        "skip_unavailable_fragments": True,
        "geo_bypass": True,
        "http_headers": {
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/135.0.0.0 Safari/537.36"
            )
        },
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "192",
            }
        ],
        "postprocessor_hooks": [capture_postprocessor_status],
    }

    attempt_options: list[dict[str, Any]] = [
        {
            "format": "bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio/best",
        },
        {
            "format": "bestaudio*/best*",
        },
        {
            "format": "best*",
        },
        {
            "format": "bestaudio*/best*",
            "extractor_args": {
                "youtube": {
                    "player_client": ["ios", "web", "tv_embedded"],
                }
            },
        },
        {
            "format": "best*",
            "extractor_args": {
                "youtube": {
                    "player_client": ["ios", "web", "tv_embedded"],
                }
            },
        },
    ]

    try:
        last_error: Exception | None = None
        final_path: Path | None = None

        for attempt in attempt_options:
            captured_path = None
            options = dict(base_options)
            options.update(attempt)

            try:
                with YoutubeDL(options) as ydl:
                    info = ydl.extract_info(url, download=True)
                    if captured_path and captured_path.exists():
                        final_path = captured_path
                    else:
                        prepared = Path(ydl.prepare_filename(info))
                        final_path = prepared.with_suffix(".mp3")
                break
            except Exception as exc:
                last_error = exc
                detail = str(exc).strip().lower()
                if "requested format is not available" not in detail:
                    raise

        if final_path is None:
            if last_error is not None:
                raise last_error
            raise RuntimeError("Ses indirme denemeleri başarısız oldu.")

        if not final_path.exists():
            raise FileNotFoundError(f"İndirilen ses dosyası bulunamadı: {final_path}")
    except UserFacingError:
        raise
    except Exception as exc:
        raise map_download_error(exc) from exc

    emit_status("audio_ready", "Ses dosyası hazırlandı.")
    return final_path.resolve()


def load_model(model_name: str):
    emit_status("loading_model", "Whisper modeli yükleniyor...")
    configure_hugging_face_token()

    try:
        from faster_whisper import WhisperModel
    except Exception as exc:
        raise UserFacingError(
            message="Python backend kurulmamış. Lütfen önce 'Backend Kurulumu Yap' butonuna bas.",
            step="loading_model",
            detail=str(exc) or exc.__class__.__name__,
        ) from exc

    try:
        return WhisperModel(model_name, compute_type="float32")
    except Exception as exc:
        raise map_model_error(exc, "loading_model") from exc


def transcribe_audio(model: Any, audio_path: Path, language: str | None) -> str:
    emit_status("transcribing", "Transkript oluşturuluyor...")

    try:
        segments, _info = model.transcribe(str(audio_path), language=language)
        transcript_lines: list[str] = []

        for segment in segments:
            text = (segment.text or "").strip()
            if text:
                transcript_lines.append(text)

        transcript = "\n".join(transcript_lines).strip()
        return transcript
    except Exception as exc:
        raise map_model_error(exc, "transcribing") from exc


def save_txt(transcript: str, destination: Path) -> Path:
    emit_status("saving_txt", "TXT dosyası kaydediliyor...")
    try:
        destination.write_text(transcript, encoding="utf-8")
    except OSError as exc:
        raise map_write_error(exc, "saving_txt") from exc
    return destination.resolve()


def derive_transcript_path(audio_path: Path, transcripts_dir: Path) -> Path:
    base_name = audio_path.stem[:120] or "transcript"
    return transcripts_dir / f"{base_name}.txt"


def main() -> int:
    args = parse_args()

    try:
        emit_status("checking_backend", "Backend kontrol ediliyor...")
        url = validate_url(args.url)
        ensure_ffmpeg()

        output_root = Path(args.output_root).expanduser().resolve()
        audio_dir, transcripts_dir = ensure_output_directories(output_root)

        audio_path = download_audio(url, audio_dir)
        model = load_model(args.model)
        transcript = transcribe_audio(model, audio_path, args.language)
        txt_path = derive_transcript_path(audio_path, transcripts_dir)
        saved_txt_path = save_txt(transcript, txt_path)

        emit_status("completed", "İşlem tamamlandı.")
        emit_stdout_result(
            {
                "success": True,
                "transcript": transcript,
                "txt_path": str(saved_txt_path),
                "audio_path": str(audio_path),
                "output_dir": str(output_root),
            }
        )
        return 0
    except UserFacingError as exc:
        emit_error(exc.step, exc.message, exc.detail)
        emit_stdout_result(
            {
                "success": False,
                "error": exc.message,
                "step": exc.step,
                "detail": exc.detail,
            }
        )
        return 1
    except Exception as exc:
        fallback = UserFacingError(
            message="Beklenmeyen bir hata oluştu. Teknik detayları kontrol edip tekrar dene.",
            step="checking_backend",
            detail=str(exc) or exc.__class__.__name__,
        )
        emit_error(fallback.step, fallback.message, fallback.detail)
        emit_stdout_result(
            {
                "success": False,
                "error": fallback.message,
                "step": fallback.step,
                "detail": fallback.detail,
            }
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
