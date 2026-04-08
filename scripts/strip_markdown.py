#!/usr/bin/env python3
"""Strip markdown formatting from text for TTS output.

Usage:
    echo "**bold** text" | python strip_markdown.py
    cat file.md | python strip_markdown.py
"""

import html
import re
import sys
import unicodedata

import mistune
from mistune.plugins.formatting import strikethrough as strikethrough_plugin


class PlainTextRenderer(mistune.HTMLRenderer):
    """Render markdown as plain text suitable for TTS."""

    def text(self, text):
        return text

    def emphasis(self, text):
        return text

    def strong(self, text):
        return text

    def codespan(self, text):
        return ""

    def block_code(self, code, info=None):
        return ""

    def link(self, text, url, title=None):
        return text or ""

    def image(self, alt, url, title=None):
        return alt or ""

    def heading(self, text, level, **attrs):
        return text + ". "

    def paragraph(self, text):
        return text + " "

    def list(self, text, ordered, **attrs):
        return text

    def list_item(self, text, **attrs):
        return text.strip() + ". "

    def thematic_break(self):
        return ""

    def block_quote(self, text):
        return text

    def linebreak(self):
        return " "

    def softbreak(self):
        return " "

    def block_html(self, html_content):
        return ""

    def inline_html(self, html_content):
        return ""

    def strikethrough(self, text):
        return text


def strip_markdown(text: str) -> str:
    """Convert markdown to plain text for TTS."""
    # Remove bare URLs
    text = re.sub(r"https?://[^\s)]+", "", text)

    # Remove file paths
    text = re.sub(r"`[~/][^`]+`", "", text)
    text = re.sub(r"(?:^|\s)~/[a-zA-Z0-9_./-]+", " ", text)
    text = re.sub(r"(?:^|\s)/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_./-]*", " ", text)

    # Remove tables
    text = re.sub(r"^\|.*\|$", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*\|[-:\s|]+\|\s*$", "", text, flags=re.MULTILINE)

    # Parse with custom renderer
    renderer = PlainTextRenderer()
    md = mistune.create_markdown(
        renderer=renderer, plugins=[strikethrough_plugin]
    )
    result = md(text)

    # Clean artifacts
    result = re.sub(r"`", "", result)
    result = re.sub(r"\[\]|\(\)", "", result)
    result = re.sub(r"\s+", " ", result)

    # Remove emoji/symbols
    result = "".join(
        c
        for c in result
        if unicodedata.category(c) != "So" and not (0xFE00 <= ord(c) <= 0xFE0F)
    )

    # Decode HTML entities
    result = html.unescape(result)
    result = re.sub(r"\s+", " ", result)

    return result.strip()


def main():
    """Read from stdin, strip markdown, write to stdout."""
    text = sys.stdin.read()
    print(strip_markdown(text))


if __name__ == "__main__":
    main()
