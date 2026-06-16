"""
Probe Patcher's public endpoints on a schedule and alert Slack on status
transitions. Last-known status per target lives in DynamoDB, so a sustained
outage pages once when it goes down and once when it recovers, not every run.
"""

import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone

import boto3

PROBE_TIMEOUT = 10
# Cloudflare 403s the default Python-urllib UA as a bot; identify ourselves instead.
USER_AGENT = "brainframe-monitor/1.0 (+https://github.com/liquidz00/Patcher)"
TARGETS = json.loads(os.environ["TARGETS"])
TABLE_NAME = os.environ["DDB_TABLE"]
WEBHOOK_PARAM = os.environ["SLACK_WEBHOOK_PARAM"]
STATS_URL = os.environ.get("STATS_URL", "")  # empty disables the freshness check
FRESH_MAX_AGE_HOURS = float(os.environ.get("FRESH_MAX_AGE_HOURS", "26"))

_table = boto3.resource("dynamodb").Table(TABLE_NAME)
_ssm = boto3.client("ssm")
_webhook_url = None  # cached across warm invocations


# A 3xx means the server answered, so treat it as alive rather than chasing
# the redirect (mcp.patcherctl.dev/mcp returns 307 by design).
class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


_opener = urllib.request.build_opener(_NoRedirect)


def _probe(target):
    """Return ``("up" | "down", reason)`` for a single endpoint."""
    req = urllib.request.Request(target["url"], headers={"User-Agent": USER_AGENT})
    try:
        with _opener.open(req, timeout=PROBE_TIMEOUT) as resp:
            code = resp.status
            body = resp.read(8192).decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        code, body = exc.code, ""
    except Exception as exc:
        return "down", f"request failed: {exc}"

    if not 200 <= code < 400:
        return "down", f"HTTP {code}"
    match = target.get("body_match")
    if match and match not in body:
        return "down", f"body missing {match!r}"
    return "up", f"HTTP {code}"


def _probe_freshness():
    """Return ``("up" | "down", reason)`` from the catalog's last-refresh age."""
    req = urllib.request.Request(STATS_URL, headers={"User-Agent": USER_AGENT})
    try:
        with _opener.open(req, timeout=PROBE_TIMEOUT) as resp:
            data = json.loads(resp.read())
    except Exception as exc:
        return "down", f"stats fetch failed: {exc}"

    stamp = data.get("last_refresh")
    if not stamp:
        return "down", "catalog reports no last_refresh"
    age_hours = (datetime.now(timezone.utc) - datetime.fromisoformat(stamp)).total_seconds() / 3600
    if age_hours > FRESH_MAX_AGE_HOURS:
        return "down", f"catalog stale: refreshed {age_hours:.0f}h ago"
    return "up", f"fresh ({age_hours:.0f}h ago)"


def _last_status(name):
    item = _table.get_item(Key={"target": name}).get("Item")
    return item["status"] if item else "up"  # assume healthy until proven otherwise


def _save_status(name, status, reason):
    _table.put_item(
        Item={
            "target": name,
            "status": status,
            "reason": reason,
            "updated": datetime.now(timezone.utc).isoformat(),
        }
    )


def _post_slack(text):
    global _webhook_url
    if _webhook_url is None:
        _webhook_url = _ssm.get_parameter(Name=WEBHOOK_PARAM, WithDecryption=True)["Parameter"]["Value"]

    payload = json.dumps({"text": text}).encode("utf-8")
    req = urllib.request.Request(
        _webhook_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    urllib.request.urlopen(req, timeout=PROBE_TIMEOUT)


def handler(event, context):
    results = [(target["name"], *_probe(target)) for target in TARGETS]
    if STATS_URL:
        results.append(("catalog freshness", *_probe_freshness()))

    transitions = []
    for name, status, reason in results:
        if status != _last_status(name):
            transitions.append((name, status, reason))
            _save_status(name, status, reason)

    if transitions:
        lines = [
            f"🔴 DOWN  `{name}`: {reason}" if status == "down" else f"✅ RECOVERED  `{name}`"
            for name, status, reason in transitions
        ]
        _post_slack("\n".join(lines))

    return {"checked": len(results), "transitions": len(transitions)}
