#!/bin/bash -
#
# new-github-repo.sh
#
# Create a brand-new GitHub repo via the API, then make a matching local repo,
# seed it with a README, and push the first commit.
#
# Usage:
#   GITHUB_TOKEN=<personal-access-token> ./new-github-repo.sh <repo-name>
#
# Prerequisites:
#   - curl and git installed.
#   - GITHUB_TOKEN env var set to a GitHub PAT with "repo" scope (used both to
#     authenticate the API call and embedded in the push URL).
#   - You are in the directory where you want the new local repo folder created;
#     this script makes a subdirectory named <repo-name> under the current dir.

# First positional argument = the name of the repo to create.
repo_name=$1
# GitHub account that will own the repo.
USER=jacobm3
# Guard: if no repo name was given, print an error to stderr (1>&2) and bail out.
# `test -z $repo_name` is true when the string is empty; the && chain only runs
# the echo+exit when that test passes.
test -z $repo_name && echo "Repo name required." 1>&2 && exit 1
# (Old/alternate form of the API call, kept for reference — intentionally disabled.)
#curl -u 'jacobm3' https://api.github.com/user/repos -d  "{\"name\":\"$repo_name\",\"token\":\"${GITHUB_TOKEN}\"}"
# Call the GitHub REST API to create the repo under the authenticated user.
#   -u "user:token"  HTTP basic auth — GitHub accepts a PAT as the password.
#   POST /user/repos creates a repo owned by the authenticated user.
#   -d '{...}'  sends a JSON body; the presence of -d makes this a POST.
#               Here it only sets the new repo's "name".
curl -u "${USER}:${GITHUB_TOKEN}" https://api.github.com/user/repos -d  "{\"name\":\"$repo_name\"}"
# Make a local directory for the repo (same name as the repo) and enter it.
mkdir $1
cd $1
# Seed a minimal README whose only content is the repo name as a markdown H1.
echo "# $1" >> README.md
# Turn the new directory into a git repository.
git init
# Stage the README so it will be part of the first commit.
git add README.md
# Record the first commit.
git commit -m "first commit"
# Point "origin" at the GitHub repo. The token is embedded in the URL so the
# push below authenticates without a separate prompt. (Token-in-URL gets written
# into .git/config in plaintext — fine for a private box, not for shared hosts.)
git remote add origin  https://${USER}:${GITHUB_TOKEN}@github.com/jacobm3/${1}.git
# Push the first commit and set "origin master" as the upstream (-u) so later
# bare `git push`/`git pull` know where to go.
git push -u origin master
# Cache HTTPS credentials for this repo so future operations don't re-prompt.
git config credential.helper store
