# Skills and agents

Agent skills and subagents for a coding harness, with the generic and board-driven skills kept in
separate repos.

- **This repo** (`danielcherubini/skills`) holds the generic skills and the installer.
- **[archimedes-codes/skills](https://github.com/archimedes-codes/skills)** (the *kit*) holds the
  board-driven pipeline and the subagents it dispatches. It is included here as a git submodule at `kit/`.

## Layout

```
kit/                    submodule: archimedes-codes/skills (pipeline skills + agents)
agents/   -> kit/agents subagent definitions
skills/                 generic skills (real directories) and symlinks into kit/skills
install.sh              links skills/ and agents/ into the harness config directories
```

## Pipeline (in the kit)

```
research → specify → implement → review → finish
```

- **research** investigates before deciding. It writes no plan.
- **specify** writes the plan, and attaches it to the Task card.
- **implement** runs a plan, or a block of tasks in parallel waves.
- **review** and **finish** check the change, then merge it.

## Generic skills (this repo)

| Skill | Use it for |
|---|---|
| daily-summary | a standup or summary of what you did today |
| find-skills | finding and installing a skill for a task |
| github-profile | improving a GitHub profile page |
| release | a semver release, before tagging and pushing |
| review-pr | a deep review of an open PR, with inline suggestions |
| verification-before-completion | checking work before claiming it is done |
| write-readme | writing a project README |
| write-skills | creating or editing a skill |

## Install

```bash
git clone --recurse-submodules https://github.com/danielcherubini/skills.git ~/.agents
# or, if already cloned:
git -C ~/.agents submodule update --init --recursive
~/.agents/install.sh
```

`install.sh` must live in `~/.agents/`. It creates the links for the harness config directories and
leaves existing files alone.

## Adding a skill

A skill is a directory with a `SKILL.md`. Its frontmatter has only `name` and `description`. The name
matches the directory, and the description says *when* to use the skill, not what it does.
