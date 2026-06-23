---
name: paperless-ngx
description: Manage documents in Paperless-ngx document management system. Use when the user asks to "upload document", "search paperless", "find document", "add to paperless", "tag document", "manage correspondents", "organize documents", "archive document", "export document", "delete document", or mentions Paperless-ngx, document management, OCR, or paperless office.
---

# Paperless-ngx

## Purpose

This skill provides **read-write** access to a self-hosted Paperless-ngx instance for document management with OCR. Paperless-ngx transforms physical documents into a searchable online archive with full-text search, tagging, and metadata management.

**Core capabilities:**
- Upload documents with auto-OCR and metadata extraction
- Search documents by content, tags, correspondent, or date
- Manage tags, correspondents, and document types
- Update document metadata (title, tags, correspondent, dates)
- Archive and export operations
- Delete documents (with confirmation)
- Bulk operations on multiple documents

**Primary use case:** Maintain a searchable digital archive of all documents with powerful organization and retrieval capabilities.

## Setup

### Prerequisites
- Paperless-ngx instance running and accessible
- API token generated from Paperless-ngx UI
- `curl` and `jq` installed

### Credential Configuration

Configure these values in plugin userConfig. The hook writes
`${XDG_CONFIG_HOME:-~/.config}/lab-paperless/config.env` with mode `600`.
`~/.lab/.env` remains a fallback during migration:

```bash
# Paperless-ngx - Document management system
PAPERLESS_URL="https://paperless.example.com"
PAPERLESS_API_TOKEN="<your_api_token>"
```

`PAPERLESS_API_KEY` and `PAPERLESS_TOKEN` are accepted as local aliases when
`PAPERLESS_API_TOKEN` is unset.

**To generate an API token:**
1. Log into your Paperless-ngx instance
2. Go to Settings → My Profile
3. Click "Create Token" under "API Tokens"
4. Copy the generated token
5. Add the token to plugin userConfig, or to `.env` as a local fallback

**Security:**
- Generated config and `.env` files are local-only (never commit)
- Set permissions: `chmod 600 ~/.lab/.env`
- Token has same permissions as your user account

## Commands

All commands return JSON output for LLM parsing. Scripts source credentials from
the generated plugin config automatically.

Resolve `SKILL_DIR` to the directory containing this `SKILL.md`, then run the
helpers through that path:

```bash
SKILL_DIR="<paperless-ngx-skill-dir>"
```

### Document Operations

**Upload a document:**
```bash
bash "$SKILL_DIR/scripts/paperless-api.sh" upload /path/to/document.pdf
bash "$SKILL_DIR/scripts/paperless-api.sh" upload scan.jpg --title "Receipt" --tags "expense,2024"
bash "$SKILL_DIR/scripts/paperless-api.sh" upload contract.pdf --correspondent "Acme Corp" --document-type "Contract"
```

**Search documents:**
```bash
bash "$SKILL_DIR/scripts/paperless-api.sh" search "invoice"
bash "$SKILL_DIR/scripts/paperless-api.sh" search "meeting notes" --limit 10
bash "$SKILL_DIR/scripts/paperless-api.sh" search "2024" --tags "tax"
bash "$SKILL_DIR/scripts/paperless-api.sh" search --correspondent "John Doe"
```

**List documents:**
```bash
bash "$SKILL_DIR/scripts/paperless-api.sh" list
bash "$SKILL_DIR/scripts/paperless-api.sh" list --limit 20
bash "$SKILL_DIR/scripts/paperless-api.sh" list --ordering "-created"
```

**Get document details:**
```bash
bash "$SKILL_DIR/scripts/paperless-api.sh" get <document-id>
```

**Download/export document:**
```bash
bash "$SKILL_DIR/scripts/paperless-api.sh" download <document-id>
bash "$SKILL_DIR/scripts/paperless-api.sh" download <document-id> --output /path/to/save.pdf
```

**Update document:**
```bash
bash "$SKILL_DIR/scripts/paperless-api.sh" update <document-id> --title "New Title"
bash "$SKILL_DIR/scripts/paperless-api.sh" update <document-id> --add-tags "urgent,reviewed"
bash "$SKILL_DIR/scripts/paperless-api.sh" update <document-id> --correspondent "Jane Smith"
bash "$SKILL_DIR/scripts/paperless-api.sh" update <document-id> --document-type "Invoice"
bash "$SKILL_DIR/scripts/paperless-api.sh" update <document-id> --archive-serial-number "2024-001"
```

**Delete document:**
```bash
bash "$SKILL_DIR/scripts/paperless-api.sh" delete <document-id>  # Prompts for confirmation
```

### Tag Management

**List tags:**
```bash
bash "$SKILL_DIR/scripts/tag-api.sh" list
bash "$SKILL_DIR/scripts/tag-api.sh" list --ordering "name"
```

**Create tag:**
```bash
bash "$SKILL_DIR/scripts/tag-api.sh" create "project-alpha"
bash "$SKILL_DIR/scripts/tag-api.sh" create "urgent" --color "#ff0000"
```

**Get tag details:**
```bash
bash "$SKILL_DIR/scripts/tag-api.sh" get <tag-id>
```

