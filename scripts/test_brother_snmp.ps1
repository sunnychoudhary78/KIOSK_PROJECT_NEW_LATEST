$ErrorActionPreference = "Stop"

$python = "C:\Windows\Temp\brother-snmp-test\.venv\Scripts\python.exe"

@'
import os
import asyncio
from pysnmp.hlapi.v3arch.asyncio import (
    SnmpEngine, CommunityData, UdpTransportTarget,
    ContextData, ObjectType, ObjectIdentity, get_cmd
)

HOST = os.environ.get("SKP_PRINTER_SNMP_HOST", "192.168.1.13")
COMMUNITY = os.environ["SKP_PRINTER_SNMP_COMMUNITY"]

OIDS = [
    "1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.8.0",
    "1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.10.0",
    "1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.11.0",
]

MAINTENANCE_OID = OIDS[0]
PAGE_COUNTER_OID = OIDS[1]
REMAINING_PARTS_OID = OIDS[2]

def decode_blob(data):
    records = []
    i = 0

    while i < len(data):
        if data[i:i+4] == b"\xff\xff\xff\xff":
            break

        if data[i:i+3] == b"\xff\xff\xff":
            i += 3
            continue

        if data[i:i+1] == b"\xff" and i + 1 == len(data):
            break

        if i + 3 > len(data) or data[i+1:i+3] != b"\x01\x04":
            records.append((f"{data[i]:02X}", None, "Unrecognized record"))
            break

        tag = data[i]
        i += 3
        value_bytes = bytearray()

        while len(value_bytes) < 4 and i < len(data):
            if data[i:i+3] == b"\xff\xff\xff":
                i += 3
                continue
            value_bytes.append(data[i])
            i += 1

        if len(value_bytes) != 4:
            records.append((f"{tag:02X}", None, "Incomplete value"))
            break

        value = int.from_bytes(value_bytes, "big")
        records.append((f"{tag:02X}", value, ""))

    return records

def metric_value(records, tag):
    if not records:
        return None
    for record_tag, value, _note in records:
        if record_tag == tag and value is not None:
            return value
    return None

def show_metric(label, records, tag, as_percent, hundredths=False):
    value = metric_value(records, tag)
    if value is None:
        shown = "unavailable"
    elif as_percent and hundredths:
        whole, frac = divmod(value, 100)
        if frac == 0:
            shown = f"{whole}%"
        else:
            shown = f"{whole}.{frac:02d}".rstrip("0").rstrip(".") + "%"
    elif as_percent:
        shown = f"{value}%"
    else:
        shown = str(value)
    print(f"{label}: {shown}")

def print_summary(decoded):
    maintenance = decoded[MAINTENANCE_OID]["records"]
    pages = decoded[PAGE_COUNTER_OID]["records"]
    parts = decoded[REMAINING_PARTS_OID]["records"]

    print("\nInterpreted summary")
    show_metric("Black toner", maintenance, "81", True)
    show_metric("Cyan toner", maintenance, "82", True)
    show_metric("Magenta toner", maintenance, "83", True)
    show_metric("Yellow toner", maintenance, "84", True)
    show_metric("Drum candidate 79", maintenance, "79", True, hundredths=True)
    show_metric("Drum candidate 7A", maintenance, "7A", True, hundredths=True)
    show_metric("Drum candidate 7B", maintenance, "7B", True, hundredths=True)
    show_metric("Drum candidate 80", maintenance, "80", True, hundredths=True)
    show_metric("Total pages", pages, "00", False)
    show_metric("Color pages", pages, "02", False)
    show_metric("Black-and-white pages", pages, "01", False)
    show_metric("Belt remaining pages", parts, "88", False)
    show_metric("Fuser remaining pages", parts, "73", False)

def print_raw_records(decoded):
    print("\nRaw decoded records")
    for oid in OIDS:
        entry = decoded[oid]
        print(f"\nOID: {oid}")
        if entry["error"] and not entry["records"]:
            print(entry["error"])
            continue
        print("Tag | Raw value | Notes")
        for tag, val, note in entry["records"] or []:
            print(f"{tag}  | {val if val is not None else '-'} | {note}")

