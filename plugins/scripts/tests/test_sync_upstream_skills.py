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


import tempfile


class TestContentHash(unittest.TestCase):
    def _make(self, root, files):
        for rel, data in files.items():
            p = root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(data)

    def test_order_independent_and_deterministic(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = Path(a), Path(b)
            self._make(ra, {"SKILL.md": "x", "references/r.md": "y"})
            self._make(rb, {"references/r.md": "y", "SKILL.md": "x"})
            self.assertEqual(
                sus.compute_content_hash(ra, []),
                sus.compute_content_hash(rb, []),
            )

    def test_content_change_changes_hash(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = Path(a), Path(b)
            self._make(ra, {"SKILL.md": "x", "scripts/s.sh": "echo 1"})
            self._make(rb, {"SKILL.md": "x", "scripts/s.sh": "echo 2"})
            self.assertNotEqual(
                sus.compute_content_hash(ra, []),
                sus.compute_content_hash(rb, []),
            )

    def test_added_file_changes_hash(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = Path(a), Path(b)
            self._make(ra, {"SKILL.md": "x"})
            self._make(rb, {"SKILL.md": "x", "references/new.md": "z"})
            self.assertNotEqual(
                sus.compute_content_hash(ra, []),
                sus.compute_content_hash(rb, []),
            )

    def test_local_only_excluded(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = Path(a), Path(b)
            self._make(ra, {"SKILL.md": "x"})
            self._make(rb, {"SKILL.md": "x", "agents/openai.yaml": "interface: {}"})
            self.assertEqual(
                sus.compute_content_hash(ra, ["agents/openai.yaml"]),
                sus.compute_content_hash(rb, ["agents/openai.yaml"]),
            )

    def test_hash_format(self):
        with tempfile.TemporaryDirectory() as a:
            ra = Path(a)
            self._make(ra, {"SKILL.md": "x"})
            digest = sus.compute_content_hash(ra, [])
            self.assertRegex(digest, r"^sha256:[0-9a-f]{64}$")


class TestOpenaiYaml(unittest.TestCase):
    SKILL = (
        "---\n"
        'name: meme-maker\n'
        'description: Make memes from templates with captions.\n'
        "---\n\n# Meme Maker\n"
    )

    def test_frontmatter_parsed(self):
        fm = sus.parse_frontmatter(self.SKILL)
        self.assertEqual(fm["name"], "meme-maker")
        self.assertEqual(fm["description"], "Make memes from templates with captions.")

    def test_generates_interface_block(self):
        out = sus.generate_openai_yaml(self.SKILL, "meme-maker")
        self.assertIn("interface:", out)
        self.assertIn("display_name:", out)
        self.assertIn("short_description:", out)
        self.assertIn("default_prompt:", out)

    def test_no_frontmatter_falls_back_to_name(self):
        out = sus.generate_openai_yaml("# no frontmatter here", "yeet")
        self.assertIn("Yeet", out)


if __name__ == "__main__":
    unittest.main()
