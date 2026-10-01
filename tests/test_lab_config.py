"""Config and SPL validation for the SplunkHarbor lab.

No Splunk needed: these checks parse the shipped files and fail the
build when a detection, a config stanza or the compose stack breaks.
"""

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPL_DIR = ROOT / "spl"
CONF_DIR = ROOT / "configs" / "logharbor" / "local"

DETECTIONS = {
    "brute-force.spl": ["index=wineventlog", "EventCode=4625", "coalesce", "src_ip"],
    "encoded-powershell.spl": ["index=sysmon", "EventCode=1", "EncodedCommand"],
    "lateral-movement.spl": ["index=wineventlog", "EventCode=5140", "ShareName"],
    "persistence.spl": ["index=sysmon", "EventCode=13", "TargetObject"],
    "scheduled-tasks.spl": ["index=sysmon", "EventCode=1", "schtasks"],
}


def test_every_detection_exists_and_matches_its_index():
    for name, needles in DETECTIONS.items():
        text = (SPL_DIR / name).read_text()
        for needle in needles:
            assert needle in text, f"{name} missing {needle!r}"


def test_no_win_index_references_left():
    # the searches used index=win, but the shipped props/transforms route
    # into sysmon/wineventlog/powershell - searches would return nothing
    for path in list(SPL_DIR.glob("*.spl")) + [SPL_DIR / "triage-walkthrough.md"]:
        text = path.read_text()
        assert not re.search(r"index=win(?!\w)", text), f"{path.name} still uses index=win"


def test_conf_files_have_stanzas():
    for conf in CONF_DIR.glob("*.conf"):
        text = conf.read_text()
        assert re.search(r"^\[[^\]]+\]$", text, re.M), f"{conf.name} has no stanzas"


def test_savedsearches_cover_five_detections():
    text = (CONF_DIR / "savedsearches.conf").read_text()
    stanzas = re.findall(r"^\[([^\]]+)\]$", text, re.M)
    assert len(stanzas) == 5, f"expected 5 saved searches, found {len(stanzas)}"
    assert all(name.startswith("LH -") for name in stanzas)


def test_brute_force_saved_search_has_webhook():
    text = (CONF_DIR / "savedsearches.conf").read_text()
    assert "action.webhook = 1" in text
    assert "action.webhook.param.url" in text


def test_compose_mounts_existing_config_dir():
    compose = (ROOT / "docker-compose.yml").read_text()
    assert "configs/logharbor/local" in compose
    assert (ROOT / "configs" / "logharbor" / "local").is_dir()
    assert "changeme123" not in compose
    assert "LH_PASSWORD" in compose


def test_shell_scripts_are_valid_bash():
    for script in (ROOT / "setup").glob("*.sh"):
        subprocess.run(["bash", "-n", str(script)], check=True)


def test_env_example_uses_lh_password():
    text = (ROOT / ".env.example").read_text()
    assert "LH_PASSWORD=" in text


def test_hec_token_script_present():
    text = (ROOT / "setup" / "create-hec-token.sh").read_text()
    assert "http-event-collector" in text
    assert "LH_PASSWORD" in text
