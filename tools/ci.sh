#!/bin/bash
# Waits for the newest cloud build of this branch and prints what the compiler said.
R=kendo316/Claude-Code---Bravo
sleep "${1:-20}"
ID=$(gh run list -R $R -b finders-keepers -L 1 --json databaseId -q '.[0].databaseId')
for i in $(seq 1 70); do
  S=$(gh run view $ID -R $R --json status,conclusion -q '.status+" "+.conclusion')
  case "$S" in completed*) break;; esac
  sleep 8
done
echo "run $ID: $S"
gh run view $ID -R $R --json jobs -q '.jobs[] | .name+": "+.conclusion'
gh run view $ID -R $R --log 2>/dev/null | sed -E 's/^([^\t]*)\t[^\t]*\t[0-9TZ:.\-]+ /\1| /' | grep -E "error|warning: |BUILD (SUCCEEDED|FAILED)|Test Suite 'All tests'|Executed [0-9]+ tests|XCTAssert|failed|✘|CFBundle|NSPhoto|Xcode [0-9]|Apple Swift" | grep -vE "ld: warning|##\[group\]|grep -E|appintentsmetadata|warning: Metadata extraction" | sort -u | head -${2:-90}
