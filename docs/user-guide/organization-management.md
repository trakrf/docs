---
sidebar_position: 5
---

# Organization & Team Management

Everything covered on this page lives in the **account menu**, not the left sidebar. Click the avatar button in the top-right corner of the app (it shows your initials) to open it.

The menu header shows your email address and your role in the currently active organization. Below that:

- **Organizations** lists every organization you belong to. Click a name to switch — the app reloads into that organization's data.
- **Create Organization** starts a new one.
- **Organization Settings**, **Members**, and **API Keys** manage the organization you're currently in.
- **Logout** ends your session.

## Switch or create an organization

If you belong to more than one organization, they're all listed under **Organizations** in the account menu. Selecting one switches your active context — assets, locations, members, and everything else in the app scope to whichever organization is active.

To create a new one, click **Create Organization**. A dialog asks for an organization name and explains that you'll be the owner, able to invite others once it's created. Enter a name and click **Create**; TrakRF switches you into the new organization immediately.

## Organization Settings

Click **Organization Settings** to land on a single page covering the active organization's basics:

- **Subscription** — a status line showing your current plan state, e.g. "Trial — expires \<date\>".
- **Organization Name** — an editable text field. The **Save Changes** button stays disabled until you actually change the value.
- An **API Keys** shortcut card that summarizes the feature and links to the same API Keys page reachable from the account menu.
- A **Danger Zone** with a **Delete Organization** button. The page warns plainly that deletion can't be undone.

## Members

Click **Members** to see a table of everyone in the active organization: **Name**, **Email**, **Role**, **Joined**, and **Actions**. Your own row is marked **You**. Each member's role is a dropdown you can change inline — **Owner**, **Admin**, **Manager**, **Operator**, or **Viewer** — if your own role has permission to do so.

Below the table, **Pending Invitations** lists outstanding invites (or "No pending invitations" if there aren't any) next to an **Invite Member** button. Clicking it opens a small form:

1. Enter the invitee's **email address**.
2. Pick a **Role** — Admin, Manager, Operator, or Viewer (Viewer is the default; new members can't be invited directly as Owner).
3. Click **Send Invitation**.

## API Keys

Click **API Keys** to manage tokens that let an external system talk to TrakRF. A fresh organization shows an empty state ("No API keys yet") and a **New key** button. Creating one opens a form:

- **Name** — defaults to something like "API key — \<today's date\>"; free text.
- **Permissions** — separate access levels per area: **Assets** and **Locations** each offer None / Read / Read + Write, and **Tracking** offers None / Read.
- **Expiration** — Never, 30 days, 90 days, 1 year, or a custom date.

Click **Create key** to generate it. This page is where you provision and revoke integration credentials from the UI — it doesn't expose the organization or member data itself, just the keys used to access it externally.
