---
name: mermaid-diagrams
description: "Best practices and known pitfalls for writing Mermaid diagrams in this repo. Use this skill whenever writing or editing Mermaid diagrams in Markdown files, especially C4 architecture diagrams. Trigger on: 'create diagram', 'add mermaid', 'C4 diagram', 'architecture diagram', 'flowchart', or any task involving ```mermaid blocks."
---

# Mermaid Diagram Best Practices

## Linting

A `mermaid-lint` pre-commit hook runs `@probelabs/maid` against all `.md` files.
Always run it after writing diagrams:

```bash
pre-commit run mermaid-lint --all-files
```

Note: `maid` validates syntax but does **not** catch layout/rendering bugs (e.g. the
C4Container cross-boundary issue below). Visual verification in VS Code
(`bierner.markdown-mermaid` extension) or GitHub is still required.

---

## Diagram Type Selection

Use `flowchart` for all architecture diagrams in this repo. C4-specific diagram
types (`C4Context`, `C4Container`, `C4Component`) are avoided — they are less
readable and have a known layout engine bug with cross-boundary relationships.

| Diagram purpose | Use this type |
|-----------------|--------------|
| System context / actors | `flowchart TB` with subgraphs |
| Containers / services | `flowchart TB` with subgraphs |
| Components inside a service | `flowchart TB` with subgraphs |
| Secrets / data flow | `flowchart TD` |
| CI / deployment pipeline | `flowchart LR` or `TB` |

### Why not C4 diagram types?

`C4Container` (and sometimes `C4Component`) fails with
**"Cannot read properties of undefined (reading 'x')"** when `Rel()` calls cross
`System_Boundary` blocks. The layout engine does not register cross-boundary node
positions in the global coordinate space. `flowchart` with `subgraph` blocks
expresses the same structure without this bug.

---

## Forbidden Characters in C4 Quoted Strings

The C4 parser (C4Context, C4Component) breaks on these characters inside
**any quoted argument** — description, label, or technology field:

| Character | Problem | Replace with |
|-----------|---------|-------------|
| `(` `)` | Confuses argument parser | Remove, use `-` or `/` |
| `—` (em dash) | Breaks tokeniser | Use ` - ` (hyphen with spaces) |
| `→` (arrow) | Invalid token | Use `->` or plain text |
| `\n` | Not interpreted as newline in C4 strings | Write shorter single-line description |

Examples:

```mermaid
# BAD
Container(svc, "My Service", "Node.js (pnpm)", "Listens on port 3000 (loopback only)")
Rel(a, b, "Injects via", "op inject → .env")
System_Boundary(vm, "Production VM — Hyper-V")

# GOOD
Container(svc, "My Service", "Node.js / pnpm", "Listens on port 3000 on loopback only")
Rel(a, b, "Injects via", "op inject writes .env")
System_Boundary(vm, "Production VM - Hyper-V")
```

---

## C4 System_Ext Requires 3 Arguments

Always provide a description as the third argument. Two-argument calls can cause
undefined node sizing and layout failures.

```mermaid
# BAD
System_Ext(discord, "Discord API")

# GOOD
System_Ext(discord, "Discord API", "Messaging platform")
```

---

## Flowchart Node Shapes for C4-style L2 Diagrams

Use these shapes to visually distinguish node types in `flowchart` diagrams:

| C4 concept | Flowchart shape | Syntax |
|------------|----------------|--------|
| Person / actor | Stadium | `id(["Label"])` |
| Container / service | Round rect | `id["Label"]` |
| External system | Cylinder | `id[("Label")]` |
| Database | Cylinder | `id[("Label")]` |
