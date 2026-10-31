"""Build the one-page and two-page Smart Kiosk feature PDFs."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

DOCS = Path(__file__).resolve().parent
LOGO = DOCS / "image.png"
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")

ICONS = {
    "print": """<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9V3.8h12V9"/><path d="M6 18H4.2A1.8 1.8 0 0 1 2.4 16.2v-4.4A1.8 1.8 0 0 1 4.2 10h15.6a1.8 1.8 0 0 1 1.8 1.8v4.4a1.8 1.8 0 0 1-1.8 1.8H18"/><rect x="6" y="14" width="12" height="6.2" rx="1.2"/></svg>""",
    "folder": """<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3.2 7.2A1.8 1.8 0 0 1 5 5.4h4.1l1.8 1.8H19a1.8 1.8 0 0 1 1.8 1.8v7.6A1.8 1.8 0 0 1 19 18.4H5a1.8 1.8 0 0 1-1.8-1.8V7.2z"/></svg>""",
    "heart": """<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 19.4s-6.4-3.9-6.4-8.1a3.6 3.6 0 0 1 6.4-1.8 3.6 3.6 0 0 1 6.4 1.8c0 4.2-6.4 8.1-6.4 8.1z"/></svg>""",
    "plug": """<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6.5v3.2M15 6.5v3.2"/><path d="M7.6 9.7h8.8v2.1a4.4 4.4 0 0 1-8.8 0V9.7z"/><path d="M12 16.2v3.3"/></svg>""",
    "star": """<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3.4l2.3 4.8 5.3.7-3.8 3.6.9 5.2L12 15.4 7.3 17.7l.9-5.2L4.4 8.9l5.3-.7L12 3.4z"/></svg>""",
    "pin": """<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 20.5s6.2-5.5 6.2-9.7a6.2 6.2 0 1 0-12.4 0c0 4.2 6.2 9.7 6.2 9.7z"/><circle cx="12" cy="10.6" r="2.1"/></svg>""",
    "people": """<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="9" cy="8.2" r="2.6"/><circle cx="16.1" cy="9" r="2.1"/><path d="M3.8 18.6c.5-2.7 2.5-4.1 5.2-4.1s4.6 1.4 5.1 4.1"/><path d="M14 14.4c1.5-.4 3 .1 4 1.3.7 1 .9 2 1 2.9"/></svg>""",
}

SERVICES = [
    (
        "01",
        "print",
        "Print",
        "Scan a QR code and upload from any phone browser, with no app required. Or enter the OTP from the Smart Kiosk app, preview the pages, and collect them from the printer.",
        "The screen shows the page count before you confirm, in black and white or colour.",
    ),
    (
        "02",
        "folder",
        "DigiLocker Print",
        "Sign in to DigiLocker on the kiosk and choose the government documents you need. Preview each file, then print the ones you want.",
        "You check the document on screen first, then collect the pages from the printer.",
    ),
    (
        "03",
        "heart",
        "Well Being",
        "Check blood oxygen and heart rate with a short fingertip reading, or take a body temperature. Results appear on the screen in a few moments.",
        "The kiosk guides each step, and you can try again if the sensor is not ready.",
    ),
    (
        "04",
        "plug",
        "Phone Charging",
        "Watch a short sponsored message, then plug in your phone. The screen follows the session until you finish and return to the menu.",
        "You can cancel while the message is playing or while the phone is connecting.",
    ),
    (
        "05",
        "star",
        "Astrology",
        "Open a birth chart in North or South Indian style, or photograph a palm for insights. You can also match two charts or see today’s panchang.",
        "Birth details are entered on the kiosk. Nothing needs to be installed on your phone.",
    ),
    (
        "06",
        "pin",
        "Fuel stations",
        "Find petrol, diesel, CNG, and EV stations nearby, and filter by fuel type. Open a map, then scan a QR code to continue directions on your phone.",
        "Distance and a rough drive time help you choose the nearest stop.",
    ),
]

TRADES = [
    "AC, RO and washing machines",
    "Two-wheeler mechanics",
    "Carpenters",
    "Electricians",
    "Painters",
    "Tailors",
    "Scrap dealers",
    "Gas-stove repair",
    "Pigeon netting",
    "Puncture repair",
]

