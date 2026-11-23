"""Gera logotipo e ícones PROVISÓRIOS do DCL Remoto a partir de formas simples.

Uso (na raiz do repositório):  python res/produto/gerar_icones.py
Requer Pillow e as fontes Segoe UI do Windows. Para trocar pela arte definitiva, substitua
os arquivos gerados (lista em ALVOS) ou ajuste este script e rode de novo.
"""
import os
from PIL import Image, ImageDraw, ImageFont

AZUL = (14, 92, 168, 255)        # cor primária
AZUL_ESCURO = (8, 56, 110, 255)
BRANCO = (255, 255, 255, 255)
VERDE = (25, 179, 107, 255)      # destaque (ponto de "conectado")
FONTE_B = r"C:\Windows\Fonts\segoeuib.ttf"
FONTE = r"C:\Windows\Fonts\segoeui.ttf"

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def caminho(*p):
    return os.path.join(RAIZ, *p)


def icone(tam=1024):
    """Quadrado arredondado azul com um monitor branco e o texto DCL."""
    im = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = tam * 0.22
    d.rounded_rectangle([0, 0, tam - 1, tam - 1], radius=r, fill=AZUL)
    # monitor
    m = tam * 0.16
    topo, base = tam * 0.20, tam * 0.66
    d.rounded_rectangle([m, topo, tam - m, base], radius=tam * 0.05,
                        outline=BRANCO, width=max(2, int(tam * 0.05)))
    # pé do monitor
    d.rectangle([tam * 0.44, base, tam * 0.56, tam * 0.75], fill=BRANCO)
    d.rounded_rectangle([tam * 0.32, tam * 0.74, tam * 0.68, tam * 0.80],
                        radius=tam * 0.02, fill=BRANCO)
    # texto DCL dentro da tela
    f = ImageFont.truetype(FONTE_B, int(tam * 0.22))
    txt = "DCL"
    bb = d.textbbox((0, 0), txt, font=f)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((tam - w) / 2 - bb[0], (topo + base) / 2 - h / 2 - bb[1]), txt, font=f, fill=BRANCO)
    # ponto verde (conexão ativa)
    c, rr = tam * 0.80, tam * 0.085
    d.ellipse([c - rr, tam * 0.13 - rr + rr, c + rr, tam * 0.13 + rr + rr], fill=VERDE,
              outline=AZUL, width=max(1, int(tam * 0.02)))
    return im


def logo(larg=600, alt=120, cor1=AZUL, cor2=AZUL_ESCURO):
    """Logo horizontal 2x (a tela inicial limita a 300x60)."""
    im = Image.new("RGBA", (larg, alt), (0, 0, 0, 0))
    ic = icone(alt).resize((alt, alt), Image.LANCZOS)
    im.alpha_composite(ic, (0, 0))
    d = ImageDraw.Draw(im)
    fb = ImageFont.truetype(FONTE_B, int(alt * 0.52))
    fr = ImageFont.truetype(FONTE, int(alt * 0.52))
    x = alt + int(alt * 0.18)
    y = alt * 0.5
    d.text((x, y), "DCL", font=fb, fill=cor1, anchor="lm")
    x += d.textlength("DCL ", font=fb)
    d.text((x, y), "Remoto", font=fr, fill=cor2, anchor="lm")
    return im


def salvar_ico(im, destino, tamanhos):
    im.save(destino, format="ICO", sizes=[(t, t) for t in tamanhos])


def main():
    base = icone(1024)
    base.save(caminho("res", "icon.png"))
    base.save(caminho("flutter", "assets", "icon.png"))
    for t, nome in [(32, "32x32.png"), (64, "64x64.png"), (128, "128x128.png"), (256, "128x128@2x.png")]:
        base.resize((t, t), Image.LANCZOS).save(caminho("res", nome))
    todos = [16, 24, 32, 48, 64, 128, 256]
    salvar_ico(base, caminho("res", "icon.ico"), todos)
    salvar_ico(base, caminho("flutter", "windows", "runner", "resources", "app_icon.ico"), todos)
    salvar_ico(base, caminho("flutter", "assets", "icon.ico"), todos)
    salvar_ico(base, caminho("res", "tray-icon.ico"), [16, 24, 32])
    lg = logo()
    lg.save(caminho("flutter", "assets", "logo.png"))
    logo(cor1=BRANCO, cor2=(200, 222, 245, 255)).save(caminho("flutter", "assets", "logo_dark.png"))
    # SVG de reserva (usado só se icon.png faltar)
    with open(caminho("flutter", "assets", "icon.svg"), "w", encoding="utf-8") as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
                '<rect width="100" height="100" rx="22" fill="#0E5CA8"/>'
                '<rect x="16" y="20" width="68" height="46" rx="5" fill="none" stroke="#fff" stroke-width="5"/>'
                '<rect x="44" y="66" width="12" height="9" fill="#fff"/>'
                '<rect x="32" y="74" width="36" height="6" rx="2" fill="#fff"/>'
                '<text x="50" y="50" font-family="Segoe UI,Arial" font-weight="700" font-size="22" '
                'fill="#fff" text-anchor="middle">DCL</text></svg>')
    print("ícones e logo gerados")


if __name__ == "__main__":
    main()
