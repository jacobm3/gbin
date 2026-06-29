# git-setup.sh
#
# One-time global git configuration for a fresh machine/account. These settings
# land in ~/.gitconfig (that's what --global means) and apply to every repo this
# user touches. There is no shebang on purpose: run it explicitly with
#   bash git-setup.sh
# Prerequisites: git installed. Safe to re-run — each line just overwrites the
# same key, so the result is identical no matter how many times you run it.

# Set the author email stamped on every commit you make.
git config --global user.email jacobm3@gmail.com
# Set the author name stamped on every commit you make.
git config --global user.name "Jacob"
# Use the "store" credential helper: after you type an HTTPS git password/token
# once, git saves it in plaintext at ~/.git-credentials and reuses it, so future
# pushes/pulls don't prompt. (Convenient on a trusted personal box; the token is
# unencrypted on disk.)
git config --global credential.helper store
# When `git pull` has to integrate remote commits with local ones, merge instead
# of rebase. false = create a merge commit (the classic default) rather than
# replaying your commits on top of theirs. Keeps history honest about what
# happened, at the cost of occasional merge commits.
git config --global pull.rebase false
