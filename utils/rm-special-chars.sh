# rm-special-chars.sh -- rename files in the current directory so their names
# contain only "safe" characters.
#
# What it does: looks at every regular file directly inside the current
# directory (not subdirectories) and, for any file whose name contains a
# character outside [letters, digits, dot, underscore, hyphen], replaces each
# such character with an underscore and renames the file. Files whose names are
# already clean are left untouched.
#
# Example: "my report (final).txt"  ->  "my_report__final_.txt"
#
# How to run it:
#   cd /the/directory/you/want/to/clean
#   sh rm-special-chars.sh
# (No shebang; run it with sh/bash. It acts on the current directory only.)
#
# Prerequisites: find, sort, sed, dirname, basename, mv (all standard).
# Safety notes: it uses -print0 / -z / read -d '' so filenames containing
# spaces or newlines are handled correctly. `mv -v` is verbose so you see each
# rename. There is no collision check: if two different names clean to the same
# result, the second mv could overwrite the first -- review output if unsure.
#
# Pipeline / loop, explained:
#   find . -maxdepth 1 -type f   : list regular files in this dir only
#   -print0                      : separate names with a NUL byte (\0) instead
#                                  of a newline, so odd filenames stay intact
#   | sort -z                    : sort that NUL-separated list (-z = NUL-aware)
#   | while ... read -r -d $'\0' : read one NUL-separated name at a time into $f
find . -maxdepth 1 -type f -print0 | sort -z | \
while IFS= read -r -d $'\0' f; do 
    # Split the path into its directory part and its filename part.
    # dirname gives the containing directory (e.g. "." for this dir).
    dir=$(dirname "$f")
    # basename gives just the filename (e.g. "bad name.txt").
    base=$(basename "$f")
    # Build a cleaned filename:
    #   sed 's/[^a-zA-Z0-9._-]/_/g'
    #     [^...] = match any character NOT in the listed set
    #     a-zA-Z0-9._-  = the allowed set: letters, digits, dot, underscore,
    #                     hyphen (the hyphen is last so it's a literal '-',
    #                     not a range)
    #     /_/    = replace each disallowed character with an underscore
    #     g      = do it for every match in the name, not just the first
    newbase=$(echo "$base" | sed 's/[^a-zA-Z0-9._-]/_/g')
    # Only rename if cleaning actually changed something (avoids no-op moves).
    if [[ "$base" != "$newbase" ]]; then
        # -v prints "old -> new" so you can see what was renamed.
        mv -v "$f" "$dir/$newbase"
    fi
done

