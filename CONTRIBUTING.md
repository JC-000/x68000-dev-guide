# Contributing

Thanks for your interest in improving the Sharp X68000 Software Development Guide.

## Workflow

`master` is protected. All changes land via pull request:

1. Branch from `master`: `git checkout -b my-change`
2. Commit your changes and push the branch
3. Open a pull request against `master`
4. Merge once checks (if any) pass — no approvals are required

Direct pushes to `master` are blocked. Repository admins retain an emergency bypass.

## Branch protection on `master`

- Pull request required before merging
- Force-pushes blocked
- Branch deletion blocked

## Security

- Secret scanning and push protection are enabled — commits containing detected secrets will be rejected before they reach GitHub.
- Dependabot security updates are enabled for dependency advisories.

## Style

- Keep hardware claims verifiable against primary sources (datasheets, MAME source, inside.x68k.dev, Data Crystal).
- Note uncertainty explicitly rather than guessing.
- Code examples should assemble with HAS.X / link with HLK.X where practical.
