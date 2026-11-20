# Contributing

This guide explains how to propose a change to the lab.

## Before you start

Open an issue before a large change, so that the approach is agreed before the work. Small fixes can go straight to a pull request.

Report security vulnerabilities privately to devqs@quersystem.com, not in an issue.

## Development setup

Install Docker with Compose, Go and Node.js. Clone power-ens-wazuh and oscompliance-ens-wazuh next to this repository.

## Checks

```bash
make up && make status
```

For the distributed lab, run `make up` and `make status` in `distributed/`, and `make reset` before each test.

## Code

- Code, identifiers, comments, commit messages and pull requests are in English.
- Follow the conventions already in the repository. Clear names, small functions and explicit error handling come before comments.
- Write a comment only for what the code cannot say: an invariant, an external constraint or a workaround with its reference.
- Tests live in their own files.
- The files in `config/` come from wazuh-docker and OpenSearch Security under their own licenses, listed in `config/NOTICE`. Keep that notice up to date when you change them.
- Passwords and certificates are generated locally and never committed.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/) with a scope, in one line of at most 72 characters, imperative and lowercase:

```text
fix(install): wait for the rules of the release on workers
```

Types: feat, fix, refactor, perf, test, docs, build, ci, chore, style and revert.

## Pull requests

- One logical change per pull request, on a branch named `feat/<topic>` or `fix/<topic>`.
- The checks above pass.
- New behaviour comes with tests, and a bug fix with a test that fails without it.

## License

The project is licensed under AGPL-3.0-only, and Quer System Informática also offers it under a commercial license. To keep both possible, Quer System Informática needs the rights to every contribution. Before your first pull request is merged, sign the Quer System Informática contributor license agreement. Ask for it at devqs@quersystem.com.
