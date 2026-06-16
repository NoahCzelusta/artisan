# Issue Tracker: GitHub

Issues and product work for this repo live in GitHub Issues for `NoahCzelusta/artisan`. Use the `gh` CLI for issue operations.

## Conventions

- Create issues with `gh issue create --repo NoahCzelusta/artisan --title "..." --body "..."`.
- Read issues with `gh issue view <number> --repo NoahCzelusta/artisan --comments`.
- List issues with `gh issue list --repo NoahCzelusta/artisan --state open --json number,title,body,labels`.
- Comment with `gh issue comment <number> --repo NoahCzelusta/artisan --body "..."`.
- Apply labels with `gh issue edit <number> --repo NoahCzelusta/artisan --add-label "..."`.
- Close issues with `gh issue close <number> --repo NoahCzelusta/artisan --comment "..."`.

## When A Skill Says "Publish To The Issue Tracker"

Create a GitHub issue in `NoahCzelusta/artisan`.

Use the triage label mapping in `docs/agents/triage-labels.md`.

## When A Skill Says "Fetch The Relevant Ticket"

Run:

```bash
gh issue view <number> --repo NoahCzelusta/artisan --comments
```

## Migration Note

Historical local markdown issues were migrated from `.scratch/quick-edit-code-editor/issues/` and `.scratch/repo-scaffold/issues/` to GitHub Issues #1-#27 on 2026-06-16. Do not create new issue-tracker files under `.scratch/`.
