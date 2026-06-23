---
name: radicale
description: Use when managing calendars or contacts on a self-hosted Radicale CalDAV/CardDAV server. Trigger for requests such as "list my calendar", "what's on my calendar this week", "when is my next event", "add to my calendar", "create an event", "schedule a meeting", "cancel an event", "find a contact", "what's someone's email", "search my contacts", "add a contact", or mentions of Radicale, CalDAV, CardDAV, calendar events, addressbooks, or contact management.
---

# Radicale CalDAV/CardDAV Management

Manage calendars (events) and contacts on a self-hosted Radicale server using CalDAV and CardDAV protocols.

**Type:** Read & Write (calendar events and contacts)

## Purpose

This skill enables comprehensive calendar and contact management through a self-hosted Radicale server. It provides read and write access to:
- **Calendars** - List, view, create, update, and delete calendar events
- **Contacts** - List, search, create, update, and delete contacts in addressbooks

All operations use the Python caldav library which implements the CalDAV (RFC 4791) and CardDAV (RFC 6352) protocols.

## Setup

### Prerequisites

Install required Python libraries:

```bash
pip install caldav vobject icalendar
```

**Script Permissions:**

The Python script can be made executable (optional but recommended):

```bash
chmod +x scripts/radicale-api.py
```

You can then run it directly:
```bash
./scripts/radicale-api.py --help
```

Or without executable permissions using Python:
```bash
python scripts/radicale-api.py --help
```

### Credentials

Configure these values through plugin userConfig. The setup hook writes
`${XDG_CONFIG_HOME:-~/.config}/lab-radicale/config.env` with mode `600`.
Legacy `~/.lab/.env` remains a fallback during
migration, but do not ask users to hand-edit them unless plugin config is
unavailable:

```bash
RADICALE_URL="https://radicale.example.test"
RADICALE_USERNAME="<radicale-username>"
RADICALE_PASSWORD="<radicale-password>"
```

**Security:**
- Generated config and `.env` files are local-only; never commit credentials
- The plugin hook sets generated config permissions to `600`

## Destructive and write actions

This skill writes to live calendar and contact data. Creates and deletes take
effect immediately on the Radicale server, with **no confirmation prompt and no
undo**. Before running any write operation — `events create`, `events delete`,
`contacts create`, or `contacts delete` — confirm the action and its parameters
(target calendar/addressbook, title, date/time, UID) with the user. Deletions
are permanent: always show the user which event or contact (by summary/name and
UID) you are about to delete and get explicit confirmation first.

Read operations (`calendars list`, `events list`, `contacts list`,
`contacts addressbooks`, `contacts search`) are safe to run without confirmation.

## Core Operations

All operations use the `scripts/radicale-api.py` wrapper script. Output is JSON format for easy parsing.

### Calendar Operations

#### List Calendars

```bash
python scripts/radicale-api.py calendars list
```

Returns array of calendars with name, URL, and ID.

#### View Events

List events in a calendar within a date range:

```bash
python scripts/radicale-api.py events list \
  --calendar "Personal" \
  --start "2026-02-08" \
  --end "2026-02-15"
```