BLOB_CANDIDATES = [
    ("1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.20.0", "brInfoReplaceCount", True),
    ("1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.21.0", "brInfoJamCount", False),
    ("1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.23.0", "brInfoReplaceTime", False),
]

ERROR_HISTORY_TABLES = [
    (
        "1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.51.1.0",
        "brErrorHistoryCount",
        "1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.51.2.1.2.",
        "brErrorHistoryDescription",
    ),
    (
        "1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.51.11.0",
        "brCommunicationErrorHistoryCount",
        "1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.51.12.1.2.",
        "brCommunicationErrorHistoryDescription",
    ),
]

def decode_layout2(data):
    records = []
    i = 0

    while i < len(data):
        if data[i:i+4] == b"\xff\xff\xff\xff":
            break

        if data[i:i+3] == b"\xff\xff\xff":
            i += 3
            continue

        if data[i] == 0xFF and i + 1 == len(data):
            break

        if i + 1 >= len(data):
            records.append((f"{data[i]:02X}", None, None, "Incomplete record"))
            break

        tag = data[i]
        length = data[i + 1]
        if length not in (1, 2, 4):
            records.append((f"{tag:02X}", length, None, "Unrecognized length"))
            break

        i += 2
        value_bytes = bytearray()

        while len(value_bytes) < length and i < len(data):
            if data[i:i+4] == b"\xff\xff\xff\xff":
                break
            if data[i:i+3] == b"\xff\xff\xff":
                i += 3
                continue
            value_bytes.append(data[i])
            i += 1

        if len(value_bytes) != length:
            records.append((f"{tag:02X}", length, None, "Incomplete value"))
            break

        value = int.from_bytes(value_bytes, "big")
        records.append((f"{tag:02X}", length, value, ""))

    return records

def print_layout2(records):
    if not records:
        print("No layout-2 records")
        return
    print("Tag | Length | Value | Notes")
    for tag, length, value, note in records:
        length_shown = "-" if length is None else str(length)
        value_shown = "-" if value is None else str(value)
        print(f"{tag}  | {length_shown} | {value_shown} | {note}")

def printable_text(data):
    return "".join(chr(byte) if 32 <= byte <= 126 else "." for byte in data)

def snmp_type_name(value):
    return value.__class__.__name__

def is_unsupported(value):
    name = snmp_type_name(value).lower()
    if name in ("nosuchobject", "nosuchinstance", "endofmibview"):
        return True
    if not hasattr(value, "prettyPrint"):
        return False
    text = value.prettyPrint().lower().replace(" ", "")
    return any(token in text for token in ("nosuchobject", "nosuchinstance", "endofmibview"))

async def get_one(engine, target, oid):
    try:
        error, status, index, var_binds = await get_cmd(
            engine,
            CommunityData(COMMUNITY, mpModel=1),
            target,
            ContextData(),
            ObjectType(ObjectIdentity(oid)),
        )
    except Exception as exc:
        return None, f"ERROR: {exc}"

    if error:
        return None, f"ERROR: {error}"
    if status:
        return None, f"SNMP ERROR: {status.prettyPrint()}"
    if not var_binds:
        return None, "ERROR: no varbind"
    return var_binds[0][1], None

