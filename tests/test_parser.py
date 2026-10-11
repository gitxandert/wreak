import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "skill" / "wreak" / "scripts"))

from wreak_parse import parse  # noqa: E402


class ParserTests(unittest.TestCase):
    def test_three_families_and_flags(self):
        src = (
            "text:\n\tgoal\n\n"
            "pseudo-code: --language py\n\tif x:\n\t\ty()\n"
            "code: -l c++ --file src/a.cpp --name main --optional\n\tint main() {}\n"
        )
        r = parse(src)
        self.assertEqual([b["kind"] for b in r["blocks"]], ["text", "pseudo-code", "code"])
        text, pseudo, code = r["blocks"]
        self.assertEqual((text["line"], text["end_line"]), (1, 2))
        self.assertEqual(pseudo["language"], "python")
        self.assertEqual(pseudo["body"], "if x:\n\ty()")
        self.assertEqual(code["language"], "cpp")
        self.assertEqual(code["file"], "src/a.cpp")
        self.assertEqual(code["flags"], {"name": "main", "optional": True})
        self.assertEqual(r["warnings"], [])

    def test_equals_form_and_pseudocode_alias(self):
        r = parse("pseudocode: --language=TS\n\tx\n")
        self.assertEqual(r["blocks"][0]["kind"], "pseudo-code")
        self.assertEqual(r["blocks"][0]["language"], "typescript")

    def test_unknown_language_kept(self):
        r = parse("code: --language cobol\n\tDISPLAY 'HI'.\n")
        self.assertEqual(r["blocks"][0]["language"], "cobol")

    def test_comments_ignored_and_stray_is_implicit_text(self):
        r = parse("# note\nbuild me a thing\nplease\ncode:\n\tx = 1\n")
        kinds = [(b["kind"], b["implicit"]) for b in r["blocks"]]
        self.assertEqual(kinds, [("text", True), ("code", False)])
        self.assertEqual(r["blocks"][0]["body"], "build me a thing\nplease")
        self.assertEqual(len(r["warnings"]), 2)

    def test_not_a_header_without_space(self):
        r = parse("code:stuff\n")
        self.assertTrue(r["blocks"][0]["implicit"])

    def test_body_blank_lines_and_space_fallback(self):
        r = parse("code:\n\ta\n\n\t\tb\n\n\ntext:\n    hi\n      there\n")
        self.assertEqual(r["blocks"][0]["body"], "a\n\n\tb")
        self.assertEqual(r["blocks"][1]["body"], "hi\n  there")

    def test_empty_block_warns(self):
        r = parse("text:\ncode:\n\tx\n")
        self.assertIn("empty text block", r["warnings"][0])

    def test_example_parses_cleanly(self):
        r = parse((ROOT / "examples" / "todo-cli.wreak").read_text())
        self.assertEqual(r["warnings"], [])
        self.assertEqual(len(r["blocks"]), 4)


if __name__ == "__main__":
    unittest.main()
