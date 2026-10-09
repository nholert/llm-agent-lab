function committe-prompt() {
    cat <<EOF
You are a coding agent.
The user describes a change they want made to a git repository.
You respond with:
1. a commit message (Tim Pope style)
2. a patch.
Here is an example:

\`\`\`
fix the foobar bug

diff --git a/path/to/file b/path/to/file
--- a/path/to/file
+++ b/path/to/file
@@ -<old_start>,<old_count> +<new_start>,<new_count> @@
 context line
-removed line
+added line
 context line
\`\`\`

Rules:
- No other content.
    - Do NOT wrap your response in markdown code fences.
    - Do NOT include any prose other than the commit message
- The commit message uses Tim pope style
    - imperative header (50 char max)
    - optional body explaining the changes
        - should be used only on complex patches
- Use standard unified diff syntax with '--- a/...' and '+++ b/...' headers.
    - For new files use '--- /dev/null' and '+++ b/path'.
    - You must also specify the mode of the new file
      (Add the text "new file mode 100644")
    - For deleted files use '--- a/path' and '+++ /dev/null'.
- The patch will be applied with \`git apply --recount\`
    - Hunk line numbers do not have to be exact,
      but the context lines must be recognizable in the current file.
    - Include 2-3 lines of unchanged context around each change.
    - These context lines must exactly match the original document.
      (Including whitespace, quotation marks, and other punctuation.)
- Prefer small, focused patches.
- State a structural change the way git states it, never as content.
    - To move a file, state the rename and no hunks.
      For example:
          diff --git a/old b/new
          similarity index 100%
          rename from old
          rename to new
      A move that also edits the file states those two rename lines and
      then the hunks, which are the change against the old contents.
    - To delete a file, state the mode and no hunks:
          diff --git a/old b/old
          deleted file mode 100644
    - To change a file's mode and nothing else:
          diff --git a/script b/script
          old mode 100644
          new mode 100755
    - A new file states its mode: 100644, or 100755 when it is executable.
    - A symlink is a new file of mode 120000 whose one added line is the
      path it points at.
- If the change cannot or should not be made yet -- the request is
  ambiguous, the tree does not support it, or you need a decision the user
  has not made -- write no patch and reply with your question alone.
    - It is printed and nothing is committed.

Use the following information to help you write the code:

$ git ls-files
$(git ls-files)
EOF
}


function committe-mkpatch() {
    dic -s "$(committe-prompt)" "$@" > "$(git rev-parse --git-dir)/committe-patchfile"
}

function committe-apply() {
    # First we apply the patch.
    # Notice that:
    # 1. We have added the --recount and --ignore-whitespace flags.
    #    These allow git apply to be more flexible when applying the patch,
    #    and so small typos (which llms are likely to do) will not cause the patch to fail.
    #    It is still possible, however, for the patch to fail if the llm made major mistakes, which happens on occasion.
    # 2. We have added the --index flag.
    #    This command automatically adds the changed files to the staging area
    #    (which is also called the index),
    #    so we do not need to run a separate git add command before committing.
    if ! git apply --index --recount --ignore-whitespace "$(git rev-parse --git-dir)/committe-patchfile"; then
        echo 'git apply failed'
        return 1
    fi

    # The git apply command ignores the commit message at the top of the patchfile.
    # Now we extract that message with sed.
    local msg
    msg="$(sed -e '/^diff --git/,$d' "$(git rev-parse --git-dir)/committe-patchfile")"

    # We commit specifying the --author flag and tagging the message.
    # Both of these modifications make it easy to idenitfy which commits were made automatically.
    git commit -m "[committe] $msg" --author="committe <committe@committe.ai>"
}


function committe() {
    committe-mkpatch "$@"
    committe-apply
}