def print_comparison(records, texts):
    print("\nReference comparison")
    print("Equal numbers are not a part assignment.")
    if records is None:
        print("Replacement tags equal to 1: unavailable")
        print("Replacement tags equal to 0: unavailable")
    else:
        ones = [tag for tag, _length, value, _note in records if value == 1]
        zeros = [tag for tag, _length, value, _note in records if value == 0]
        others = [
            f"{tag}={value}"
            for tag, _length, value, _note in records
            if value is not None and value not in (0, 1)
        ]
        print("Replacement tags equal to 1:", ", ".join(ones) if ones else "none")
        print("Replacement tags equal to 0:", ", ".join(zeros) if zeros else "none")
        if others:
            print("Replacement tags with another value:", ", ".join(others))
    print(
        "Webpage reference: toner replacement counts are 1 each; "
        "four drum counts, belt, fuser, and total paper jams are 0."
    )
    print(
        "Replacement-count and jam-count tag meanings are unresolved. "
        "BROTHER-MIB does not define the tags inside those octet strings."
    )
    combined = "\n".join(texts)
    normalized = "\n".join(" ".join(text.split()) for text in texts)
    contains_error = "yes" if "Cannot Print ZC" in normalized else "no"
    contains_page = "yes" if "19" in combined else "no"
    print("Error-history text contains 'Cannot Print ZC':", contains_error)
    print("Error-history text contains '19':", contains_page)

def description_page_note(data):
    suffix_start = len(data)
    for index in range(len(data) - 1, -1, -1):
        if 32 <= data[index] <= 126:
            break
        suffix_start = index
    suffix = data[suffix_start:]
    matches = []
    for length in (1, 2, 4):
        if length > len(suffix):
            continue
        chunk = suffix[-length:]
        big = int.from_bytes(chunk, "big")
        little = int.from_bytes(chunk, "little")
        if big == 19:
            matches.append(f"{length}-byte big-endian")
        if little == 19 and little != big:
            matches.append(f"{length}-byte little-endian")
    if matches:
        print(
            "Unverified reading of brErrorHistoryDescription matches webpage page 19 "
            f"({', '.join(matches)}). This is not a separate MIB column."
        )
    else:
        print("Documented column does not contain page 19.")

async def print_page_candidate(engine, target, index):
    oid = f"1.3.6.1.4.1.2435.2.3.9.4.2.1.5.5.51.2.1.3.{index}"
    print(f"\nOID: {oid}")
    print("candidate, not defined in BROTHER-MIB")
    print("Source: next sub-identifier after the documented description column")
    value, error = await get_one(engine, target, oid)
    if error:
        print(error)
        print("Does not match page 19.")
        compact = error.lower().replace(" ", "")
        unsupported = any(
            token in compact
            for token in ("nosuchobject", "nosuchinstance", "endofmibview")
        )
        return not unsupported
    if is_unsupported(value):
        print(f"Type: {snmp_type_name(value)}")
        print(value.prettyPrint())
        print("Does not match page 19.")
        return False

    print(f"Type: {snmp_type_name(value)}")
    matched = False
    if hasattr(value, "asOctets"):
        data = value.asOctets()
        print("Raw HEX:", data.hex(" ").upper())
        if len(data) in (1, 2, 4):
            matched = (
                int.from_bytes(data, "big") == 19
                or int.from_bytes(data, "little") == 19
            )
    else:
        shown = value.prettyPrint() if hasattr(value, "prettyPrint") else str(value)
        print(f"Value: {shown}")
        try:
            matched = int(value) == 19
        except (TypeError, ValueError):
            matched = False
    if matched:
        print("Value matches webpage page 19. OID remains undocumented.")
    else:
        print("Does not match page 19.")
    return True