PUBLIC = [
    ("Home", "Tap Home when you are done. The next person starts with a clear screen."),
    ("Still there?", "If the kiosk sits idle, a short countdown returns it to the menu."),
    ("At a glance", "The home screen shows the time and local weather while you choose a service."),
    ("Out of paper", "If the printer runs out of paper, printing pauses with a plain message."),
]

CSS = r"""
@page { size: A4; margin: 0; }
* { box-sizing: border-box; }
html, body {
  margin: 0;
  padding: 0;
  background: #fff;
  color: #1A2430;
  font-family: "Segoe UI", Calibri, sans-serif;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
.page {
  width: 210mm;
  height: 297mm;
  padding: 8mm 9mm 7mm;
  display: flex;
  flex-direction: column;
  page-break-after: always;
  overflow: hidden;
  background:
    radial-gradient(circle at 100% 0%, rgba(46,196,160,.08), transparent 28%),
    #fff;
}
.page:last-child { page-break-after: auto; }
.hero {
  display: flex;
  gap: 5mm;
  align-items: center;
  background: #0F6A5A;
  color: #fff;
  border-radius: 4.5mm;
  padding: 4.2mm 5mm 4.4mm;
  border-bottom: 1.3mm solid #E8C872;
  box-shadow: 0 2mm 5mm rgba(15,106,90,.16);
}
.logo-wrap {
  background: #fff;
  border-radius: 3.2mm;
  padding: 1.1mm;
  flex: 0 0 auto;
  line-height: 0;
}
.logo-wrap img { display: block; width: 32mm; height: 32mm; object-fit: contain; }
.layout-roomy .logo-wrap img { width: 42mm; height: 42mm; }
.eyebrow {
  margin: 0 0 1mm;
  letter-spacing: .16em;
  font-size: 8.5pt;
  font-weight: 700;
  color: #E8C872;
}
h1 {
  margin: 0;
  font-size: 26pt;
  line-height: .95;
  font-weight: 750;
  letter-spacing: -.02em;
}
.layout-roomy h1 { font-size: 32pt; }
.promise {
  margin: 1.4mm 0 0;
  color: #2EC4A0;
  font-size: 12pt;
  font-weight: 700;
}
.tagline {
  margin: 1.2mm 0 0;
  color: rgba(255,255,255,.82);
  font-size: 8.5pt;
}
.intro {
  margin: 3.2mm 1mm 2.6mm;
  font-size: 10.5pt;
  line-height: 1.35;
  color: #1A2430;
}
.layout-compact .intro { font-size: 9.6pt; margin-top: 2.6mm; margin-bottom: 2.2mm; }
.trade { display: flex; align-items: center; }
.kicker {
  margin: 0 1mm 1.4mm;
  color: #0F6A5A;
  font-size: 8.5pt;
  font-weight: 800;
  letter-spacing: .14em;
}
.grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2.4mm;
}
.card {
  background: #F7FBFA;
  border: .3mm solid #D7E6E1;
  border-left: 1.15mm solid #0F6A5A;
  border-top: .7mm solid #E8C872;
  border-radius: 2.6mm;
  padding: 2.4mm 3mm 2.6mm;
  display: flex;
  gap: 2.4mm;
  align-items: flex-start;
}
.icon {
  flex: 0 0 8mm;
  width: 8mm;
  height: 8mm;
  border-radius: 2mm;
  background: #E7F4F0;
  color: #0F6A5A;
  display: flex;
  align-items: center;
  justify-content: center;
}
.icon svg { width: 5mm; height: 5mm; fill: none; stroke: currentColor; stroke-width: 1.7; stroke-linecap: round; stroke-linejoin: round; }
.num {
  margin: 0;
  color: #C4A35A;
  font-size: 8pt;
  font-weight: 800;
  letter-spacing: .08em;
}
h2 {
  margin: 0;
  color: #0F6A5A;
  font-size: 12pt;
  line-height: 1.15;
}
.layout-compact h2 { font-size: 11pt; }
.card p, .wide p, .pub p, .step p {
  margin: .7mm 0 0;
  font-size: 9pt;
  line-height: 1.32;
  color: #1A2430;
}
.layout-compact .card p { font-size: 8.35pt; line-height: 1.28; }
.more { color: #5C6B76 !important; }
.wide {
  margin-top: 2.4mm;
  background: #F7FBFA;
  border: .3mm solid #D7E6E1;
  border-left: 1.15mm solid #0F6A5A;
  border-top: .7mm solid #E8C872;
  border-radius: 2.6mm;
  padding: 2.5mm 3.2mm 2.8mm;
  display: flex;
  gap: 2.6mm;
}
.section-head { margin: 0 0 2mm; }
.section-head h2 { font-size: 16pt; }
.lead {
  margin: 0 0 3.2mm;
  font-size: 11pt;
  line-height: 1.4;
}
.trades {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2.6mm;
}
.trade {
  background: #F7FBFA;
  border: .3mm solid #D7E6E1;
  border-left: 1.15mm solid #0F6A5A;
  border-top: .65mm solid #E8C872;
  border-radius: 2.4mm;
  padding: 3.2mm 3.4mm;
  color: #0F6A5A;
  font-weight: 750;
  font-size: 11.5pt;
}
.steps {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 2.6mm;
  margin: 3.4mm 0 3.6mm;
}
.step {
  background: #0F6A5A;
  color: #fff;
  border-radius: 2.6mm;
  padding: 3mm 3.2mm 3.2mm;
}
.step b {
  display: block;
  color: #E8C872;
  font-size: 8pt;
  letter-spacing: .12em;
}
.step strong { display: block; margin-top: .6mm; font-size: 11pt; }
.step p { color: rgba(255,255,255,.92); font-size: 9pt; }
.band {
  margin-top: 2.6mm;
}
.band h3 {
  margin: 0 0 1mm;
  color: #0F6A5A;
  font-size: 8.5pt;
  letter-spacing: .14em;
}
.band .note {
  margin: 0 0 2mm;
  color: #5C6B76;
  font-size: 9.5pt;
}
.pubs {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2.2mm;
}
.pub {
  background: #E7F4F0;
  border-top: .65mm solid #2EC4A0;
  border-radius: 2.2mm;
  padding: 2mm 2.6mm 2.2mm;
}
.pub strong { color: #0F6A5A; font-size: 9.5pt; }
.layout-compact .pub p { font-size: 8pt; margin-top: .4mm; }
.footer {
  margin-top: auto;
  padding-top: 2.2mm;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-top: .35mm solid #0F6A5A;
  color: #5C6B76;
  font-size: 8pt;
}
.footer b { color: #0F6A5A; }
.layout-roomy .page-local { padding-top: 9mm; }
.layout-roomy .hero { padding: 5mm 6mm; }
"""


