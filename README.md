# ArchUnitRuby RAG test repository

[![CI](https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG/actions/workflows/ci.yml/badge.svg)](https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG/actions/workflows/ci.yml)

A deliberately small retrieval-augmented generation application used to exercise
[ArchUnitRuby](https://github.com/LukasNiessen/ArchUnitRuby) against a realistic layered Ruby
codebase.

The intended dependency flow is:

```text
api -> services, models
services -> retrieval, llm, models
retrieval -> models, shared
llm -> models, shared
models -> shared
shared -> nothing
```

Two source files intentionally violate that architecture:

- `lib/rag_pipeline/api/bad_shortcut.rb` reaches directly into `retrieval`.
- `lib/rag_pipeline/shared/leaky.rb` reaches upward into `services`.

Its executable architecture specs cover project discovery, source enumeration, dependency
extraction, ignore directives, internal/external classification, built-in edge mappers, layer
projection, cycle detection, immutable file scopes/moods, executable cycle/name/folder/path rules,
internal/external dependency rules, custom `FileInfo` predicates, the universal empty-test guard,
shared violation/result formatting, the framework-neutral assertion helper, the native RSpec
matcher, a complete named-layer policy, immutable graph querying and layer collapsing, all six graph
renderers, HTML export, forbidden slice dependencies, PlantUML validation and generation, and both
intentional violations. It also extracts real class/file metrics, verifies count measurements, and
calculates the complete LCOM cohesion family over the RAG service. Dependency-derived distance
metrics, an architectural zone guard, and a custom class metric exercise the remaining metric API.
Its fluent rules report and assert those violations directly. The intended
component architecture is checked in as [`docs/architecture.puml`](docs/architecture.puml) and is
executed against the real dependency graph on every CI run.

Run it next to a checkout named `ArchUnitRuby`:

```bash
bundle install
bundle exec rake
```

CI checks the fixture against the current ArchUnitRuby `main` branch on Ruby 3.3 and 4.0, including
Windows.
