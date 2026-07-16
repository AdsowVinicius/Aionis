#!/usr/bin/env python3
"""Worker de OCR do Aionis — OpenCV + Tesseract.

Pipeline (obrigatório, nesta ordem):
    Imagem/PDF -> OpenCV -> Deskew -> Noise Removal -> Contrast -> Threshold
              -> Tesseract OCR

Entrada (argumentos):
    --file          caminho do arquivo (PDF/PNG/JPG/JPEG)
    --content-type  ex.: image/png, application/pdf
    --lang          idioma do Tesseract (default: por)
    --dpi           DPI de rasterização do PDF (default: 200)

Saída: JSON em stdout.
    sucesso  -> {"text": "...", "confidence": 0..100, "pages": N, "words": N}
    erro     -> {"error": "...", "error_type": "dependency|processing"}

Exit codes:
    0 sucesso · 3 dependência ausente (provider trata como indisponível)
    outro nonzero = erro de processamento
"""

import argparse
import json
import sys


def _fail(message, error_type, code):
    json.dump({"error": str(message), "error_type": error_type}, sys.stdout)
    sys.exit(code)


def load_images(path, content_type, dpi):
    """Retorna lista de imagens OpenCV (BGR). PDF é rasterizado por página."""
    import numpy as np  # noqa: WPS433 (import tardio para isolar dependências)
    import cv2

    is_pdf = (content_type or "").lower() == "application/pdf" or path.lower().endswith(".pdf")

    if not is_pdf:
        img = cv2.imread(path, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Não foi possível ler a imagem")
        return [img]

    # PDF -> imagens (PyMuPDF)
    import fitz  # PyMuPDF

    images = []
    zoom = dpi / 72.0
    matrix = fitz.Matrix(zoom, zoom)
    with fitz.open(path) as doc:
        for page in doc:
            pix = page.get_pixmap(matrix=matrix)
            buf = np.frombuffer(pix.samples, dtype=np.uint8)
            arr = buf.reshape(pix.height, pix.width, pix.n)
            if pix.n == 4:
                arr = cv2.cvtColor(arr, cv2.COLOR_RGBA2BGR)
            elif pix.n == 3:
                arr = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
            else:
                arr = cv2.cvtColor(arr, cv2.COLOR_GRAY2BGR)
            images.append(arr)
    return images


def deskew(gray):
    """Corrige a inclinação do texto (deskew) via minAreaRect dos pixels escuros."""
    import numpy as np
    import cv2

    inverted = cv2.bitwise_not(gray)
    coords = np.column_stack(np.where(inverted > 0))
    if coords.shape[0] == 0:
        return gray

    angle = cv2.minAreaRect(coords)[-1]
    if angle < -45:
        angle = 90 + angle
    if abs(angle) < 0.5:
        return gray

    (h, w) = gray.shape[:2]
    matrix = cv2.getRotationMatrix2D((w / 2, h / 2), angle, 1.0)
    return cv2.warpAffine(
        gray, matrix, (w, h),
        flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE,
    )


def preprocess(img):
    """OpenCV: grayscale -> deskew -> noise removal -> contrast -> threshold."""
    import cv2

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)      # grayscale
    gray = deskew(gray)                                # deskew
    gray = cv2.fastNlMeansDenoising(gray, h=10)        # noise removal
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)                           # contrast
    _, thresh = cv2.threshold(                         # threshold
        gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU,
    )
    return thresh


def ocr_image(image, lang):
    """Roda o Tesseract e devolve (texto, confiança_média, num_palavras)."""
    import pytesseract
    from pytesseract import Output

    text = pytesseract.image_to_string(image, lang=lang)
    data = pytesseract.image_to_data(image, lang=lang, output_type=Output.DICT)

    confs = [int(c) for c in data.get("conf", []) if str(c).lstrip("-").isdigit() and int(c) >= 0]
    words = [w for w in data.get("text", []) if str(w).strip()]
    avg_conf = round(sum(confs) / len(confs)) if confs else 0
    return text, avg_conf, len(words)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True)
    parser.add_argument("--content-type", default="")
    parser.add_argument("--lang", default="por")
    parser.add_argument("--dpi", type=int, default=200)
    args = parser.parse_args()

    try:
        images = load_images(args.file, args.content_type, args.dpi)
    except ImportError as exc:
        _fail(exc, "dependency", 3)
    except Exception as exc:  # noqa: BLE001
        _fail(exc, "processing", 1)

    try:
        texts = []
        confs = []
        total_words = 0
        for image in images:
            processed = preprocess(image)
            text, conf, nwords = ocr_image(processed, args.lang)
            texts.append(text)
            total_words += nwords
            if nwords > 0:
                confs.append(conf)

        json.dump({
            "text": "\n\n".join(t.strip() for t in texts).strip(),
            "confidence": round(sum(confs) / len(confs)) if confs else 0,
            "pages": len(images),
            "words": total_words,
        }, sys.stdout)
    except ImportError as exc:
        _fail(exc, "dependency", 3)
    except Exception as exc:  # noqa: BLE001
        _fail(exc, "processing", 1)


if __name__ == "__main__":
    main()
