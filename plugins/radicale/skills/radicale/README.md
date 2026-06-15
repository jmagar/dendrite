# Radicale CalDAV/CardDAV Management

Manage calendars and contacts on a self-hosted Radicale server through the
bundled `scripts/radicale-api.py` helper.

## Setup

Install the Python dependencies in the environment used to run the helper:

```bash
pip install caldav vobject icalendar
```

Configure Radicale through plugin userConfig. The plugin setup hook writes:

```text
${XDG_CONFIG_HOME:-~/.config}/lab-radicale/config.env
```

The helper also supports legacy `~/.lab/.env` and `~/.claude-homelab/.env`
fallbacks during migration. Keep all local config files out of git.

Expected variables:

```bash
RADICALE_URL="https://radicale.example.test"
RADICALE_USERNAME="<radicale-username>"
RADICALE_PASSWORD="<radicale-password>"
```

## Calendar Commands

List calendars:

```bash
python scripts/radicale-api.py calendars list
```

List events. If `--start` and `--end` are omitted, the helper uses the current
time through seven days from now:

```bash
python scripts/radicale-api.py events list \
  --calendar "Personal" \
  --start "2026-02-08" \
  --end "2026-02-15"
```

Create an event:

```bash
python scripts/radicale-api.py events create \
  --calendar "Personal" \
  --title "Team Meeting" \
  --start "2026-02-10T14:00:00" \
  --end "2026-02-10T15:00:00" \
  --location "Conference Room" \
  --description "Weekly sync"
```

Delete an event by UID from `events list` output:

```bash
python scripts/radicale-api.py events delete \
  --calendar "Personal" \
  --uid "<event-uid>"
```

## Contact Commands

List addressbooks:

```bash
python scripts/radicale-api.py contacts addressbooks
```

List contacts:

```bash
python scripts/radicale-api.py contacts list --addressbook "Contacts"
```

Search contacts by name or email:

```bash
python scripts/radicale-api.py contacts search \
  --addressbook "Contacts" \
  --query "David"
```

Create a contact:

```bash
python scripts/radicale-api.py contacts create \
  --addressbook "Contacts" \
  --name "Jane Smith" \
  --email "jane.smith@example.test" \
  --phone "+1-555-0100"
```

Delete a contact by UID from `contacts list` or `contacts search` output:

```bash
python scripts/radicale-api.py contacts delete \
  --addressbook "Contacts" \
  --uid "<contact-uid>"
```

## Notes for Agents

- `SKILL.md` is the primary instruction file for trigger handling and workflow
  decisions.
- The helper does not currently support `events search`, `--days`,
  organization/job-title contact fields, updates, reminders, or recurring-event
  creation.
- Deletions are permanent. Confirm the target UID before deleting.
- Use ISO 8601 datetimes such as `2026-02-10T14:00:00`.

## References

- `references/quick-reference.md` has copyable command examples.
- `references/troubleshooting.md` covers setup, connection, auth, and data
  errors.
- `references/caldav-library.md` documents the Python CalDAV/CardDAV library
  patterns used by the helper.