**Update tag:**
```bash
bash "$SKILL_DIR/scripts/tag-api.sh" update <tag-id> --name "new-name"
bash "$SKILL_DIR/scripts/tag-api.sh" update <tag-id> --color "#00ff00"
```

**Delete tag:**
```bash
bash "$SKILL_DIR/scripts/tag-api.sh" delete <tag-id>  # Prompts for confirmation
```

### Correspondent Management

**List correspondents:**
```bash
bash "$SKILL_DIR/scripts/correspondent-api.sh" list
```

**Create correspondent:**
```bash
bash "$SKILL_DIR/scripts/correspondent-api.sh" create "Acme Corporation"
```

**Get correspondent details:**
```bash
bash "$SKILL_DIR/scripts/correspondent-api.sh" get <correspondent-id>
```

**Update correspondent:**
```bash
bash "$SKILL_DIR/scripts/correspondent-api.sh" update <correspondent-id> --name "New Name"
```

**Delete correspondent:**
```bash
bash "$SKILL_DIR/scripts/correspondent-api.sh" delete <correspondent-id>  # Prompts for confirmation
```

### Bulk Operations

**Bulk tag documents:**
```bash
bash "$SKILL_DIR/scripts/bulk-api.sh" add-tag <tag-id> --documents "1,2,3"
bash "$SKILL_DIR/scripts/bulk-api.sh" remove-tag <tag-id> --documents "1,2,3"
```

**Bulk set correspondent:**
```bash
bash "$SKILL_DIR/scripts/bulk-api.sh" set-correspondent <correspondent-id> --documents "1,2,3"
```

**Bulk set document type:**
```bash
bash "$SKILL_DIR/scripts/bulk-api.sh" set-document-type <type-id> --documents "1,2,3"
```

**Bulk delete documents:**
```bash
bash "$SKILL_DIR/scripts/bulk-api.sh" delete --documents "1,2,3"  # Prompts for confirmation
```

## Workflow

When the user asks about Paperless-ngx:

1. **"Upload this document to Paperless"**
   - Save file locally if needed
   - Use `upload` command with appropriate metadata
   - Optionally add tags, correspondent, document type
   - Paperless will auto-OCR and extract text

2. **"Find my 2024 tax documents"**
   - Use `search "tax" --tags "2024"` or similar query
   - Present results with ID, title, date, tags
   - User can request full details with `get <id>`

3. **"Tag all invoices from Acme Corp as paid"**
   - Search for documents: `search "invoice" --correspondent "Acme Corp"`
   - Create or find "paid" tag
   - Use bulk operation to add tag to results

4. **"Show me documents without tags"**
   - Use `list` with filter parameter
   - Present untagged documents
   - Suggest tagging workflow

5. **"Delete this old document"**
   - Confirm document ID with user
   - Ask for explicit confirmation
   - Use `delete <id>` command

6. **"Add a new supplier as correspondent"**
   - Use `correspondent-api.sh create "Supplier Name"`
   - Return correspondent ID for future document uploads

Step-by-step transcripts for upload, search-and-organize, and bulk-tagging
flows live in `references/quick-reference.md` under "Detailed Flows".

## Notes

### API Details

- **Authentication:** Token authentication via `Authorization: Token <token>` header
- **Base URL:** `/api/` endpoint
- **API Version:** Version 5 (specify via Accept header)
- **Rate limits:** No documented limits (self-hosted)
- **Pagination:** Uses `page` and `page_size` parameters

### Document Processing

Paperless-ngx automatically processes uploaded documents:
- OCR extraction (if not already text-based PDF)
- Thumbnail generation
- Metadata extraction (date, correspondent guessing)
- Full-text indexing for search

### Search Syntax

Search supports multiple query types:
- **Full-text:** `search "meeting notes"`
- **Tag filter:** `search --tags "work,urgent"`
- **Correspondent:** `search --correspondent "John Doe"`
- **Date range:** `search --created-after "2024-01-01"`
- **Document type:** `search --document-type "Invoice"`

### Tags vs Correspondents

- **Tags:** General-purpose labels (e.g., "urgent", "personal", "2024")
- **Correspondents:** People or organizations (e.g., "Acme Corp", "John Smith")
- **Document Types:** Categories of documents (e.g., "Invoice", "Contract", "Receipt")

All three provide different organizational axes for your documents.

### Destructive Operations

Delete operations require confirmation:
- **Delete document:** Permanently removes document and files
- **Delete tag:** Removes tag from all documents (documents remain)
- **Delete correspondent:** Removes from all documents (documents remain)

Always confirm with user before executing delete operations.

### Best Practices and Errors

Organization best practices (consistent tags, correspondents, document types,
archive serial numbers, search-before-upload) live in
`references/quick-reference.md` under "Best Practices". Common errors (401, 404,
400, connection refused) and full diagnostics live in
`references/troubleshooting.md`.

## Reference

- **Official Docs:** https://docs.paperless-ngx.com/
- **API Reference:** See `references/api-endpoints.md` for complete API documentation
- **Quick Reference:** See `references/quick-reference.md` for command examples
- **Troubleshooting:** See `references/troubleshooting.md` for common issues
- **Scripts:** `scripts/` relative to this skill directory

---
