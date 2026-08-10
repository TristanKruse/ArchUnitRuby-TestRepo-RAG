# ArchUnitRuby RAG test repository

[![CI](https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG/actions/workflows/ci.yml/badge.svg)](https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG/actions/workflows/ci.yml)

A deliberately small retrieval-augmented generation application used to exercise
[ArchUnitRuby](https://github.com/LukasNiessen/ArchUnitRuby) against a realistic layered Ruby
codebase.

The intended dependency flow is:

```text
api -> services -> retrieval, llm, models
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
and both intentional violations. Its fluent rules report those violations directly as structured
data.

Run it next to a checkout named `ArchUnitRuby`:

```bash
bundle install
bundle exec rake
```

CI checks the fixture against the current ArchUnitRuby `main` branch on Ruby 3.3 and 4.0, including
Windows.
