---
sidebar_position: 4
title: Tag numbering and encoding
description: How TrakRF numbers the RFID tags it supplies — the 96-bit EPC layout, encoding instructions for print bureaus, label rules, and first-article acceptance checks.
---

# Tag numbering and encoding

This page is the reference for how TrakRF numbers the RFID tags it supplies. It is written for
print and encoding bureaus, partners, and anyone receiving TrakRF-encoded tags.

## Summary

Every TrakRF-encoded tag carries one number, written two ways:

- **On the label**: an 8-digit sequence number, for example `31570344`.
- **In the chip**: a 96-bit EPC made of a fixed 12-character prefix, four reserved zeros, and the
  same 8 digits.

| Printed on the label | Encoded in the chip (EPC, hex) |
| -------------------- | ------------------------------ |
| `31570344`           | `355E4ACFD000000031570344`     |

The last 8 characters of the EPC are always the printed number. The sequence digits are written
into the EPC as decimal digits, one digit per hex character, so nothing after the prefix is ever
`A`–`F`.

## EPC layout

The EPC is 24 hex characters (96 bits). Positions count from the left, starting at 1.

| Characters | Field                         | Value                                   |
| ---------- | ----------------------------- | --------------------------------------- |
| 1–2        | Header                        | `35` (GID-96)                           |
| 3–9        | General Manager Number        | `5E4ACFD` (98872573 decimal)            |
| 10–12      | Object class, high characters | `000`                                   |
| 13–16      | Reserved                      | `0000`                                  |
| 17–24      | Sequence                      | 8 decimal digits, `10000001`–`99999999` |

Characters 1–12, `355E4ACFD000`, are the fixed TrakRF prefix. Characters 13–16 are always `0000`.

### How the numbers are issued

- Sequence numbers come from one global counter, starting at `10000001`. A number is never
  reused.
- One pool covers every customer, order, and demo roll. The EPC carries no customer code.
- Each order is allocated a contiguous block: the ordered quantity plus a 5% overrun buffer.
  Blocks needn't start or end on round numbers. Buffer numbers that go unused are retired, not
  reissued.
- Within a roll, tags run from the lowest number to the highest.

### What a standard decoder shows

The layout is a valid GID-96 encoding, so standard EPC decoders read it. For the example above
they show:

```text
urn:epc:id:gid:98872573.0.827786052
```

The serial a decoder shows (`827786052`) is not the printed number. GID-96 reads the last 9 hex
characters (`031570344`) as one binary value. The printed number is those same characters read
as decimal digits. Match tags to labels on the last 8 characters of the EPC, never on the
decoded serial.

## Encoding instructions for bureaus

TrakRF supplies a data file with one row per tag. Encode from that file only.

- Write the **EPC bank (MB01)** with the `epc_hex` value from each row.
- **96 bits**, with the EPC length in the PC word set to **6 words** (PC `3000` hex when no other
  PC flags are set).
- **No lock and no access password.**
- **Don't use a start-and-increment rule.** Encoder software counts in binary and would produce
  `A`–`F` characters. Take each EPC from its row.
- **On an encode failure, re-encode the same row on the next good tag.** Never skip a number.

### File columns

```text
order,line,roll,tag_type,sequence,epc_hex,barcode,human_readable,overrun
```

Rows with `overrun=yes` are the buffer. Encode in file order and use buffer rows only to cover
overruns. Report the last number used back to TrakRF.

## Label rules

| Element             | Content                                                     |
| ------------------- | ----------------------------------------------------------- |
| Human-readable text | The 8-digit sequence                                        |
| Barcode             | Code 128, holding the same 8 digits                         |
| QR code             | Only when the order asks for one: the full 24-character EPC |
| Header text         | Specified per order                                         |

## First-article acceptance checks

Before a full run, check a first article against all of these:

1. The EPC decodes as GID-96 with General Manager Number `98872573`.
2. The last 8 characters of the EPC equal the printed number.
3. The barcode scans to the same 8 digits.
4. No two tags carry the same EPC.

Worked through for the example tag:

| Check              | Result                                                             |
| ------------------ | ------------------------------------------------------------------ |
| Decodes as GID-96  | `355E4ACFD000000031570344` → `urn:epc:id:gid:98872573.0.827786052` |
| Last 8 = printed   | `…31570344` = `31570344`                                           |
| Barcode = 8 digits | Code 128 `31570344`                                                |
| No duplicates      | Checked across the whole run, not per tag                          |

## How TrakRF shows tag IDs

TrakRF stores and matches on the full EPC. Today the app shows a TrakRF tag as its full EPC, for
example `355E4ACFD000000031570344`, and you find a tag by its full EPC — for instance by pasting
it into [Locate](/docs/app-tour/locate). The app trims leading zeros from tag values, which
doesn't change a TrakRF EPC because it starts with `3`.

**Planned:** a per-organization prefix list, with `355E4ACFD000` as the default. When an EPC
starts with a listed prefix, the app removes the prefix and strips leading zeros for display, so a
TrakRF tag shows as its printed 8 digits. Searching by those 8 digits or by the full EPC will find
the same tag. This page will be updated when that ships.

## Customer-specified encodings

When a customer supplies its own numbering scheme, such as sequential hex, TrakRF encodes it as
given. Those tags are outside this scheme: they don't use the TrakRF prefix or the sequence pool,
and the app shows them as their full EPC.

## Status and caveats

- **`98872573` is a General Manager Number TrakRF assigned itself.** It was not issued by GS1.
- **The scheme is for closed-loop use.** Don't publish these IDs into open GS1 or EPCIS supply
  chains.
- **A move to a RAIN CIN or GS1 prefix is planned.** The sequence pool stays global across any
  prefix change, so an 8-digit number never exists under two prefixes.

Questions about an order or a data file: [email support](mailto:support@trakrf.id).
