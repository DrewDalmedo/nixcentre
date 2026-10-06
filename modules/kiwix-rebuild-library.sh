# Rebuilds the Kiwix library (the list of ZIM files kiwix-serve offers) from every
# complete .zim file in a folder. Half-copied or broken files are skipped and get
# picked up on a later run. The new library replaces the old one in one step, and
# kiwix-serve (--monitorLibrary) reloads it by itself.
#
# Usage: kiwix-rebuild-library ZIM_DIR LIBRARY_XML

zim_dir=$1
library=$2

empty_library='<library version="20110515">
</library>'

# kiwix-serve won't start without a library file.
if [[ ! -e $library ]]; then
  printf '%s\n' "$empty_library" >"$library"
  chmod 644 "$library"
fi

if [[ ! -d $zim_dir ]]; then
  echo "$zim_dir does not exist; keeping the current library." >&2
  exit 1
fi

# Build the new library next to the old one: kiwix-manage stores ZIM paths
# relative to the library file.
new=$(mktemp --dry-run "$library.XXXXXX")
trap 'rm -f "$new"' EXIT

added=0
skipped=0
while IFS= read -r -d '' zim; do
  if kiwix-manage "$new" add "$zim" >/dev/null 2>&1; then
    added=$((added + 1))
  else
    echo "Skipping $zim: incomplete or not a ZIM file (still copying?)"
    skipped=$((skipped + 1))
  fi
done < <(find -L "$zim_dir" -type f -iname '*.zim' ! -name '._*' -print0 | sort -z)

if [[ ! -e $new ]]; then
  printf '%s\n' "$empty_library" >"$new"
fi
chmod 644 "$new"

if cmp -s "$new" "$library"; then
  echo "Library unchanged: $added ZIM file(s), $skipped skipped."
else
  mv -f "$new" "$library"
  echo "Library updated: $added ZIM file(s), $skipped skipped."
fi
