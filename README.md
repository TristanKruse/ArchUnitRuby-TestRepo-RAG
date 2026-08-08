# ArchUnitRuby RAG test repository

A deliberately small retrieval-augmented generation application used to exercise ArchUnitRuby
against a realistic layered Ruby codebase.

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

The first executable architecture spec covers project discovery and source enumeration. As the
ArchUnitRuby fluent API grows, this same repository will gain rules that detect the intentional
violations end to end.

Run it next to a checkout named `ArchUnitRuby`:

```bash
bundle install
bundle exec rake
```
