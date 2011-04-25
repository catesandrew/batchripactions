#!/usr/bin/env sh

# main.command
# Get Source Info from HandBrake

#  Created by Robert Yamada on 11/30/09.
#  Copyright (c) 2009-2010 Robert Yamada
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
	
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
	
#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.

while read i
do

	if [[ ! "${hbPath}" ]]; then hbPath="no selection"; fi
	if [[ ! "${savePath}" ]]; then savePath="no selection"; fi

	fileExt=`echo "$i" | sed 's|.*\.||'`
	fileName=`basename "$i" .${fileExt}`
	"$hbPath" -i "$i" -t0 > "${savePath}/${fileName}-hbInfo.txt" 2>&1

done