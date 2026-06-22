import importlib.machinery
import importlib.util
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "sync-upstream-skills"
_loader = importlib.machinery.SourceFileLoader("sync_upstream_skills", str(TOOL))
_spec = importlib.util.spec_from_loader("sync_upstream_skills", _loader)
sus = importlib.util.module_from_spec(_spec)
_loader.exec_module(sus)


class TestParseSkillUrl(unittest.TestCase):
    def test_tree_url(self):
        got = sus.parse_skill_url(
            "https://github.com/openclaw/openclaw/tree/main/skills/meme-maker"
        )
        self.assertEqual(got, {
            "name": "meme-maker",
            "repo": "openclaw/openclaw",
            "branch": "main",
            "src_path": "skills/meme-maker",
        })

    def test_blob_url_strips_skill_md(self):
        got = sus.parse_skill_url(
            "https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md"
        )
        self.assertEqual(got["src_path"], ".agents/skills/gog")
        self.assertEqual(got["name"], "gog")

    def test_dot_prefixed_parent_segment(self):
        got = sus.parse_skill_url(
            "https://github.com/openai/skills/tree/main/skills/.curated/yeet"
        )
        self.assertEqual(got["src_path"], "skills/.curated/yeet")
        self.assertEqual(got["name"], "yeet")

    def test_rejects_non_github(self):
        with self.assertRaises(ValueError):
            sus.parse_skill_url("https://example.com/foo/bar")


if __name__ == "__main__":
    unittest.main()
