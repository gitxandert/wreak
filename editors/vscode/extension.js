// Snaps a header typed on a carried-over indent back to column 0 when Enter is
// pressed, and makes the new line the block's first (single-tab) body line.
const vscode = require("vscode");

// Header-shaped, indented, with nothing after the colon except --flags.
const TYPED_HEADER = /^\s+(?:code|pseudo-?code|text):(?:\s+-\S.*)?\s*$/;

function activate(context) {
  const provider = {
    provideOnTypeFormattingEdits(document, position, ch) {
      if (ch !== "\n" || position.line === 0) return [];
      const header = document.lineAt(position.line - 1);
      if (!TYPED_HEADER.test(header.text)) return [];
      const body = document.lineAt(position.line);
      const indent = header.firstNonWhitespaceCharacterIndex;
      const bodyIndent = body.firstNonWhitespaceCharacterIndex;
      return [
        vscode.TextEdit.delete(new vscode.Range(header.lineNumber, 0, header.lineNumber, indent)),
        vscode.TextEdit.replace(new vscode.Range(body.lineNumber, 0, body.lineNumber, bodyIndent), "\t"),
      ];
    },
  };
  context.subscriptions.push(
    vscode.languages.registerOnTypeFormattingEditProvider({ language: "wreak" }, provider, "\n"),
  );
}

module.exports = { activate, deactivate() {} };
