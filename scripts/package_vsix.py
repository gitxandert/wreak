#!/usr/bin/env python3
"""Package editors/vscode into a .vsix without needing Node/vsce.

Usage: package_vsix.py [OUTPUT.vsix]   (default: dist/wreak-<version>.vsix)
"""
import json
import sys
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
EXT = ROOT / "editors" / "vscode"
FILES = ["package.json", "extension.js", "language-configuration.json", "syntaxes", "snippets"]

CONTENT_TYPES = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json"/>
  <Default Extension=".js" ContentType="application/javascript"/>
  <Default Extension=".vsixmanifest" ContentType="text/xml"/>
</Types>
"""


def manifest(pkg):
    e = lambda k, d="": escape(str(pkg.get(k, d)))
    return f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="{e('name')}" Version="{e('version')}" Publisher="{e('publisher')}"/>
    <DisplayName>{e('displayName')}</DisplayName>
    <Description xml:space="preserve">{e('description')}</Description>
    <Categories>{escape(",".join(pkg.get("categories", [])))}</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{escape(pkg['engines']['vscode'])}"/>
      <Property Id="Microsoft.VisualStudio.Code.ExtensionDependencies" Value=""/>
      <Property Id="Microsoft.VisualStudio.Code.ExtensionPack" Value=""/>
      <Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="workspace"/>
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
</PackageManifest>
"""


def main():
    pkg = json.loads((EXT / "package.json").read_text())
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dist" / f"wreak-{pkg['version']}.vsix"
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", CONTENT_TYPES)
        z.writestr("extension.vsixmanifest", manifest(pkg))
        for name in FILES:
            src = EXT / name
            for f in sorted([src] if src.is_file() else src.rglob("*")):
                if f.is_file():
                    z.write(f, "extension/" + f.relative_to(EXT).as_posix())
    print(out)


if __name__ == "__main__":
    main()
