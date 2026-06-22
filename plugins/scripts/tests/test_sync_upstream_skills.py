import contextlib
import importlib.machinery
import importlib.util
import io
import json
import tarfile
import tempfile
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




class TestManifestIO(unittest.TestCase):
    def test_roundtrip_sorted(self):
        with tempfile.TemporaryDirectory() as d:
            sus.MANIFEST_PATH = Path(d) / "upstream-sources.json"
            sus.save_manifest({"skills": [
                {"name": "zeta"}, {"name": "alpha"},
            ]})
            data = sus.load_manifest()
            self.assertEqual([s["name"] for s in data["skills"]], ["alpha", "zeta"])

    def test_missing_file_is_empty(self):
        with tempfile.TemporaryDirectory() as d:
            sus.MANIFEST_PATH = Path(d) / "nope.json"
            self.assertEqual(sus.load_manifest(), {"skills": []})


class TestManifestSchema(unittest.TestCase):
    def setUp(self):
        from jsonschema import Draft7Validator
        schema_path = (
            Path(__file__).resolve().parents[2]
            / "schemas" / "upstream-sources.schema.json"
        )
        self.validator = Draft7Validator(json.loads(schema_path.read_text()))

    def _entry(self, **over):
        entry = {
            "name": "gog",
            "repo": "openclaw/gogcli",
            "branch": "main",
            "src_path": ".agents/skills/gog",
            "pinned_sha": "a" * 40,
            "content_hash": "sha256:" + "b" * 64,
            "local_only": ["agents/openai.yaml"],
        }
        entry.update(over)
        return entry

    def test_valid_manifest_passes(self):
        errors = list(self.validator.iter_errors({"skills": [self._entry()]}))
        self.assertEqual(errors, [])

    def test_bad_sha_rejected(self):
        bad = self._entry(pinned_sha="xyz")
        self.assertTrue(list(self.validator.iter_errors({"skills": [bad]})))

    def test_missing_required_rejected(self):
        bad = self._entry()
        del bad["content_hash"]
        self.assertTrue(list(self.validator.iter_errors({"skills": [bad]})))




def _make_tarball(prefix, files):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for rel, data in files.items():
            raw = data.encode()
            info = tarfile.TarInfo(name=f"{prefix}/{rel}")
            info.size = len(raw)
            tar.addfile(info, io.BytesIO(raw))
    return buf.getvalue()


class TestFetchSubtree(unittest.TestCase):
    def test_extracts_only_src_path(self):
        tarball = _make_tarball("openclaw-openclaw-abc123", {
            "skills/meme-maker/SKILL.md": "meme",
            "skills/meme-maker/scripts/run.sh": "echo hi",
            "skills/other/SKILL.md": "other",
            "README.md": "top",
        })
        orig = sus._download_tarball
        sus._download_tarball = lambda repo, sha: tarball
        try:
            with tempfile.TemporaryDirectory() as d:
                dest = Path(d) / "meme-maker"
                sus.fetch_subtree("openclaw/openclaw", "abc123",
                                  "skills/meme-maker", dest)
                self.assertEqual((dest / "SKILL.md").read_text(), "meme")
                self.assertEqual((dest / "scripts/run.sh").read_text(), "echo hi")
                self.assertFalse((dest / "other").exists())
        finally:
            sus._download_tarball = orig


