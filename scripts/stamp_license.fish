#!/usr/bin/env fish
# stamp gpl header onto dart files under /lib
# skips generated files and anything that is already stamped

set -l marker 'GNU General Public License as published by'

set -l header (string join \n \
'// Copyright (C) 2026 mathiiiiiis' \
'//' \
'// This program is free software: you can redistribute it and/or modify' \
'// it under the terms of the GNU General Public License as published by' \
'// the Free Software Foundation, either version 3 of the License, or' \
'// (at your option) any later version.' \
'//' \
'// This program is distributed in the hope that it will be useful,' \
'// but WITHOUT ANY WARRANTY; without even the implied warranty of' \
'// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the' \
'// GNU General Public License for more details.' \
'')

set -l count 0
for f in (find lib -type f -name '*.dart')
    # skip generated output
    string match -q '*.g.dart' -- $f; and continue
    string match -q '*.freezed.dart' -- $f; and continue
    string match -q 'lib/l10n/generated/*' -- $f; and continue

    # skip files that already carry header
    if grep -qF -- $marker $f
        continue
    end

    set -l tmp (mktemp)
    printf '%s\n' $header >$tmp
    cat $f >>$tmp
    mv $tmp $f
    set count (math $count + 1)
    echo "stamped $f"
end

echo "stamped $count file(s)"
