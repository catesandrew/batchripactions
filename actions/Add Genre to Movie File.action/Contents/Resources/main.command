#!/usr/bin/env sh

# main.command
# Add Genre to Movie File

#  Created by Robert Yamada on 10/19/09.

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

while read theFile
do
if [[ ! "${genrePopup}" ]]; then genrePopup=""; fi
mp4tagsPath="/usr/local/bin/mp4tags"

	if [ ! -x "$mp4tagsPath" ]; then
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Genre to Movie File" message "Error: mp4v2 Library cannot be found" & Return & "Please install mp4v2 tools in /usr/local/bin" & Return & "Get mp4v2 at: http://code.google.com/p/mp4v2/"'
		exit 1
	fi


if [ ! -z "$genrePopup" ]; then
	"$mp4tagsPath" -genre "$genrePopup" "$theFile"
else
	osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Genre to Movie File" message "Error: No genre selected" & Return & "Please choose a genre"'
	exit 1
fi
done
