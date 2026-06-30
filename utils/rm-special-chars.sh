# Rename files AND directories under the current dir, replacing any char
# that isn't a letter/digit/dot/underscore/dash with an underscore.
#
# -mindepth 1 : skip "." itself
# -depth      : process a directory's contents BEFORE the directory, so
#               renaming a parent doesn't invalidate paths to its children.
# (no -maxdepth, no -type f) : recurse fully and handle both files and dirs.
find . -mindepth 1 -depth -print0 | \
while IFS= read -r -d $'\0' f; do
    dir=$(dirname "$f")
    base=$(basename "$f")
    newbase=$(echo "$base" | sed 's/[^a-zA-Z0-9._-]/_/g')
    if [[ "$base" != "$newbase" ]]; then
        mv -v "$f" "$dir/$newbase"
    fi
done
