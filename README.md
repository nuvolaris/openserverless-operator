<!--
  ~ Licensed to the Apache Software Foundation (ASF) under one
  ~ or more contributor license agreements.  See the NOTICE file
  ~ distributed with this work for additional information
  ~ regarding copyright ownership.  The ASF licenses this file
  ~ to you under the Apache License, Version 2.0 (the
  ~ "License"); you may not use this file except in compliance
  ~ with the License.  You may obtain a copy of the License at
  ~
  ~   http://www.apache.org/licenses/LICENSE-2.0
  ~
  ~ Unless required by applicable law or agreed to in writing,
  ~ software distributed under the License is distributed on an
  ~ "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  ~ KIND, either express or implied.  See the License for the
  ~ specific language governing permissions and limitations
  ~ under the License.
  ~
-->

# Apache OpenServerless Operator

In this readme there are information for developers.

We describe how to build and test the operator in our development environment

Please refer to the [website](https://openserverless.apache.org) for user information.

## How to build and use an operator image

Ensure you have satisfied the prerequisites below. Most notably, you need to use our development virtual machine and you
need write access to a GitHub repository.

Once you have satisfied the prerequisites, you can build an image you can use in the development machine.

Build an image with:

```shell
task build
```

Please note that it will build the image locally and push in an internal registry, even if it is name is
`ghcr.io/${GITHUB_USER}/openserverless-operator`.

To be able to build, the task `build` will commit and push all your changes and then build the operator from the public
sources in your local k3s.

It will also show the logs for the latest build.

You can then deploy it with:

```shell
task deploy
```

Once you have finished with development you can create a public image with `task publish` that will publish the tag and
trigger a creation of the image.

## Prerequisites

1. Please set up and use a development VM [as described here](https://github.com/apache/openserverless)

2. With VSCode, access the development VM, open the workspace `openserverless/openserverless.code-workspace` and then
   open a terminal with `operator` subproject: this will enable the `nix` environment with direnv (provided by the VM).

3. Create a fork of `github.com/apache/openserverless-operator`

4. Copy .env.dist in .env and put your GitHub username in it

5. Since the build requires you push your sources in your repo, you need the credentials to access it. The fastest way
   is
   to [create a personal token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

6. Now set up a remote to access your repo and set it as your default upstream branch.

```
git remote add fork https://<GITHUB_USERNAME>:<GITHUB_TOKEN>@github.com/<GITHUB_USERNAME>/openserverless-operator
git branch -u https://github.com/<GITHUB_USERNAME>/openserverless-operator
```

That's it. Now you can use `task build` to build the image.

7. Deploy the operator

To deploy a testing configuration of the Apache OpenServerless operator execute the command

```shell
task all
```

The operator instance will be configured applying the `test/k3s/whisk.yaml` template.
All the components are activated except TLS and MONITORING.

## PR Testing Workflow

The operator has a cross-repository testing pipeline that runs the full acceptance test suite from
`openserverless-testing` against an operator image built from a PR branch.

### How it works

```
openserverless-operator                        openserverless-testing
┌──────────────────────────┐                   ┌──────────────────────────────┐
│  trigger-testing.yaml    │  repository_      │  operator-pr-test.yaml       │
│                          │  dispatch         │                              │
│  /testing <platform>     │ ───────────────>  │  1. Clone PR branch          │
│  or workflow_dispatch    │  event_type:      │  2. Build operator image     │
│                          │  operator-pr-test │  3. Push to GHCR             │
│  Extracts PR details     │                   │  4. Patch opsroot.json       │
│  (ref, sha, repo)        │                   │  5. Deploy on <platform>     │
│                          │                   │  6. Run acceptance tests     │
└──────────────────────────┘                   └──────────────────────────────┘
```

### Triggering a test

There are two ways to trigger the test pipeline:

**1. PR comment (preferred)**

On any open PR, an authorized user (MEMBER, OWNER, or COLLABORATOR) can post a comment:

```
/testing k3s-amd
```

The platform argument is required (see the supported platforms table below).
A rocket reaction is added to the comment to confirm the dispatch was sent.

**2. Manual dispatch**

Go to Actions > "Trigger Testing" > "Run workflow" and provide:
- **pr_number**: the PR number to test
- **platform**: the target platform (see table below)

### Supported platforms

| Platform | Description | Status |
|---|---|---|
| `kind` | Local Docker-based cluster via `ops setup devcluster` | Active |
| `k3s-amd` | Single AMD VM with k3s installed via `ops setup server` | Active |
| `k3s-arm` | Single ARM VM with k3s installed via `ops setup server` | Active |
| `k8s` | Generic Kubernetes cluster accessed via kubeconfig | Active |
| `mk8s` | MicroK8s on Azure VM | Disabled |
| `eks` | Amazon EKS cluster | Disabled |
| `aks` | Azure AKS cluster | Disabled |
| `gke` | Google GKE cluster | Disabled |
| `osh` | OpenShift on GCP | Disabled |

### What happens on the testing side

Once dispatched, `openserverless-testing` receives the event and:

1. **Clones the operator PR branch** (with submodules) from the fork repository
2. **Builds a Docker image** from the PR source and pushes it to `ghcr.io/<owner>/openserverless-testing:pr-<number>-<short-sha>`
3. **Patches `opsroot.json`** to point the operator image to the freshly built PR image
4. **Deploys** the operator on the specified platform using `tests/1-deploy.sh`
5. **Runs the acceptance test suite**: system Redis, FerretDB, Postgres, MinIO, login, static, user-level services, and runtime tests

### Payload

The dispatch sends the following data to the testing repo:

| Field | Description |
|---|---|
| `pr_number` | The PR number being tested |
| `pr_ref` | The head branch name of the PR |
| `pr_sha` | The head commit SHA of the PR |
| `operator_repo` | Full name of the fork repo (e.g. `user/openserverless-operator`) |
| `platform` | Target platform (e.g. `k3s-amd`) |

### Required secrets

| Secret | Repository | Purpose |
|---|---|---|
| `OPENSERVERLESS_TESTING_PAT` | openserverless-operator | PAT with `repo` scope on the testing repo, used to send the `repository_dispatch` event. The default `GITHUB_TOKEN` cannot dispatch to external repositories. |
| `OP_SERVICE_ACCOUNT_TOKEN` | openserverless-testing | 1Password service account token to load test infrastructure secrets (SSH keys, kubeconfigs, API hosts). |
| `NGROK_TOKEN` | openserverless-testing | Ngrok authentication for tunnel access during tests. |

### The `olaris` submodule (openserverless-task)

The operator includes `openserverless-task` as a git submodule at `olaris/`. This submodule contains the
task definitions and `opsroot.json` that the `ops` CLI uses to discover images and configuration (including
the operator image reference).

During PR testing, the workflow sets `OPS_ROOT` to the submodule path, so `ops` uses the task definitions
and `opsroot.json` bundled with the PR branch. The workflow then patches `opsroot.json` to replace the
operator image with the one built from the PR.

#### Pointing to a fork or branch of openserverless-task

To test the operator with a specific version or fork of `openserverless-task`, update the submodule
reference in your PR branch:

```shell
# Point the submodule to a different remote (e.g. your fork)
git config submodule.olaris.url https://github.com/<your-user>/openserverless-task.git

# Fetch and checkout the desired branch
cd olaris
git fetch origin
git checkout <branch-or-tag>
cd ..

# Stage and commit the submodule pointer change
git add olaris
git commit -m "test: point olaris submodule to <your-user>/openserverless-task@<branch>"
```

When the PR testing workflow clones this branch with `--recurse-submodules`, it will pick up the
fork/branch you configured. This allows testing operator changes alongside task definition changes
in a single PR cycle.

To restore the submodule to the upstream default:

```shell
git config submodule.olaris.url https://github.com/apache/openserverless-task.git
cd olaris && git checkout main && cd ..
git add olaris
git commit -m "chore: restore olaris submodule to upstream"
```

