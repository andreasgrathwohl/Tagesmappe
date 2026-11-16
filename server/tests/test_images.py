import io

import pytest
from PIL import Image, ImageCms, PngImagePlugin

from frontstage_service.images import MAX_IMAGE_BYTES, ImageRejected, clean_image


def _make(fmt: str, size=(40, 20), exif=None) -> bytes:
    buf = io.BytesIO()
    img = Image.new("RGB", size, (200, 30, 30))
    kwargs = {"exif": exif} if exif is not None else {}
    img.save(buf, format=fmt, **kwargs)
    return buf.getvalue()


def test_png_and_jpeg_accepted_and_reencoded():
    png, ext = clean_image(_make("PNG"))
    assert ext == "png" and png.startswith(b"\x89PNG")
    jpg, ext = clean_image(_make("JPEG"))
    assert ext == "jpg" and jpg.startswith(b"\xff\xd8")


def test_strips_exif_gps():
    exif = Image.Exif()
    exif[0x010F] = "Kamera"
    exif.get_ifd(0x8825)[1] = "N"  # GPS-IFD
    data = _make("JPEG", exif=exif.tobytes())
    assert len(Image.open(io.BytesIO(data)).getexif()) > 0
    cleaned, _ = clean_image(data)
    assert len(Image.open(io.BytesIO(cleaned)).getexif()) == 0


def _icc_bytes() -> bytes:
    return ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()


@pytest.mark.parametrize("fmt", ["PNG", "JPEG"])
def test_strips_icc_profile(fmt):
    buf = io.BytesIO()
    Image.new("RGB", (40, 20), (200, 30, 30)).save(buf, format=fmt, icc_profile=_icc_bytes())
    assert Image.open(io.BytesIO(buf.getvalue())).info.get("icc_profile")
    cleaned, _ = clean_image(buf.getvalue())
    assert not Image.open(io.BytesIO(cleaned)).info.get("icc_profile")


def test_strips_jpeg_comment():
    buf = io.BytesIO()
    Image.new("RGB", (40, 20), (200, 30, 30)).save(buf, format="JPEG", comment=b"Klasse 8b, Raum 12")
    assert Image.open(io.BytesIO(buf.getvalue())).info.get("comment")
    cleaned, _ = clean_image(buf.getvalue())
    assert b"Klasse 8b" not in cleaned
    assert not Image.open(io.BytesIO(cleaned)).info.get("comment")


def test_strips_png_text_chunks_but_keeps_palette_transparency():
    info = PngImagePlugin.PngInfo()
    info.add_text("Comment", "Klasse 8b")
    image = Image.new("P", (8, 8), 0)
    image.putpalette([255, 0, 0, 0, 255, 0] + [0] * 762)
    buf = io.BytesIO()
    image.save(buf, format="PNG", pnginfo=info, transparency=0)
    cleaned, _ = clean_image(buf.getvalue())
    assert b"Klasse 8b" not in cleaned
    result = Image.open(io.BytesIO(cleaned))
    assert result.info.get("transparency") == 0


def test_applies_orientation():
    exif = Image.Exif()
    exif[0x0112] = 6
    cleaned, _ = clean_image(_make("JPEG", size=(40, 20), exif=exif.tobytes()))
    assert Image.open(io.BytesIO(cleaned)).size == (20, 40)


def test_rejects_disguised_file():
    with pytest.raises(ImageRejected) as e:
        clean_image(b"%PDF-1.7 not an image")
    assert e.value.status_code == 415


def test_rejects_gif_and_webp():
    for fmt in ("GIF", "WEBP"):
        with pytest.raises(ImageRejected) as e:
            clean_image(_make(fmt))
        assert e.value.status_code == 415


def test_rejects_over_8_mib():
    with pytest.raises(ImageRejected) as e:
        clean_image(b"\x89PNG" + b"0" * MAX_IMAGE_BYTES)
    assert e.value.status_code == 413


def test_rejects_corrupt_image():
    data = _make("PNG")
    with pytest.raises(ImageRejected) as e:
        clean_image(data[:40])
    assert e.value.status_code == 415


def test_rejects_decompression_bomb():
    buf = io.BytesIO()
    Image.new("L", (10000, 10000), 0).save(buf, format="PNG", optimize=True)
    assert len(buf.getvalue()) < MAX_IMAGE_BYTES
    with pytest.raises(ImageRejected) as e:
        clean_image(buf.getvalue())
    assert e.value.status_code == 413