**Parameters:**
- `--calendar` (required) - Calendar name (case-sensitive)
- `--start` (optional) - Start date (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
- `--end` (optional) - End date (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)

**Default behavior:** If start/end not specified, uses current date + 7 days.

Returns array of events with UID, summary, description, location, start, end, and timestamps.

#### Create Event

```bash
python scripts/radicale-api.py events create \
  --calendar "Personal" \
  --title "Meeting" \
  --start "2026-02-10T14:00:00" \
  --end "2026-02-10T15:00:00" \
  --location "Conference Room" \
  --description "Team sync"
```

**Required parameters:**
- `--calendar` - Calendar name
- `--title` - Event title/summary
- `--start` - Start datetime (YYYY-MM-DDTHH:MM:SS)
- `--end` - End datetime (YYYY-MM-DDTHH:MM:SS)

**Optional parameters:**
- `--location` - Event location
- `--description` - Event description

**Important:** Use ISO 8601 datetime format (YYYY-MM-DDTHH:MM:SS). End must be after start.

> **⚠️ Timezone limitation — read before creating events.** This skill has **no
> timezone support**: datetimes are stored as-is in the Radicale server's local
> time. If the user gives a time in a specific zone (e.g. "7PM EST"), you MUST
> convert it to the server's local time yourself before passing it — passing the
> raw zoned time will silently create a wrong-time event. There is also **no
> recurring-event support** and no reminders/alarms; create recurring or
> reminder events one-off and tell the user about the limitation. When in doubt
> about the target timezone, confirm with the user.

#### Delete Event

```bash
python scripts/radicale-api.py events delete \
  --calendar "Personal" \
  --uid "event-uid-here"
```

Get UID from `events list` output.

### Contact Operations

#### List Addressbooks

```bash
python scripts/radicale-api.py contacts addressbooks
```

Returns array of addressbooks with name, URL, and ID.

#### List Contacts

```bash
python scripts/radicale-api.py contacts list \
  --addressbook "Contacts"
```

Returns array of contacts with UID, name, email, and phone.

#### Search Contacts

```bash
python scripts/radicale-api.py contacts search \
  --addressbook "Contacts" \
  --query "David"
```

**Search behavior:** Case-insensitive substring match against name and email fields.

#### Create Contact

```bash
python scripts/radicale-api.py contacts create \
  --addressbook "Contacts" \
  --name "John Doe" \
  --email "john@example.com" \
  --phone "+1-555-1234"
```

**Required parameter:**
- `--name` - Contact full name

**Optional parameters:**
- `--email` - Email address
- `--phone` - Phone number

#### Delete Contact

```bash
python scripts/radicale-api.py contacts delete \
  --addressbook "Contacts" \
  --uid "contact-uid-here"
```

Get UID from `contacts list` or `contacts search` output.

## Mapping requests to commands

Pick the operation from the user's intent, then identify the target and extract
parameters:

- Calendar query ("show", "list", "what's on") → `events list`
- Calendar create ("add", "schedule") → `events create`
- Calendar delete ("remove", "cancel") → `events delete` (confirm first)
- Contact query ("find", "who is", "what's their email") → `contacts search`
- Contact create ("add contact") → `contacts create`
- Contact delete ("delete contact") → `contacts delete` (confirm first)

Defaults: calendar `"Personal"`, addressbook `"Contacts"` (confirm with the user
if ambiguous). Then run the command, parse the JSON, and present results in
human-readable form.

**Date/time:** use ISO 8601 `YYYY-MM-DDTHH:MM:SS`; default event duration 1 hour
if no end given. Times are stored in the **server's local timezone** — convert
any zoned time the user gives (see the timezone limitation under *Create Event*).
Resolve relative dates ("this week", "tomorrow", "7PM") yourself before calling.

Worked natural-language → command examples (calendar and contacts) live in
`references/quick-reference.md`.

## Error Handling

All operations return JSON with status. Check for:

**Connection errors:**
- `ERROR: Radicale config not found` → Configure plugin userConfig or verify legacy fallback files
- `ERROR: Failed to connect to Radicale` → Check Radicale is running, verify URL
- `ERROR: Authentication failed` → Verify plugin-configured credentials

**Resource errors:**
- `ERROR: Calendar 'X' not found` → List available calendars with `calendars list`
- `ERROR: Addressbook 'X' not found` → List addressbooks with `contacts addressbooks`

**Data errors:**
- `ValueError: Invalid isoformat string` → Fix datetime format to ISO 8601
- End time before start time → Adjust end time to be after start

## Notes

**Read-Write Operations:**
- All operations modify data on the Radicale server
- Event creation is immediate (no confirmation prompt)
- Contact creation is immediate (no confirmation prompt)
- Deletions are permanent (no undo)

**Performance:**
- Use date ranges for event queries to avoid loading all events
- Search contacts instead of listing all when looking for specific person
- Calendar/contact listing can be slow with large datasets

**Limitations:**
- No timezone support in current implementation (uses local time)
- No recurring event support yet
- Contact fields limited to name, email, phone (vCard supports more)
- No event reminders/alarms

**Security:**
- Credentials are read from generated plugin config or legacy local env files
- API script never logs credentials
- Connection uses HTTP basic auth (HTTPS recommended for production)

## Reference

Bundled references (load as needed):
- `references/caldav-library.md` — Python caldav library guide (auth patterns, CalDAV/CardDAV operations, error handling)
- `references/quick-reference.md` — command examples with sample outputs
- `references/troubleshooting.md` — installation, connection, auth, and data errors

External:
- [Radicale Documentation](https://radicale.org/v3.html)
- [caldav Library Docs](https://caldav.readthedocs.io/)

## Agent Tool Usage

Run this skill's scripts with the Bash tool directly:

```bash
python scripts/radicale-api.py [args]
```