def card(number: str, icon: str, title: str, body: str, extra: str, detailed: bool) -> str:
    more = f'<p class="more">{extra}</p>' if detailed else ""
    return f"""
    <article class="card">
      <div class="icon">{ICONS[icon]}</div>
      <div>
        <p class="num">{number}</p>
        <h2>{title}</h2>
        <p>{body}</p>
        {more}
      </div>
    </article>"""


def public_block() -> str:
    items = "".join(
        f'<article class="pub"><strong>{title}</strong><p>{body}</p></article>'
        for title, body in PUBLIC
    )
    return f"""
    <section class="band">
      <h3>BUILT FOR PUBLIC USE</h3>
      <p class="note">The same screen stays simple for every visitor who walks up to it.</p>
      <div class="pubs">{items}</div>
    </section>"""


def footer(page: str, pages: str) -> str:
    return f"""
    <footer class="footer">
      <span><b>Smart Kiosk</b> &nbsp;·&nbsp; Services in one touch</span>
      <span>{page} / {pages}</span>
    </footer>"""


def hero(compact: bool) -> str:
    tag = "" if compact else '<p class="tagline">Empowering Businesses with Smart IT Solutions</p>'
    return f"""
    <header class="hero">
      <div class="logo-wrap"><img src="image.png" alt="Company logo"></div>
      <div>
        <p class="eyebrow">DESKTOP KIOSK</p>
        <h1>Smart Kiosk</h1>
        <p class="promise">Services in one touch</p>
        {tag}
      </div>
    </header>"""


