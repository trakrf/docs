---
sidebar_position: 4
title: Tag numbering and encoding
description: How TrakRF numbers the RFID tags it supplies — the 96-bit EPC layout, customer namespaces, encoding instructions for print bureaus, label rules, and acceptance checks.
---

# Tag numbering and encoding

This page is the reference for how TrakRF numbers the RFID tags it supplies. It is written for
print and encoding bureaus, partners, and anyone receiving TrakRF-encoded tags.

## Summary

A tag numbered from TrakRF's standard pool carries one number, written two ways:

- **On the label**: an 8-digit sequence number, for example `31570344`.
- **In the chip**: a 96-bit EPC made of a fixed 12-character prefix, four reserved zeros, and the
  same 8 digits.

| Printed on the label | Encoded in the chip (EPC, hex) |
| -------------------- | ------------------------------ |
| `31570344`           | `355E4ACFD000000031570344`     |

The last 8 characters of the EPC are always the printed number. The sequence digits are written
into the EPC as decimal digits, one digit per hex character, so nothing after the prefix is ever
`A`–`F`.

Customers with their own numbering get a [customer namespace](#customer-namespaces) instead.

## EPC layout

The EPC is 24 hex characters (96 bits). Positions count from the left, starting at 1.

| Characters | Field                    | Value                                                           |
| ---------- | ------------------------ | --------------------------------------------------------------- |
| 1–2        | Header                   | `35` (GID-96)                                                   |
| 3–9        | General Manager Number   | `5E4ACFD` (98872573 decimal)                                    |
| 10–12      | Namespace code           | `000` = TrakRF standard pool; `001`–`FFF` = customer namespaces |
| 13–16      | Reserved (standard pool) | `0000`                                                          |
| 17–24      | Sequence (standard pool) | 8 decimal digits, `10000001`–`99999999`                         |

In GID-96 terms, characters 10–15 are the Object Class field and characters 16–24 are the serial
field. The namespace code occupies the top of the Object Class.

Characters 1–12, `355E4ACFD000`, are the standard-pool prefix. A customer namespace replaces `000`
with its own code.

### How the numbers are issued

- Sequence numbers come from one global counter, starting at `10000001`. A number is never
  reused.
- The standard pool (namespace `000`) covers TrakRF's own numbering for every customer, order, and
  demo roll, with no customer code in the EPC. Customers with their own numbering use a
  [customer namespace](#customer-namespaces).
- Each order is allocated a contiguous block: the ordered quantity plus an overrun buffer (5% by
  default, adjusted to the bureau's stated tolerance). Blocks needn't start or end on round
  numbers. Buffer numbers that go unused are retired, not reissued.
- Within a roll, tags run from the lowest number to the highest.
- The [tag allocation register](./tag-allocations) lists every block issued so far.

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

## Customer namespaces

A customer namespace prefix is `355E4ACFD` plus a 3-character namespace code, `001`–`FFF`. The
customer controls characters 13–24 (48 bits) and can use any sequencing in them: hex or decimal,
starting from zero or one.

For example, with the illustrative namespace code `0A5` (not a real customer) and a one-based hex
sequence:

| EPC                        | Standard decoder shows             |
| -------------------------- | ---------------------------------- |
| `355E4ACFD0A5000000000001` | `urn:epc:id:gid:98872573.675840.1` |
| `355E4ACFD0A5000000000002` | `urn:epc:id:gid:98872573.675840.2` |

A standard decoder shows the Object Class as the namespace code × 4096 plus the value of the first
3 characters of the customer's tail, read as hex. That's expected, for example:

```text
355E4ACFD0A5A00000000001 → urn:epc:id:gid:98872573.678400.1
```

Match on the EPC characters, not the decoded fields.

- **Customer-required rightmost characters**: when a customer's systems key on their last N
  characters, those characters are encoded unchanged at the right. Any padding goes between the
  prefix and their value, never inside it.
- **No all-zero prefixes by default.** Zero-padded EPCs collide with other vendors' tags and
  clutter shared reader fields, so for a customer with its own numbering TrakRF proposes a
  namespace. A zero-padded or other customer-mandated prefix is used only when the customer
  explicitly requires it. Those tags fall outside both the standard pool and the namespaces.
- **Codes are never reassigned.** TrakRF records each namespace code in its own register and
  doesn't reassign it, even after a customer leaves.

## Encoding instructions for bureaus

### All orders

- Write the **EPC bank (MB01)**: a **96-bit EPC**, with the EPC length in the PC word set to
  **6 words**. Leave the other PC bits at the chip default.
- **No lock and no access password.**
- **On an encode failure, re-encode the same value on the next good tag.** Never skip a number.
- **Return an encode log for every run**, with one row per encoded tag: EPC and TID, plus the
  data-file row number where there is a data file.

### Standard pool (namespace `000`)

TrakRF supplies a data file with one row per tag. Encode from that file only, writing the
`epc_hex` value from each row.

**Don't use a start-and-increment rule.** The sequence is stored as decimal digits, and encoder
software counts in binary, so it would produce `A`–`F` characters. Take each EPC from its row.

The file columns are:

```text
order,line,roll,tag_type,sequence,epc_hex,barcode,human_readable,overrun
```

Rows with `overrun=yes` are the buffer. Encode in file order and use buffer rows only to cover
overruns. Report the last number used back to TrakRF.

### Customer namespace

The order specifies either a data file, or a start value with a hex increment.

## Label rules

| Element                            | Content                                                                                                                        |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Standard pool: human-readable text | The 8-digit sequence                                                                                                           |
| Standard pool: barcode             | Code 128, holding the same 8 digits                                                                                            |
| Standard pool: QR code             | Only when the order asks for one: the full 24-character EPC                                                                    |
| Header text                        | Specified per order                                                                                                            |
| Customer namespace order           | Human-readable, barcode and QR content as specified per order — typically the customer's required characters, not the full EPC |

## Acceptance checks

### First article, before the full run

1. The EPC decodes as GID-96 with General Manager Number `98872573`.
2. The last 8 characters of the EPC equal the printed number. For a customer namespace, the
   customer's required rightmost characters equal the printed value.
3. The barcode scans to the same 8 digits. For a customer namespace, it scans to the customer's
   printed value.

Worked through for the standard-pool example:

| Check              | Result                                                             |
| ------------------ | ------------------------------------------------------------------ |
| Decodes as GID-96  | `355E4ACFD000000031570344` → `urn:epc:id:gid:98872573.0.827786052` |
| Last 8 = printed   | `…31570344` = `31570344`                                           |
| Barcode = 8 digits | Code 128 `31570344`                                                |

### After the run, from the encode log

- No two tags in the run carry the same EPC. Across runs, the bureau doesn't need to check against
  earlier orders: TrakRF's allocation register draws every standard-pool block once, so no number is
  issued twice.
- The last number used is reported to TrakRF.

## How TrakRF shows tag IDs

TrakRF stores and matches on the full EPC. Today the app shows a TrakRF tag as its full EPC, for
example `355E4ACFD000000031570344`, and you find a tag by its full EPC — for instance by pasting
it into [Locate](/docs/app-tour/locate). The app trims leading zeros from tag values, which
doesn't change a TrakRF EPC because it starts with `3`.

**Planned:** a per-organization prefix list, with `355E4ACFD000` as the default. When an EPC
starts with a listed prefix, the app removes the prefix and strips leading zeros for display, so a
standard-pool tag shows as its printed 8 digits. Searching by those 8 digits or by the full EPC
will find the same tag. A customer namespace prefix is added to that organization's list, so its
tags show as the customer's characters with leading zeros stripped. This page will be updated
when that ships.

## Status and caveats

- **`98872573` is a General Manager Number TrakRF assigned itself.** It was not issued by GS1.
- **The scheme is for closed-loop use.** Don't publish these IDs into open GS1 or EPCIS supply
  chains.
- **A move to a RAIN CIN or GS1 prefix is planned.** The sequence pool stays global across any
  prefix change, so an 8-digit number never exists under two prefixes.

Questions about an order or a data file: [email support](mailto:support@trakrf.id).