class TestApplySkill(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        sus.SKILLS_DIR = Path(self.tmp.name) / "skills"
        self._orig_resolve = sus.resolve_tip_sha
        self._orig_fetch = sus.fetch_subtree

    def tearDown(self):
        sus.resolve_tip_sha = self._orig_resolve
        sus.fetch_subtree = self._orig_fetch
        self.tmp.cleanup()

    def _fake_fetch(self, files):
        def fetch(repo, sha, src_path, dest):
            import shutil
            if dest.exists():
                shutil.rmtree(dest)
            dest.mkdir(parents=True)
            for rel, data in files.items():
                p = dest / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(data)
        return fetch

    def test_generates_openai_when_missing_and_sets_hashes(self):
        sus.resolve_tip_sha = lambda repo, branch, path: "c" * 40
        sus.fetch_subtree = self._fake_fetch({
            "SKILL.md": "---\nname: gog\ndescription: Do gog.\n---\n",
        })
        entry = {
            "name": "gog", "repo": "openclaw/gogcli", "branch": "main",
            "src_path": ".agents/skills/gog", "pinned_sha": "",
            "content_hash": "", "local_only": ["agents/openai.yaml"],
        }
        sus.apply_skill(entry)
        dest = sus.SKILLS_DIR / "gog"
        self.assertTrue((dest / "agents/openai.yaml").exists())
        self.assertEqual(entry["pinned_sha"], "c" * 40)
        self.assertRegex(entry["content_hash"], r"^sha256:[0-9a-f]{64}$")

    def test_preserves_existing_openai_and_propagates_deletion(self):
        dest = sus.SKILLS_DIR / "gog"
        (dest / "agents").mkdir(parents=True)
        (dest / "agents/openai.yaml").write_text("CUSTOM")
        (dest / "stale.md").write_text("old")
        sus.resolve_tip_sha = lambda repo, branch, path: "d" * 40
        sus.fetch_subtree = self._fake_fetch({"SKILL.md": "new"})
        entry = {
            "name": "gog", "repo": "openclaw/gogcli", "branch": "main",
            "src_path": ".agents/skills/gog", "pinned_sha": "",
            "content_hash": "", "local_only": ["agents/openai.yaml"],
        }
        sus.apply_skill(entry)
        self.assertEqual((dest / "agents/openai.yaml").read_text(), "CUSTOM")
        self.assertFalse((dest / "stale.md").exists())
        self.assertTrue((dest / "SKILL.md").exists())


class TestAddSkill(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        sus.SKILLS_DIR = base / "skills"
        sus.MANIFEST_PATH = base / "upstream-sources.json"
        self._orig_resolve = sus.resolve_tip_sha
        self._orig_fetch = sus.fetch_subtree
        sus.resolve_tip_sha = lambda repo, branch, path: "e" * 40

        def fetch(repo, sha, src_path, dest):
            dest.mkdir(parents=True, exist_ok=True)
            (dest / "SKILL.md").write_text(
                "---\nname: gog\ndescription: Do gog.\n---\n"
            )
        sus.fetch_subtree = fetch

    def tearDown(self):
        sus.resolve_tip_sha = self._orig_resolve
        sus.fetch_subtree = self._orig_fetch
        self.tmp.cleanup()

    def test_add_writes_entry_and_openai(self):
        entry = sus.add_skill(
            "https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md"
        )
        self.assertEqual(entry["name"], "gog")
        data = sus.load_manifest()
        self.assertEqual([s["name"] for s in data["skills"]], ["gog"])
        self.assertTrue((sus.SKILLS_DIR / "gog/agents/openai.yaml").exists())

    def test_duplicate_rejected_without_force(self):
        url = "https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md"
        sus.add_skill(url)
        with self.assertRaises(SystemExit):
            sus.add_skill(url)

    def test_entry_validates_against_schema(self):
        from jsonschema import Draft7Validator
        schema_path = (
            Path(__file__).resolve().parents[2]
            / "schemas" / "upstream-sources.schema.json"
        )
        validator = Draft7Validator(json.loads(schema_path.read_text()))
        sus.add_skill(
            "https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md"
        )
        self.assertEqual(list(validator.iter_errors(sus.load_manifest())), [])


class TestCheckSkill(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        sus.SKILLS_DIR = Path(self.tmp.name) / "skills"
        self._orig_resolve = sus.resolve_tip_sha
        self._orig_fetch = sus.fetch_subtree

    def tearDown(self):
        sus.resolve_tip_sha = self._orig_resolve
        sus.fetch_subtree = self._orig_fetch
        self.tmp.cleanup()

    def _vendor(self, body):
        dest = sus.SKILLS_DIR / "gog"
        dest.mkdir(parents=True, exist_ok=True)
        (dest / "SKILL.md").write_text(body)
        return dest

    def _entry(self, content_hash):
        return {
            "name": "gog", "repo": "openclaw/gogcli", "branch": "main",
            "src_path": ".agents/skills/gog", "pinned_sha": "f" * 40,
            "content_hash": content_hash, "local_only": ["agents/openai.yaml"],
        }

    def _fake_upstream(self, body):
        def fetch(repo, sha, src_path, dest):
            dest.mkdir(parents=True, exist_ok=True)
            (dest / "SKILL.md").write_text(body)
        sus.fetch_subtree = fetch
        sus.resolve_tip_sha = lambda repo, branch, path: "0" * 40

    def test_in_sync(self):
        dest = self._vendor("same")
        digest = sus.compute_content_hash(dest, ["agents/openai.yaml"])
        self._fake_upstream("same")
        self.assertEqual(sus.check_skill(self._entry(digest)), [])

    def test_local_drift(self):
        self._vendor("edited-locally")
        self._fake_upstream("edited-locally")
        # recorded hash is for different content
        stale = "sha256:" + "0" * 64
        self.assertIn("LOCAL_DRIFT", sus.check_skill(self._entry(stale)))

    def test_update_available(self):
        dest = self._vendor("v1")
        digest = sus.compute_content_hash(dest, ["agents/openai.yaml"])
        self._fake_upstream("v2-new-references-too")
        self.assertIn("UPDATE_AVAILABLE", sus.check_skill(self._entry(digest)))


class TestMainCheckExit(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        sus.SKILLS_DIR = base / "skills"
        sus.MANIFEST_PATH = base / "upstream-sources.json"
        self._orig_check = sus.check_skill

    def tearDown(self):
        sus.check_skill = self._orig_check
        self.tmp.cleanup()

    def _write_manifest(self):
        sus.save_manifest({"skills": [{
            "name": "gog", "repo": "openclaw/gogcli", "branch": "main",
            "src_path": ".agents/skills/gog", "pinned_sha": "a" * 40,
            "content_hash": "sha256:" + "b" * 64,
            "local_only": ["agents/openai.yaml"],
        }]})

    def _silent_main(self, argv):
        sink = io.StringIO()
        with contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
            return sus.main(argv)

    def test_check_clean_returns_zero(self):
        self._write_manifest()
        sus.check_skill = lambda entry: []
        self.assertEqual(self._silent_main(["check"]), 0)

    def test_check_drift_returns_one(self):
        self._write_manifest()
        sus.check_skill = lambda entry: ["UPDATE_AVAILABLE"]
        self.assertEqual(self._silent_main(["check"]), 1)


class TestParseSkillUrlEdges(unittest.TestCase):
    def test_rejects_repo_root_url(self):
        with self.assertRaises(ValueError):
            sus.parse_skill_url("https://github.com/owner/repo")

    def test_trailing_slash_normalized(self):
        got = sus.parse_skill_url(
            "https://github.com/openclaw/openclaw/tree/main/skills/meme-maker/"
        )
        self.assertEqual(got["name"], "meme-maker")
        self.assertEqual(got["src_path"], "skills/meme-maker")

    def test_blob_non_skill_md_uses_parent_dir(self):
        got = sus.parse_skill_url(
            "https://github.com/o/r/blob/main/skills/x/scripts/run.sh"
        )
        self.assertEqual(got["src_path"], "skills/x/scripts")


class TestContentHashMore(unittest.TestCase):
    def _make(self, root, files):
        for rel, data in files.items():
            p = root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(data)

    def test_removed_file_changes_hash(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = Path(a), Path(b)
            self._make(ra, {"SKILL.md": "x", "references/r.md": "y"})
            self._make(rb, {"SKILL.md": "x"})
            self.assertNotEqual(
                sus.compute_content_hash(ra, []),
                sus.compute_content_hash(rb, []),
            )

    def test_empty_dir_is_stable_and_formatted(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            digest = sus.compute_content_hash(Path(a), [])
            self.assertEqual(digest, sus.compute_content_hash(Path(b), []))
            self.assertRegex(digest, r"^sha256:[0-9a-f]{64}$")


class TestOpenaiYamlEdges(unittest.TestCase):
    def test_long_description_truncated(self):
        skill = "---\nname: x\ndescription: " + ("a" * 200) + "\n---\n"
        out = sus.generate_openai_yaml(skill, "x")
        self.assertIn("...", out)
        for line in out.splitlines():
            if line.strip().startswith("short_description:"):
                value = line.split(":", 1)[1].strip().strip('"')
                self.assertLessEqual(len(value), 120)

    def test_quotes_and_backslashes_escaped(self):
        skill = '---\nname: x\ndescription: he said \\ and "hi"\n---\n'
        out = sus.generate_openai_yaml(skill, "x")
        self.assertIn('\\"', out)
        self.assertIn("\\\\", out)

    def test_display_name_title_cased(self):
        skill = "---\nname: foo-bar-baz\ndescription: d\n---\n"
        out = sus.generate_openai_yaml(skill, "foo-bar-baz")
        self.assertIn("Foo Bar Baz", out)


class TestFetchSubtreeErrors(unittest.TestCase):
    def setUp(self):
        self._orig = sus._download_tarball

    def tearDown(self):
        sus._download_tarball = self._orig

    def test_no_matching_files_raises(self):
        tb = _make_tarball("o-r-sha", {"README.md": "top", "skills/other/SKILL.md": "x"})
        sus._download_tarball = lambda repo, sha: tb
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(RuntimeError):
                sus.fetch_subtree("o/r", "sha", "skills/meme-maker", Path(d) / "m")

    def test_path_traversal_member_refused(self):
        tb = _make_tarball("o-r-sha", {"skills/x/../../escape.txt": "evil"})
        sus._download_tarball = lambda repo, sha: tb
        with tempfile.TemporaryDirectory() as d:
            dest = Path(d) / "nested" / "x"
            with self.assertRaises(RuntimeError):
                sus.fetch_subtree("o/r", "sha", "skills/x", dest)
            self.assertFalse((Path(d) / "escape.txt").exists())


class TestResolveTipSha(unittest.TestCase):
    def setUp(self):
        self._orig = sus._gh

    def tearDown(self):
        sus._gh = self._orig

    def test_empty_commits_raises(self):
        class R:
            stdout = "[]"
        sus._gh = lambda args, text: R()
        with self.assertRaises(RuntimeError):
            sus.resolve_tip_sha("o/r", "main", "skills/x")

    def test_commit_missing_sha_raises(self):
        class R:
            stdout = '[{"not_sha": 1}]'
        sus._gh = lambda args, text: R()
        with self.assertRaises(SystemExit):
            sus.resolve_tip_sha("o/r", "main", "skills/x")

    def test_non_list_response_raises(self):
        class R:
            stdout = '{"message": "Not Found"}'
        sus._gh = lambda args, text: R()
        with self.assertRaises(SystemExit):
            sus.resolve_tip_sha("o/r", "main", "skills/x")


class TestAddForce(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        sus.SKILLS_DIR = base / "skills"
        sus.MANIFEST_PATH = base / "upstream-sources.json"
        self._orig_resolve = sus.resolve_tip_sha
        self._orig_fetch = sus.fetch_subtree
        sus.resolve_tip_sha = lambda repo, branch, path: "e" * 40

        def fetch(repo, sha, src_path, dest):
            dest.mkdir(parents=True, exist_ok=True)
            (dest / "SKILL.md").write_text("---\nname: gog\ndescription: d\n---\n")
        sus.fetch_subtree = fetch

    def tearDown(self):
        sus.resolve_tip_sha = self._orig_resolve
        sus.fetch_subtree = self._orig_fetch
        self.tmp.cleanup()

    def test_force_readd_replaces_entry(self):
        url = "https://github.com/openclaw/gogcli/blob/main/.agents/skills/gog/SKILL.md"
        sus.add_skill(url)
        sus.add_skill(url, force=True)
        names = [s["name"] for s in sus.load_manifest()["skills"]]
        self.assertEqual(names, ["gog"])


class TestApplyCmd(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        sus.SKILLS_DIR = base / "skills"
        sus.MANIFEST_PATH = base / "upstream-sources.json"
        self._orig_apply = sus.apply_skill
        self.applied = []
        sus.apply_skill = lambda entry: self.applied.append(entry["name"])
        sus.save_manifest({"skills": [
            {"name": "gog", "repo": "o/r", "branch": "main", "src_path": "p",
             "pinned_sha": "a" * 40, "content_hash": "sha256:" + "b" * 64,
             "local_only": ["agents/openai.yaml"]},
            {"name": "yeet", "repo": "o/r2", "branch": "main", "src_path": "p2",
             "pinned_sha": "c" * 40, "content_hash": "sha256:" + "d" * 64,
             "local_only": ["agents/openai.yaml"]},
        ]})

    def tearDown(self):
        sus.apply_skill = self._orig_apply
        self.tmp.cleanup()

    def _silent_main(self, argv):
        sink = io.StringIO()
        with contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
            return sus.main(argv)

    def test_apply_no_args_returns_one(self):
        self.assertEqual(self._silent_main(["apply"]), 1)
        self.assertEqual(self.applied, [])

    def test_apply_all_visits_every_entry(self):
        self.assertEqual(self._silent_main(["apply", "--all"]), 0)
        self.assertEqual(sorted(self.applied), ["gog", "yeet"])

    def test_apply_named_subset(self):
        self.assertEqual(self._silent_main(["apply", "gog"]), 0)
        self.assertEqual(self.applied, ["gog"])


class TestPureLocalDrift(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        sus.SKILLS_DIR = Path(self.tmp.name) / "skills"
        self._orig_resolve = sus.resolve_tip_sha
        self._orig_fetch = sus.fetch_subtree

    def tearDown(self):
        sus.resolve_tip_sha = self._orig_resolve
        sus.fetch_subtree = self._orig_fetch
        self.tmp.cleanup()

    def test_only_local_drift_when_upstream_matches_recorded(self):
        dest = sus.SKILLS_DIR / "gog"
        dest.mkdir(parents=True)
        (dest / "SKILL.md").write_text("locally-edited")
        # upstream content equals the recorded hash; local differs from recorded
        upstream_body = "pristine-upstream"

        def fetch(repo, sha, src_path, d):
            d.mkdir(parents=True, exist_ok=True)
            (d / "SKILL.md").write_text(upstream_body)
        sus.fetch_subtree = fetch
        sus.resolve_tip_sha = lambda repo, branch, path: "0" * 40
        tmpdir = Path(self.tmp.name) / "u"
        fetch("", "", "", tmpdir)
        recorded_hash = sus.compute_content_hash(tmpdir, ["agents/openai.yaml"])
        entry = {
            "name": "gog", "repo": "o/r", "branch": "main", "src_path": "p",
            "pinned_sha": "f" * 40, "content_hash": recorded_hash,
            "local_only": ["agents/openai.yaml"],
        }
        self.assertEqual(sus.check_skill(entry), ["LOCAL_DRIFT"])


if __name__ == "__main__":
    unittest.main()