def one_page() -> str:
    cards = "".join(card(*svc, False) for svc in SERVICES)
    trades = ", ".join(TRADES[:-1]) + ", and " + TRADES[-1]
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Smart Kiosk — Desktop services</title>
<style>{CSS}</style></head>
<body class="layout-compact">
  <section class="page">
    {hero(True)}
    <p class="intro">A public touchscreen for everyday tasks. Seven services sit on the home screen. Touch a tile to begin.</p>
    <p class="kicker">WHAT YOU CAN DO</p>
    <div class="grid">{cards}</div>
    <article class="wide">
      <div class="icon">{ICONS["people"]}</div>
      <div>
        <p class="num">07</p>
        <h2>Local services</h2>
        <p>Look up help for {trades}. Each listing shows the name, phone number, and location.</p>
      </div>
    </article>
    {public_block()}
    {footer("1", "1")}
  </section>
</body></html>"""


def two_page() -> str:
    cards = "".join(card(*svc, True) for svc in SERVICES)
    trades = "".join(f'<div class="trade">{name}</div>' for name in TRADES)
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Smart Kiosk — Desktop services</title>
<style>{CSS}</style></head>
<body class="layout-roomy">
  <section class="page">
    {hero(False)}
    <p class="intro">A public touchscreen for everyday tasks. Printing, health checks, phone charging, astrology, nearby fuel, and local contacts — each one a short visit, with no training required.</p>
    <p class="kicker">WHAT YOU CAN DO</p>
    <div class="grid">{cards}</div>
    {footer("1", "2")}
  </section>
  <section class="page page-local">
    <p class="kicker">07 · LOCAL SERVICES</p>
    <div class="section-head"><h2>Find a person for an everyday job</h2></div>
    <p class="lead">Pick a trade on the kiosk. Each listing shows the name, phone number, and where that person works.</p>
    <div class="steps">
      <article class="step"><b>STEP 1</b><strong>Choose a trade</strong><p>Ten kinds of everyday help, from repairs to tailoring.</p></article>
      <article class="step"><b>STEP 2</b><strong>See who can help</strong><p>The screen shows a name, a phone number, and a location.</p></article>
      <article class="step"><b>STEP 3</b><strong>Call from your phone</strong><p>Take the number with you and contact them directly.</p></article>
    </div>
    <div class="trades">{trades}</div>
    {public_block()}
    {footer("2", "2")}
  </section>
</body></html>"""


def write_html(name: str, html: str) -> Path:
    path = DOCS / name
    path.write_text(html, encoding="utf-8")
    return path


def print_pdf(html_path: Path, pdf_path: Path) -> None:
    if not EDGE.is_file():
        raise SystemExit(f"Microsoft Edge was not found at {EDGE}")
    if not LOGO.is_file():
        raise SystemExit(f"Logo not found at {LOGO}")
    if pdf_path.exists():
        pdf_path.unlink()
    uri = html_path.resolve().as_uri()
    with tempfile.TemporaryDirectory(prefix="skp-edge-", ignore_cleanup_errors=True) as profile:
        cmd = [
            str(EDGE),
            "--headless=new",
            "--disable-gpu",
            "--no-first-run",
            "--disable-extensions",
            "--no-pdf-header-footer",
            f"--user-data-dir={profile}",
            f"--print-to-pdf={pdf_path}",
            "--virtual-time-budget=12000",
            uri,
        ]
        subprocess.run(cmd, check=True, timeout=60)
    if not pdf_path.is_file() or pdf_path.stat().st_size < 1000:
        raise SystemExit(f"PDF was not written: {pdf_path}")


def main() -> None:
    one_html = write_html("Smart-Kiosk-Features-1page.html", one_page())
    two_html = write_html("Smart-Kiosk-Features-2page.html", two_page())
    one_pdf = DOCS / "Smart-Kiosk-Features-1page.pdf"
    two_pdf = DOCS / "Smart-Kiosk-Features-2page.pdf"
    print_pdf(one_html, one_pdf)
    print_pdf(two_html, two_pdf)
    print(one_pdf)
    print(two_pdf)


if __name__ == "__main__":
    main()
