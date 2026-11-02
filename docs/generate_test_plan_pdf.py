"""Build the Smart Kiosk tester guide PDF."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

DOCS = Path(__file__).resolve().parent
LOGO = DOCS / "image.png"
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")

CSS = r"""
@page { size: A4; margin: 11mm 12mm 12mm; }
* { box-sizing: border-box; }
html, body {
  margin: 0;
  padding: 0;
  color: #1A2430;
  font-family: "Segoe UI", Calibri, sans-serif;
  font-size: 10.5pt;
  line-height: 1.4;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}
.cover {
  page-break-after: always;
  min-height: 250mm;
}
.hero {
  background: #0F6A5A;
  color: #fff;
  border-radius: 4mm;
  border-bottom: 1.4mm solid #E8C872;
  padding: 7mm 7mm 6mm;
  display: flex;
  gap: 6mm;
  align-items: center;
}
.logo-wrap {
  background: #fff;
  border-radius: 3mm;
  padding: 1.2mm;
  line-height: 0;
}
.logo-wrap img { width: 36mm; height: 36mm; object-fit: contain; display: block; }
.eyebrow {
  margin: 0 0 1mm;
  color: #E8C872;
  letter-spacing: .14em;
  font-size: 9pt;
  font-weight: 700;
}
h1 { margin: 0; font-size: 28pt; line-height: 1; }
.promise { margin: 2mm 0 0; font-size: 13pt; font-weight: 650; }
h2 {
  margin: 0 0 2mm;
  color: #0F6A5A;
  font-size: 16pt;
  page-break-after: avoid;
}
h3 {
  margin: 4mm 0 1.5mm;
  color: #0F6A5A;
  font-size: 12.5pt;
  page-break-after: avoid;
}
p { margin: 0 0 2.5mm; }
.lead { font-size: 12pt; margin-top: 6mm; }
ul { margin: 0 0 3mm; padding-left: 5mm; }
li { margin: 0 0 1.2mm; }
.section { margin-top: 6mm; page-break-inside: avoid; }
.section + .section { break-before: page; }
.check {
  border: .3mm solid #D7E6E1;
  border-left: 1.2mm solid #0F6A5A;
  border-top: .55mm solid #E8C872;
  border-radius: 2mm;
  background: #F7FBFA;
  padding: 2mm 3mm 2.2mm;
  margin: 0 0 2mm;
  break-inside: avoid;
  page-break-inside: avoid;
}
.check .id {
  color: #C4A35A;
  font-weight: 800;
  font-size: 8.5pt;
  letter-spacing: .06em;
}
.check strong.do { color: #0F6A5A; }
.pass { margin: .6mm 0 0; }
.fail { margin: .3mm 0 0; color: #5C6B76; }
.note {
  background: #E7F4F0;
  border-radius: 2mm;
  padding: 2.5mm 3.2mm;
  margin: 0 0 3mm;
}
table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 2mm;
  page-break-inside: auto;
}
th, td {
  border: .3mm solid #D0D9DE;
  padding: 2mm 2.2mm;
  text-align: left;
  vertical-align: top;
  font-size: 10pt;
}
th { background: #0F6A5A; color: #fff; font-weight: 650; }
tr { page-break-inside: avoid; }
.box {
  display: inline-block;
  width: 4mm;
  height: 4mm;
  border: .4mm solid #1A2430;
  margin-right: 1.5mm;
  vertical-align: -0.4mm;
}
.footer-note { margin-top: 4mm; color: #5C6B76; font-size: 9pt; }
"""


def check(code: str, action: str, expect: str, fail: str) -> str:
    return f"""
    <article class="check">
      <div class="id">{code}</div>
      <div><strong class="do">Do:</strong> {action}</div>
      <p class="pass"><strong>Pass when:</strong> {expect}</p>
      <p class="fail"><strong>Fail when:</strong> {fail}</p>
    </article>"""


def html() -> str:
    home = "".join([
        check(
            "H1",
            "Stand at the home screen after the kiosk has started.",
            "You see six tiles: Print, DigiLocker Print, Well Being, Phone Charging, Astrology, and Fuel stations.",
            "A tile is missing, the screen stays on Activating, or it shows Can’t reach the server.",
        ),
        check(
            "H2",
            "Open any service, then tap Home.",
            "You return to the six-tile menu. The next person does not see the previous visit.",
            "Home does nothing, or the previous documents, form, or result are still on screen.",
        ),
        check(
            "H3",
            "Open a service and do not touch the screen for about 2 minutes.",
            "A prompt asks “Are you still there?” If you ignore it, the kiosk returns home after a short countdown. Tap the screen during the countdown and you stay in the service.",
            "The kiosk never warns you, or it wipes the visit while you are still using it.",
        ),
        check(
            "H4",
            "With the printer out of paper, start a print from Quick Print, OTP Print, or DigiLocker.",
            "Printing pauses and the screen says the printer is out of paper, in plain words.",
            "The kiosk says the print succeeded while no pages come out, or the message is a code you cannot act on.",
        ),
    ])
    quick = "".join([
        check(
            "P1",
            "On the home screen, tap Print.",
            "You are asked how you want to print, with “Print from this phone” and “I have an OTP”. Cancel returns home.",
            "Only one path is offered, or Cancel leaves you stuck.",
        ),
        check(
            "Q1",
            "Choose Print from this phone.",
            "A QR code appears, with a countdown until the session expires. The screen says to scan with the phone camera and upload in the browser. No app is required.",
            "There is no QR code, or the phone cannot open the upload page.",
        ),
        check(
            "Q2",
            "Scan the QR, upload one PDF from the phone browser, then return to the kiosk.",
            "The document appears on the kiosk. You can preview it, see the page count, tap Print, and the screen then says to collect the pages from the printer. The pages are the file you uploaded.",
            "The file never appears, preview is blank, or the printed pages do not match the PDF.",
        ),
        check(
            "Q3",
            "Start Quick Print again and tap Cancel before uploading.",
            "You leave the session cleanly and can start again from Home.",
            "The old QR session is still waiting when you come back.",
        ),
        check(
            "Q4",
            "On the phone page, try to upload a file that is not a PDF.",
            "The upload is refused and you are told that only PDF files can be printed.",
            "A non-PDF is accepted or the kiosk crashes.",
        ),
        check(
            "Q5",
            "Show the QR code and wait until the countdown ends. Do not upload.",
            "The session expires and you can start a new one. An upload after expiry does not print.",
            "An expired code still accepts a file and prints it.",
        ),
    ])
    otp = "".join([
        check(
            "O1",
            "On a phone, create a print OTP in the Smart Kiosk app. On the kiosk choose I have an OTP and enter the 6-digit code on the on-screen keypad.",
            "The documents linked to that code appear. The screen says you can use the keypad and do not need a phone keyboard.",
            "A correct code is rejected, or the keypad misses digits.",
        ),
        check(
            "O2",
            "Preview a document, then tap Print.",
            "The kiosk prints that document and tells you to collect the pages.",
            "Preview and print show different files, or nothing comes out while the screen says success.",
        ),
        check(
            "O3",
            "Enter a wrong 6-digit code.",
            "The screen says the OTP is invalid or already used. You can try another code.",
            "A wrong code opens someone else’s documents, or the screen freezes.",
        ),
        check(
            "O4",
            "Redeem a code that has no documents, or an expired code.",
            "You see a plain message such as no documents, or that the OTP has expired. New OTP lets you start again.",
            "The kiosk shows a blank list with a Print button that still runs.",
        ),
    ])
    digi = "".join([
        check(
            "D1",
            "Tap DigiLocker Print and complete sign-in when the DigiLocker page opens.",
            "The kiosk shows Starting DigiLocker, then your linked documents after you allow access.",
            "Sign-in never starts, or it returns home with no explanation.",
        ),
        check(
            "D2",
            "Select a document, preview it, and tap Print.",
            "You see the preview first. After printing, you are told to collect the pages, and those pages match the document.",
            "Print starts with no preview, or the paper is a different file.",
        ),
        check(
            "D3",
            "Tap End session or Home before printing.",
            "The DigiLocker visit ends and the home menu is shown. The next person is not still signed in.",
            "Documents from the previous person are still listed.",
        ),
        check(
            "D4",
            "Finish sign-in but do not share any documents.",
            "The screen says no DigiLocker documents were shared for this session.",
            "It shows an empty screen with no way back, or it prints nothing and calls that success.",
        ),
    ])
    well = "".join([
        check(
            "W1",
            "Tap Well Being with the USB sensor connected.",
            "You can choose Blood Oxygen or Temperature. The screen says only one sensor runs at a time.",
            "Neither choice is offered while the sensor is plugged in, or both start together.",
        ),
        check(
            "W2",
            "Choose Blood Oxygen. Rest a fingertip on the sensor and keep still for about 15 seconds.",
            "The screen guides finger placement, then shows a heart rate in BPM and a blood oxygen (SpO₂) result. It says you may remove your finger.",
            "It never detects the finger, or it shows a result with no numbers.",
        ),
        check(
            "W3",
            "Start Blood Oxygen, then lift your finger before it finishes.",
            "The measurement is cancelled and you return to the two choices.",
            "It keeps counting with no finger, or it saves a result anyway.",
        ),
        check(
            "W4",
            "Choose Temperature. Hold your forehead about 1–2 cm from the sensor and stay still.",
            "The screen guides you, then shows a temperature reading.",
            "It never starts, or the result has no temperature.",
        ),
        check(
            "W5",
            "Unplug the sensor and open Well Being.",
            "The screen says to connect the sensor before you begin. Retry or plugging it back in lets you continue.",
            "It pretends a measurement is running with no sensor.",
        ),
    ])
    charge = "".join([
        check(
            "C1",
            "Tap Phone Charging and watch the sponsored message. Do not skip ahead.",
            "The message plays first. The socket is not offered for charging until that step finishes. Cancel during the message returns you without leaving the socket on.",
            "The socket turns on before the message, or Cancel leaves it on.",
        ),
        check(
            "C2",
            "After the message, plug in a phone.",
            "The screen asks you to plug in, then shows that the phone is connected, with a session timer and the safety-limit time remaining.",
            "The phone draws power but the screen stays on “plug in”, or the socket never turns on.",
        ),
        check(
            "C3",
            "While charging, tap Done charging.",
            "The socket turns off. The screen says charging is finished and you can go back home.",
            "Done leaves the socket powered, or you cannot leave the screen.",
        ),
        check(
            "C4",
            "Unplug the phone during a charge, if it is safe to do so.",
            "The screen says the phone was unplugged and the socket is off.",
            "The socket stays on after the phone is unplugged and the screen still says it is charging.",
        ),
        check(
            "C5",
            "Open Phone Charging with the charging controller disconnected.",
            "You get a clear error and a Retry button. The kiosk does not claim the phone is charging.",
            "The screen looks like a normal charge with no hardware attached.",
        ),
    ])
    astro = "".join([
        check(
            "A1",
            "Tap Astrology.",
            "You can choose My Kundali, Palm Insights, Match Kundalis, and Today & Periods. Cancel returns home.",
            "A reading is missing, or Cancel does not leave the hub.",
        ),
        check(
            "A2",
            "Open My Kundali. Enter name, birth date, time, and place. Choose North Indian, draw the chart, then repeat with South Indian.",
            "Each style draws a birth chart. You can see lagna, sun, moon, and related details, then tap Done or New kundali.",
            "Draw kundali does nothing, or both styles look identical when you asked for the other.",
        ),
        check(
            "A3",
            "Open Palm Insights with the USB camera connected. Place an open palm in the outline, capture it, and get a reading. Then retake.",
            "The camera preview appears. After capture you get on-screen guidance. Retake lets you shoot again.",
            "The camera stays black with no error, or Get reading runs with no photo.",
        ),
        check(
            "A4",
            "Open Palm Insights with no camera connected.",
            "The screen says no camera was found, or that the camera could not be opened, and offers Retry camera.",
            "It shows a reading without a photo.",
        ),
        check(
            "A5",
            "Open Match Kundalis. Enter the groom’s birth details, continue, then enter the bride’s details and match.",
            "You move from groom to bride. The result is a Gun Milan compatibility screen. New match clears both people.",
            "You can match with a name or birth place left blank, or the result mixes up the two people.",
        ),
        check(
            "A6",
            "Open Today & Periods, enter birth details, and tap Get today’s reading.",
            "You see today’s panchang and the current dasha. Done returns you toward home.",
            "The reading has no panchang and no dasha, and does not say that details are unavailable.",
        ),
    ])
    fuel = "".join([
        check(
            "F1",
            "Tap Fuel stations.",
            "A list of nearby stations loads, described as about 5 km. Each row shows enough to tell stations apart, including distance.",
            "The list stays empty with no message, or it never finishes loading.",
        ),
        check(
            "F2",
            "Filter by petrol, diesel, CNG, and EV, one at a time.",
            "The list changes to that fuel. A station that does not sell the selected fuel drops off the list.",
            "Every filter shows the same stations.",
        ),
        check(
            "F3",
            "Tap one station.",
            "You get directions on a map and a QR code labelled for scanning on your phone. Scanning opens directions on the phone.",
            "The QR does not scan, or the map is for a different station than the one you tapped.",
        ),
        check(
            "F4",
            "Tap Home from the station list or the directions view.",
            "You are back on the six-tile menu.",
            "The map stays up or the previous station is still open.",
        ),
    ])
    rows = [
        ("H1–H4", "Home, idle timeout, and out of paper"),
        ("P1, Q1–Q5", "Quick Print"),
        ("O1–O4", "OTP Print"),
        ("D1–D4", "DigiLocker Print"),
        ("W1–W5", "Well Being"),
        ("C1–C5", "Phone Charging"),
        ("A1–A6", "Astrology"),
        ("F1–F4", "Fuel stations"),
    ]
    sheet = "".join(
        f"<tr><td>{code}</td><td>{name}</td>"
        f"<td><span class=\"box\"></span> Pass</td>"
        f"<td><span class=\"box\"></span> Fail</td>"
        f"<td></td></tr>"
        for code, name in rows
    )
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<title>Smart Kiosk — Tester guide</title>
<style>{CSS}</style></head>
<body>
  <section class="cover">
    <header class="hero">
      <div class="logo-wrap"><img src="image.png" alt="Company logo"></div>
      <div>
        <p class="eyebrow">TESTER GUIDE</p>
        <h1>Smart Kiosk</h1>
        <p class="promise">Feature checks for the desktop kiosk</p>
      </div>
    </header>
    <p class="lead">Use this at the machine. Each check says what to do, what you should see, and what counts as a fail. Write Pass or Fail on the last page. If it fails, note the exact words on the screen.</p>
    <div class="note">
      <strong>Before you start.</strong> The kiosk is already activated and shows the home menu. The printer has A4 paper. You have a phone with a camera.
      Some checks need extra gear, and only those checks: a DigiLocker account, the fingertip and temperature sensor, the charging socket, and the palm camera.
    </div>
    <h2>How to mark a result</h2>
    <ul>
      <li>Follow the steps in order inside a feature. You can test the features in any order.</li>
      <li>Pass only when the “Pass when” line is true. If any part of it is missing, mark Fail.</li>
      <li>Do not treat a crash, a frozen screen, or a message you cannot act on as a pass.</li>
      <li>After a fail, tap Home so the next check starts clean.</li>
    </ul>
  </section>

  <section class="section">
    <h2>Home and leaving a visit</h2>
    <p>The home screen is the start and end of every visit. These checks apply to every feature.</p>
    {home}
  </section>

  <section class="section">
    <h2>Print</h2>
    <p>Print has two paths. Quick Print uses a QR code and the phone browser. OTP Print uses a 6-digit code from the Smart Kiosk mobile app.</p>
    <h3>Quick Print</h3>
    {quick}
    <h3>OTP Print</h3>
    {otp}
  </section>

  <section class="section">
    <h2>DigiLocker Print</h2>
    <p>The visitor signs in to DigiLocker on the kiosk, picks a government document, previews it, and prints it.</p>
    {digi}
  </section>

  <section class="section">
    <h2>Well Being</h2>
    <p>Two measurements share one screen: blood oxygen with heart rate, and body temperature. Only one runs at a time.</p>
    {well}
  </section>

  <section class="section">
    <h2>Phone Charging</h2>
    <p>The visitor watches a short sponsored message, then plugs in. The screen follows the session until they finish or the safety limit is reached.</p>
    {charge}
  </section>

  <section class="section">
    <h2>Astrology</h2>
    <p>The hub offers four readings. Each one should end with Done, and Home should clear the details you typed.</p>
    {astro}
  </section>

  <section class="section">
    <h2>Fuel stations</h2>
    <p>The kiosk lists petrol, diesel, CNG, and EV stations about 5 km around it, then hands directions to the visitor’s phone.</p>
    {fuel}
  </section>

  <section class="section">
    <h2>Result sheet</h2>
    <p>Mark one result for each group. If you fail a single check inside the group, mark the group Fail and write the check code in Notes.</p>
    <table>
      <thead>
        <tr><th>Checks</th><th>Feature</th><th>Pass</th><th>Fail</th><th>Notes</th></tr>
      </thead>
      <tbody>{sheet}</tbody>
    </table>
    <p class="footer-note">Tester name ____________________ &nbsp;&nbsp; Date ______________ &nbsp;&nbsp; Kiosk name ____________________</p>
  </section>
</body></html>"""


def main() -> None:
    if not EDGE.is_file():
        raise SystemExit(f"Microsoft Edge was not found at {EDGE}")
    if not LOGO.is_file():
        raise SystemExit(f"Logo not found at {LOGO}")
    html_path = DOCS / "Smart-Kiosk-Test-Plan.html"
    pdf_path = DOCS / "Smart-Kiosk-Test-Plan.pdf"
    html_path.write_text(html(), encoding="utf-8")
    if pdf_path.exists():
        pdf_path.unlink()
    with tempfile.TemporaryDirectory(prefix="skp-edge-", ignore_cleanup_errors=True) as profile:
        subprocess.run(
            [
                str(EDGE),
                "--headless=new",
                "--disable-gpu",
                "--no-first-run",
                "--disable-extensions",
                "--no-pdf-header-footer",
                f"--user-data-dir={profile}",
                f"--print-to-pdf={pdf_path}",
                "--virtual-time-budget=15000",
                html_path.resolve().as_uri(),
            ],
            check=True,
            timeout=90,
        )
    if not pdf_path.is_file() or pdf_path.stat().st_size < 1000:
        raise SystemExit(f"PDF was not written: {pdf_path}")
    print(pdf_path)


if __name__ == "__main__":
    main()
