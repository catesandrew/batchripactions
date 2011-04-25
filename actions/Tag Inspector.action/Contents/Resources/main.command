#!/usr/bin/env sh

# main.command
# Tag Inspector

#  Created by Robert Yamada on 11/13/09.
#  Copyright (c) 2009 Robert Yamada
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


while read theFile
do

scriptPID=$$
fileName=`basename "$theFile" | sed 's|\..*$||'`
tagInfoFile="Tag info for $fileName.txt"
echo "\n--------------------------------------------------------------------------------------------------------------" > "/tmp/${tagInfoFile}"
echo "TAG INFORMATION FROM MP4INFO:" >> "/tmp/${tagInfoFile}"
echo "--------------------------------------------------------------------------------------------------------------\n" >> "/tmp/${tagInfoFile}"
/usr/local/bin/mp4info "$theFile" >> "/tmp/${tagInfoFile}"
echo "\n--------------------------------------------------------------------------------------------------------------" >> "/tmp/${tagInfoFile}"
echo "TAG INFORMATION FROM ATOMICPARSLEY64:" >> "/tmp/${tagInfoFile}"
echo "--------------------------------------------------------------------------------------------------------------\n" >> "/tmp/${tagInfoFile}"

/usr/local/bin/AtomicParsley64 "$theFile" -t >> "/tmp/${tagInfoFile}"
qlmanage -p "/tmp/${tagInfoFile}" >& /dev/null

done

if [ -e "/tmp/${tagInfoFile}" ]; then
	rm -f "/tmp/${tagInfoFile}"
fi