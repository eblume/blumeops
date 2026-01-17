# blumeops

```
                    l0K                                k..:k.
                  .:...c.                            ;c....
                    ....'o                          x.....
                      ....k                        x....
                       ... l'                    'c....
                        ....,l                  o'....
                         .....x                k....
                          .....d.             c....
                            ... l            x....
                              .,.d         ;c.c'
                               'c':;      x',c.
                                .:,'o   .x.::.
                                 .;:.k ,:.c'
                                   ,c.c';:.
                                    .,.:;.
                                   ;'.c, l
                                  d',c..:.d.
                                 O.:;.  'c';c
                               ;c.c'     .:;.x
                              o',c.       .;:.k
                             x.::.          'c.l.
                         dOKl.c,             .c,'o
                   0l'...... ..'              .::.ocx.
                 'o ............              o .... :olx;
                x,ox;. ....... .k             ....,dKKo;..x
              'd,OXXXXk:. ...... ;            ;:dXOl;',';l;o;
             x,oXXXXXXXXXkc. ...              .lc,',':dKNNNx;x;
           ;o;0KXXXXXXXXXXXX0l.                .',ckNNNNNNNNNxco0d
          l,d0oOXKOKXXXXKXXXX0.                  kNNNNNNNNNNNNNXxloo::
             .OXxdXKOX0kXXXX0.                   .KNNNNNNNNNNXONX0o.
                ,OdxKldXXXXx.                     ,NNNNNNNNNNNKoc
                   :.OXXkKo                       .kNNNNNNNNXx.
                      ':0c                         .NdNkXkc
```

*Blue Mops* — GitOps for Erich Blume's personal computing environment.

## What is this?

Infrastructure-as-code for my tailnet (`tail8d86e.ts.net`). This repo contains
ansible playbooks, configuration, and automation for managing my personal
infrastructure.

This codebase was heavily co-authored by Claude Code, as an experiment in
LLM-assisted development. I want to include a personal note here that I don't
know entirely how I feel about LLMs in our current era, but it felt important
to learn.

## Development

### Pre-commit Hooks

This repo uses [pre-commit](https://pre-commit.com) for code quality and consistency. Install hooks with:

```bash
uvx pre-commit install
```

Run all hooks manually:

```bash
uvx pre-commit run --all-files
```

Hooks include:
- **General**: trailing whitespace, end-of-file fixer, large files, merge conflicts
- **Secrets**: [TruffleHog](https://github.com/trufflesecurity/trufflehog) for secret detection
- **YAML**: yamllint, ansible-lint
- **Python**: ruff (linting + formatting)
- **Shell**: shellcheck, shfmt
- **TOML**: taplo
- **JSON**: prettier

## Documentation

Detailed documentation lives in my personal zettelkasten, which is not included in this repository. You can view the docs with:

```bash
mise run zk-docs
```

The zettelkasten is private at time of writing. If you're interested in the documentation or have questions about this project, please reach out to blume.erich@gmail.com.