async def print_history_table(engine, target, count_oid, count_name, prefix, desc_name):
    print(f"\nOID: {count_oid} ({count_name})")
    value, error = await get_one(engine, target, count_oid)
    texts = []
    if error:
        print(error)
        return texts
    if is_unsupported(value):
        print(f"Type: {snmp_type_name(value)}")
        print(value.prettyPrint())
        return texts

    print(f"Type: {snmp_type_name(value)}")
    shown = value.prettyPrint() if hasattr(value, "prettyPrint") else str(value)
    print(f"Value: {shown}")
    try:
        count = int(value)
    except (TypeError, ValueError):
        print("Count is not an integer; descriptions not queried")
        return texts
    if count <= 0:
        return texts

    read_page_candidate = desc_name == "brErrorHistoryDescription"
    for index in range(1, min(count, 10) + 1):
        oid = f"{prefix}{index}"
        print(f"\nOID: {oid} ({desc_name})")
        row, row_error = await get_one(engine, target, oid)
        if row_error:
            print(row_error)
            compact = row_error.lower().replace(" ", "")
            if "nosuchinstance" in compact or "endofmibview" in compact:
                break
            continue
        if is_unsupported(row):
            print(f"Type: {snmp_type_name(row)}")
            print(row.prettyPrint())
            break
        print(f"Type: {snmp_type_name(row)}")
        if hasattr(row, "asOctets"):
            data = row.asOctets()
            print("Raw HEX:", data.hex(" ").upper())
            text = printable_text(data)
            print(f"Text: {text}")
            texts.append(text)
            if desc_name == "brErrorHistoryDescription":
                description_page_note(data)
        else:
            text = row.prettyPrint() if hasattr(row, "prettyPrint") else str(row)
            print(f"Value: {text}")
            texts.append(text)
            if desc_name == "brErrorHistoryDescription":
                print("Documented column does not contain page 19.")
        if read_page_candidate:
            read_page_candidate = await print_page_candidate(engine, target, index)
    return texts

async def discover_candidates(engine, target):
    print("\nCandidate discovery")
    print("Documented BROTHER-MIB objects. Part tags are unverified.")
    replacement_records = None
    history_text = []

    for oid, name, is_replacement in BLOB_CANDIDATES:
        print(f"\nOID: {oid} ({name})")
        print("Note: part tags unverified")
        value, error = await get_one(engine, target, oid)
        if error:
            print(error)
            continue
        if is_unsupported(value):
            print(f"Type: {snmp_type_name(value)}")
            print(value.prettyPrint())
            continue
        print(f"Type: {snmp_type_name(value)}")
        if hasattr(value, "asOctets"):
            data = value.asOctets()
            print("Raw HEX:", data.hex(" ").upper())
            records = decode_layout2(data)
            print_layout2(records)
            if is_replacement:
                replacement_records = records
        else:
            shown = value.prettyPrint() if hasattr(value, "prettyPrint") else str(value)
            print(f"Value: {shown}")

    for count_oid, count_name, prefix, desc_name in ERROR_HISTORY_TABLES:
        texts = await print_history_table(
            engine, target, count_oid, count_name, prefix, desc_name
        )
        history_text.extend(texts)

    print_comparison(replacement_records, history_text)

async def main():
    engine = SnmpEngine()
    target = await UdpTransportTarget.create((HOST, 161), timeout=3, retries=1)
    decoded = {
        oid: {"records": None, "error": "unavailable"}
        for oid in OIDS
    }

    try:
        for oid in OIDS:
            print(f"\nOID: {oid}")
            result = await get_cmd(
                engine,
                CommunityData(COMMUNITY, mpModel=1),
                target,
                ContextData(),
                ObjectType(ObjectIdentity(oid)),
            )
            error, status, index, var_binds = result

            if error:
                print("ERROR:", error)
                decoded[oid] = {"records": None, "error": f"ERROR: {error}"}
                continue
            if status:
                message = status.prettyPrint()
                print("SNMP ERROR:", message)
                decoded[oid] = {"records": None, "error": f"SNMP ERROR: {message}"}
                continue

            records = []
            type_error = None
            for name, value in var_binds:
                if not hasattr(value, "asOctets"):
                    print("Unexpected type:", value.__class__.__name__)
                    type_error = f"Unexpected type: {value.__class__.__name__}"
                    continue

                data = value.asOctets()
                print("Raw HEX:", data.hex(" ").upper())
                records.extend(decode_blob(data))

            if records or type_error is None:
                decoded[oid] = {"records": records, "error": None}
            else:
                decoded[oid] = {"records": None, "error": type_error}

        print_summary(decoded)
        print_raw_records(decoded)
        await discover_candidates(engine, target)

    finally:
        target.transport.close_transport()

asyncio.run(main())
'@ | Set-Content -Encoding UTF8 .\snmp_query.py

& $python .\snmp_query.py
