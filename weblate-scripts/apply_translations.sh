#!/bin/bash
CURRENT_DIRECTORY=`pwd`
SCRIPT_DIRECTORY=`dirname "$0"`
SCRIPT_NAME=`basename "$0"`
FILES="$SCRIPT_DIRECTORY/translation_list_%s.txt"
BRANCH=$2

function usage {
  echo "Usage: $SCRIPT_NAME [target] branchname"
  echo "Target:"
  echo "  update  Update translations"
  echo "  push    Push the updated translations"
  echo "  clean   Rollback the update (before pushing)"
  echo "Example:"
  echo "  $SCRIPT_NAME update stable-X"
  exit 1
}

function checkout() {
    git checkout $BRANCH
    if [[ $? != 0 ]]; then
      echo "Branch $BRANCH not found."
      return -1
    fi
    return 0
}

function update() {
  N=0
  for f in *; do
    FILE=`printf $FILES $f`
    if [[ -f $FILE ]]; then
      echo "Updating $f translations..."
      cd $f
      # Ensure that all commits from master are retrieved, since we'll update from it.
      git checkout master
      git pull --rebase origin master
      checkout
      if [[ $? != 0 ]]; then
        cd $CURRENT_DIRECTORY
        echo
        continue
      fi
      git pull --rebase origin $BRANCH
      if [[ $? != 0 ]]; then
        echo "Couldn't pull new changes."
        cd $CURRENT_DIRECTORY
        echo
        continue
      fi
      N=$((N+1))
      # Iterate on all paths from the list of components and checkout the changes from master on the translation
      # and on the source file translation
      PATHS=`awk -F';' 'NF && $0!~/^#/{print $2}' $FILE`
      for p in $PATHS; do
        if [[ -f $p ]]; then
          git checkout master -- $p

          p_prop="${p/.properties/_*.properties}"
          p_xml="${p/.xml/.*.xml}"

          # we don't want the checkout to fail if the pattern does not exist in master
          # (could be the case if the component does not have any translation yet on master)
          # Note that some not nice error logs might still occur, such as:
          # error: pathspec 'xwiki-platform-core/xwiki-platform-captcha/xwiki-platform-captcha-ui/src/main/resources/XWiki/Captcha/Translations.*.xml' did not match any file(s) known to git.
          # Those are not nice to have, but not harmful.
          if [[ $p != $p_prop ]]; then
            git checkout master -- $p_prop || true
          elif [[ $p != $p_xml ]]; then
            git checkout master -- $p_xml || true
          fi
        fi
      done
      cd $CURRENT_DIRECTORY
      echo
    fi
  done
  echo "$N project(s) updated."
  echo "After reviewing the changes, you can run '$SCRIPT_NAME push $BRANCH' "
  echo "to commit and push the changes."
}

function push() {
  for f in *; do
    FILE=`printf $FILES $f`
    if [[ -f $FILE ]]; then
      echo "Pushing $f translations..."
      cd $f
      checkout
      if [[ $? != 0 ]]; then
        cd $CURRENT_DIRECTORY
        echo
        continue
      fi
      git add . && git commit -m "[release] Updated translations." && \
      git pull --rebase origin $BRANCH && git push origin $BRANCH
      if [[ $? != 0 ]]; then
        echo "Couldn't push to $BRANCH."
      fi
      cd $CURRENT_DIRECTORY
      echo
    fi
  done
}

function clean() {
  for f in *; do
    FILE=`printf $FILES $f`
    if [[ -f $FILE ]]; then
      echo "Cleaning $f..."
      cd $f
      checkout
      if [[ $? != 0 ]]; then
        cd $CURRENT_DIRECTORY
        echo
        continue
      fi
      git reset --hard && git clean -dxf
      cd $CURRENT_DIRECTORY
      echo
    fi
  done
}

if [[ "$1" == 'update' ]] && [[ -n "$BRANCH" ]]; then
  update
elif [[ "$1" == 'push' ]] && [[ -n "$BRANCH" ]]; then
  push
elif [[ "$1" == 'clean' ]] && [[ -n "$BRANCH" ]]; then
  clean
else
  usage
fi
