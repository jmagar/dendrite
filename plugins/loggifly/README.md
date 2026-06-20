# LoggiFly

Operate LoggiFly Docker log alerting by editing its mounted `config.yaml`.
LoggiFly is not a queryable REST service; this plugin provides skill guidance
for alert patterns, notifications, container events, and guarded
`container_action` rules.

## Configuration

LoggiFly is configured in its own container-mounted YAML file, not through a
Dendrite setup hook. Use Docker mount inspection to find the host-side
`config.yaml`, back it up, edit it, validate YAML syntax, and watch container
logs for reload/match events.

## Skill

- `skills/loggifly/SKILL.md` — config reference, examples, verification steps,
  and destructive-action cautions.

## Verify

```bash
docker logs --tail 30 loggifly
```
