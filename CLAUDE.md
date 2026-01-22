# Git Workflow Rules

## Branch Protection

**CRITICAL**: Direct push to `main` branch is PROHIBITED.

All changes MUST go through Pull Request review process:

1. Create feature branch from `main`
2. Commit changes to feature branch
3. Push feature branch to remote
4. Open Pull Request for review
5. Merge only after approval

## Rationale

• **Code Quality Gate**: PR review catches issues before they reach main
• **Audit Trail**: Every change has documented review and approval
• **Collaboration**: Team visibility into all modifications
• **Rollback Safety**: Clean history enables easier reversion

## Emergency Override

If absolutely necessary to push directly to main (production hotfix, critical security patch):

1. Document reason in commit message
2. Notify team immediately
3. Create retrospective PR for review

「守护主分支的纯净，就是守护生产环境的稳定。」

---

# Language Policy

## English as Primary Language

**RULE**: Please use English as the primary language for the project (including your PR description). Using Chinese in the code is not user-friendly for non-Chinese speakers, and the project is not very international.

This applies to:

• Pull Request titles and descriptions
• Code comments
• Documentation
• Commit messages (preferably)
• Variable and function names
• Error messages and user-facing text

## Rationale

• **Accessibility**: Makes the project welcoming to international contributors
• **Collaboration**: Enables global code review and discussion
• **Maintainability**: Future developers can understand the codebase regardless of language background
• **Professional Standards**: Aligns with open-source best practices

## Exceptions

Chinese may be used in:

• Internal team discussions (Discord, Slack, etc.)
• User-facing content specifically targeting Chinese users
• Translation files (i18n/l10n)

「开源的力量在于无界，语言的统一是第一步。」
