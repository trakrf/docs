---
sidebar_position: 6
title: SMS Notifications
description: How TrakRF SMS asset alerts work, how to opt in and out, and how we handle your mobile number.
---

# SMS Notifications

TrakRF can send text-message alerts about the assets your organization tracks. This page explains
what those messages are, how you consent to receive them, and how to stop them. TrakRF is operated
by DevOps To AI LLC dba TrakRF.

SMS is one of several ways to keep an eye on your assets. The same activity is visible in the app
itself, in [Reports](./reports-exports), and through [webhooks](../api/webhooks). You do not need to
receive text messages to use TrakRF.

## What we send

TrakRF SMS messages are **transactional alerts about asset activity** that you chose to monitor,
for example when a tagged asset is seen at, or moves out of, a location. We do not send marketing or
promotional messages by SMS.

Example messages:

> TrakRF: Forklift 12 was seen at Loading Dock B at 14:05 UTC.

> TrakRF: Pallet 4471 moved from Warehouse A to Yard Gate at 09:32 UTC.

> TrakRF: Cart 7 triggered an alarm at Exit Door 2 at 18:47 UTC.

**Message frequency varies** with how much activity occurs on the assets and locations you subscribe
to. **Message and data rates may apply.**

## How you opt in

SMS alerts are set up per asset, inside the TrakRF app, by a signed-in member of your organization.
Nobody is enrolled automatically, and a phone number given elsewhere in TrakRF (for example at
sign-up) does **not** subscribe anyone to text messages.

To subscribe someone to SMS alerts for an asset:

1. Open **Assets** and click the notifications (bell) button on the asset's row.
2. Click **Add subscriber**, then pick an existing contact or add a new one with their mobile
   number.
3. Under **Send alerts by**, tick **SMS**.
4. Read the SMS consent statement below the channels and tick its checkbox. The checkbox is **never
   pre-checked**, and **Subscribe** stays disabled until it is ticked. It is cleared again whenever
   the contact or the number changes.
5. Click **Subscribe**.

![Add subscriber form with SMS chosen: the SMS consent checkbox is unticked and Subscribe is disabled](/img/user-guide/sms-opt-in-consent.png)

_The consent statement is shown in the form whenever it is open. With SMS chosen and the checkbox
unticked, **Subscribe** is disabled._

![The same form with the SMS consent checkbox ticked and Subscribe enabled](/img/user-guide/sms-opt-in-confirmed.png)

_Only after the consent checkbox is ticked can the contact be subscribed by SMS._

The consent statement reads, with the contact, asset and number filled in:

> I confirm _[contact]_ has agreed to receive recurring automated SMS alerts from TrakRF about
> _[asset]_ at _[mobile number]_. Consent is not a condition of purchase. Message frequency varies.
> Message and data rates may apply. Reply HELP for help or STOP to opt out. See the
> [Terms of Service](https://trakrf.id/tos) and [Privacy Policy](https://trakrf.id/privacy-policy).

Only tick it once the person who owns that number has agreed to receive the alerts. If they have
not, untick **SMS** and subscribe them by email instead.

## How to opt out or get help

Opting out is just as simple as opting in, and you can do it at any time.

- **In the app:** open the asset's notifications and click **Switch off** next to the SMS
  subscriber. No further texts are sent for that asset.

  ![Switch off alerts confirmation: the contact will stop receiving SMS alerts for the asset](/img/user-guide/sms-opt-out-switch-off.png)

- **By text:** reply **STOP** to any TrakRF message. You will receive one confirmation and no further
  texts.
- **Resume messages:** reply **START** to the same number.
- **Get help:** reply **HELP**, or email [support@trakrf.id](mailto:support@trakrf.id).

Carriers are not liable for delayed or undelivered messages.

## Your mobile number and privacy

We use your mobile number only to deliver the alerts you subscribed to and to honor your STOP, START
and HELP requests.

**We do not sell, rent or share your mobile number or SMS consent with third parties or affiliates
for marketing or promotional purposes.** We share it only with the messaging provider that delivers
the texts on our behalf.

For more detail, see our [Privacy Policy](https://trakrf.id/privacy-policy) and
[Terms of Service](https://trakrf.id/tos). Questions: [support@trakrf.id](mailto:support@trakrf.id).
