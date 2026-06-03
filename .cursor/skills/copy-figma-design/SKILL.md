---
name: copy-figma-design
description: >-
  Reads Figma frames via Figma Console MCP (Desktop Bridge + plugin API) and
  implements or aligns UI in code. Use when the user shares a figma.com URL,
  asks to match/copy/implement a Figma screen, paywall, or frame, or when REST
  Figma tools return 429 rate limits.
---

# Copy Figma Design

Implement or align UI from a Figma frame using **Figma Console MCP** (`user-figma-console`). No slash command — the user pastes a URL; the agent runs MCP tools.

## Prerequisites

1. **Figma Console MCP** enabled in Cursor with `FIGMA_ACCESS_TOKEN` (File content Read).
2. **Figma Desktop** open on the target file.
3. **Desktop Bridge** running: Plugins → Development → Figma Desktop Bridge (manifest at `~/.figma-console-mcp/plugin/manifest.json` after NPX install).

## Parse the URL

From `https://www.figma.com/design/{fileKey}/{name}?node-id=319-504`:

| Field | Example |
|-------|---------|
| fileKey | `T9wWCUOLSivhi6ndbbuVBj` |
| nodeId for MCP | `319:504` (replace `-` with `:` in node-id) |
| fileUrl | full design URL with `node-id` query param |

## Workflow (follow in order)

```
- [ ] figma_get_status (probe: true) — confirm WebSocket bridge connected
- [ ] figma_navigate — if file not active (only when bridge reports other file)
- [ ] figma_capture_screenshot — nodeId; plugin export (works when REST is down)
- [ ] figma_execute — read node tree + all TEXT .characters (bridge path)
- [ ] figma_get_file_data — optional; REST; may 429; use depth 2–3, verbosity standard
- [ ] Compare spec to codebase; implement in project stack (e.g. SwiftUI)
- [ ] Re-capture screenshot; list gaps vs Figma
```

## Tool selection

| Goal | Prefer | Fallback |
|------|--------|------------|
| Connection check | `figma_get_status` | — |
| Visual reference | `figma_capture_screenshot` | `figma_take_screenshot` (REST) |
| Copy, layout, text nodes | `figma_execute` on `figma.getNodeByIdAsync(nodeId)` | `figma_get_file_data` with `nodeIds` |
| Switch open bridged file | `figma_navigate` | User opens file + runs bridge |
| Write/edit Figma | `figma_execute` | Requires bridge |

**When REST returns 429:** Do not stop. Use **Desktop Bridge only** (`figma_capture_screenshot`, `figma_execute`). REST tools (`figma_get_file_data`, `figma_take_screenshot`) share Figma API rate limits.

## Extract spec from Figma (before coding)

Collect from screenshot + execute result:

- All **TEXT** `characters` (exact casing and punctuation)
- Frame size (e.g. 393×852), padding, `layoutMode`, `itemSpacing`
- Hierarchy: header, hero/timeline, plan cards, trust row, CTA, subtext under CTA, footer links
- Selected vs unselected states for toggles/cards
- Accent color usage (which words are emphasized)

Document gaps vs existing implementation before editing code.

## figma_execute pattern (read frame text)

```javascript
const node = await figma.getNodeByIdAsync('NODE_ID');
if (!node) return { error: 'Node not found' };

function collectText(n, out = []) {
  if (!n) return out;
  if (n.type === 'TEXT') out.push({ name: n.name, text: n.characters });
  if ('children' in n) n.children.forEach(c => collectText(c, out));
  return out;
}

return {
  id: node.id,
  name: node.name,
  width: 'width' in node ? node.width : null,
  height: 'height' in node ? node.height : null,
  texts: collectText(node),
};
```

For nested sections (timeline, plan picker), call `getNodeByIdAsync` on child frame IDs from the tree.

## Implementation rules (code)

- Match **exact** Figma strings unless product explicitly overrides.
- Place **pricing subtext directly under the primary CTA** when Figma shows it there.
- Reuse project theme tokens (e.g. `PaywallTheme.accent`) for light/dark via `@Environment(\.colorScheme)`.
- Prefer existing shared components over one-off layouts.
- Do not re-trigger side effects (e.g. notification prompts) on later paywall steps unless Figma flow requires it.

## Multi-MCP note

**Official Figma MCP** (`get_design_context`, `get_screenshot`) and **Figma Console MCP** can both work for design-to-code. When this skill applies, prefer Figma Console for deep text extraction and when REST is rate-limited.

## Verification

1. Screenshot captured for the target `nodeId`.
2. All visible strings accounted for in code or noted as intentional diffs.
3. CTA + subtext order matches Figma.
4. Light and dark frames checked if user provides both node IDs.
