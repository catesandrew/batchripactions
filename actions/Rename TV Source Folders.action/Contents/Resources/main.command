#!/usr/bin/env sh

# main.command
# Rename TV Items

#  Created by Robert Yamada on 12/2/10.
#  CHANGES:
#  0-20101202-0 - Initial Relese

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

xpathPath="/usr/bin/xpath"

function displayDialogGetTvShowName () {
	cat << EOF | osascript -l AppleScript
		tell application "Automator Runner" 
		activate
		display dialog "What is the TV show title?" default answer "" buttons {"Cancel", "OK"} default button 2
		copy the result as list to {button_pressed, text_returned}
		if the button_pressed is "OK" then
		return text_returned
		else
		return "Cancelled"
		end if
		end tell
EOF
}

function displayDialogGetSeasonAndDisc () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$2"
		tell application "Automator Runner" 
		activate
		display dialog "Enter Season & Disc Number for " & theFile default answer "S1D1" buttons {"Cancel", "OK"} default button 2
		copy the result as list to {button_pressed, text_returned}
		if the button_pressed is "OK" then
		return text_returned
		else
		return "Cancelled"
		end if
		end tell
EOF
}

function tvdbGetSeriesTitles () {
#	discNameNoYear=`echo "$1" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g' -e 's|\&|\&amp;|g'`
	# set TVdb searchTerm
	searchTerm=$(echo "$1" | sed -e 's|\ |+|g' -e 's|\ \-\ |:\ |g' -e "s|\'|%27|g")
	# get mirror URL
	tvdbMirror=`curl -s "http://www.thetvdb.com/api/9F21AC232F30F34D/mirrors.xml" | "$xpathPath" //mirrorpath 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	#get series id
	curl -s "$tvdbMirror/api/GetSeries.php?seriesname=$searchTerm" > "${tmpFolder}/${searchTerm}.xml"
	tvdbSearch=`cat "${tmpFolder}/${searchTerm}.xml" | grep '<id>' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	for tvdbID in $tvdbSearch
	do
		# download each id to tmp.xml
		curl -s "$tvdbMirror/api/9F21AC232F30F34D/series/$tvdbID/en.xml" > "${tmpFolder}/$tvdbID.xml"
		seriesData="${tmpFolder}/${tvdbID}.xml"
		dateAired=`cat "$seriesData" | grep '<FirstAired>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed 's|-.*||g'`
		# get movie title
		seriesTitle=`substituteISO88591 "$(cat "$seriesData" | grep '<SeriesName>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed -e "s|&apos;|\'|g" -e 's|:| -|g' -e "s|&amp;|\&|g")"`

		if [ ! -z "$seriesTitle" ]; then
			seriesFound="${seriesFound}${seriesTitle} - First Aired: ${dateAired}+"
		fi
	done
		echo $seriesFound | tr '+' '\n'
}

function displayDialogChooseTitle () {
	cat << EOF | osascript -l AppleScript
	try
	set theList to paragraphs of "$1"
	tell application "Automator Runner" 
	activate
	choose from list theList with title "Choose from List" with prompt "Please make your selection:"
	end tell
	end try
EOF
}

function substituteISO88591 () {
	returnString=`echo "$1" | sed -e 's|&#162;| cents|g' -e 's|&#163;|#|g' -e 's|&#164;|$|g' -e 's|&#165;| yen|g' -e 's|&#169;|©|g' -e 's|&#171;|"|g' -e 's|&#172;|/|g' -e 's|&#173;|-|g' -e 's|&#174;|¨|g' -e 's|&#176;|¼|g' -e 's|&#177;|+/-|g' -e 's|&#178;| 2|g' -e 's|&#179;| 3|g' -e 's|&#180;|^|g' -e 's|&#181;||g' -e 's|&#182;|¦|g' -e 's|&#183;|,|g' -e 's|&#184;||g' -e 's|&#185;| 1|g' -e 's|&#186;||g' -e 's|&#187;|"|g' -e 's|&#188;|1/4|g' -e 's|&#189;|1/2|g' -e 's|&#190;|3/4|g' -e 's|&#191;|!|g' -e 's|&#192;|A|g' -e 's|&#193;|A|g' -e 's|&#194;|A|g' -e 's|&#195;|A|g' -e 's|&#196;|A|g' -e 's|&#197;|A|g' -e 's|&#198;|AE|g' -e 's|&#199;|C|g' -e 's|&#200;|E|g' -e 's|&#201;|E|g' -e 's|&#202;|E|g' -e 's|&#203;|E|g' -e 's|&#204;|I|g' -e 's|&#205;|I|g' -e 's|&#206;|I|g' -e 's|&#207;|I|g' -e 's|&#208;|TH|g' -e 's|&#209;|N|g' -e 's|&#210;|O|g' -e 's|&#211;|O|g' -e 's|&#212;|O|g' -e 's|&#213;|O|g' -e 's|&#214;|O|g' -e 's|&#215;|x|g' -e 's|&#216;|O|g' -e 's|&#217;|U|g' -e 's|&#218;|U|g' -e 's|&#219;|U|g' -e 's|&#220;|U|g' -e 's|&#221;|Y|g' -e 's|&#222;||g' -e 's|&#223;|s|g' -e 's|&#224;|a|g' -e 's|&#225;|a|g' -e 's|&#226;|a|g' -e 's|&#227;|a|g' -e 's|&#228;|a|g' -e 's|&#229;|a|g' -e 's|&#230;|ae|g' -e 's|&#231;|c|g' -e 's|&#232;|e|g' -e 's|&#233;|e|g' -e 's|&#234;|e|g' -e 's|&#235;|e|g' -e 's|&#236;|i|g' -e 's|&#237;|i|g' -e 's|&#238;|i|g' -e 's|&#239;|i|g' -e 's|&#240;|th|g' -e 's|&#241;|n|g' -e 's|&#242;|o|g' -e 's|&#243;|o|g' -e 's|&#244;|o|g' -e 's|&#245;|o|g' -e 's|&#246;|o|g' -e 's|&#247;||g' -e 's|&#248;|o|g' -e 's|&#249;|u|g' -e 's|&#250;|u|g' -e 's|&#251;|u|g' -e 's|&#252;|u|g' -e 's|&#253;|y|g' -e 's|&#254;||g' -e 's|&#255;|y|g' -e 's|&#34;|?|g' -e 's|&#38;|&|g' -e 's|&#60;|<|g' -e 's|&#62;|>|g' -e 's|&#338;|OE|g' -e 's|&#339;|oe|g' -e 's|&#352;|S|g' -e 's|&#353;|s|g' -e 's|&#376;|Y|g' -e 's|&#382;|z|g' -e 's|&#710;||g' -e 's|&#732;|~|g' -e 's|&#8194;| |g' -e 's|&#8195;| |g' -e 's|&#8201;| |g' -e 's|&#8204;||g' -e 's|&#8205;||g' -e 's|&#8206;||g' -e 's|&#8207;||g' -e 's|&#8211;|-|g' -e 's|&#8212;|-|g' -e "s|&#8216;|'|g" -e "s|&#8217;|'|g" -e "s|&#8218;|'|g" -e 's|&#8220;|"|g' -e 's|&#8221;|"|g' -e 's|&#8222;|"|g' -e 's|&#8224;||g' -e 's|&#8225;||g' -e 's|&#8240;||g' -e 's|&#8249;|<|g' -e 's|&#8250;|>|g' -e 's|&#8364;|e|g'`
	echo "$returnString"
}

scriptPID=$$
tmpFolder="/tmp/renameTV${scriptPID}"

if [ ! -e "$tmpFolder" ]; then
	mkdir "$tmpFolder"
fi

getSeriesName=`displayDialogGetTvShowName`
if [ ! -z "$getSeriesName" ]; then
	seriesList=`tvdbGetSeriesTitles "$getSeriesName"`
	seriesName=`displayDialogChooseTitle "$seriesList"`
	if [[ ! "$seriesName" = "false" && ! "$seriesName" = "" ]]; then
		seriesName=`echo "$seriesName" | sed -e 's| - First Aired.*$||g' -e 's|\&amp;|\&|g'`
	fi
else
	osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Rename TV Item" message "Error: Search Term Required" & Return & "Please enter a series title"'
	exit 0
fi

while read theFile
do
	folderName=`basename "$theFile" | tr '_' ' ' | sed 's| ([0-9]*)||'`
	nameWithSeasonAndDisc=`displayDialogGetSeasonAndDisc "$seriesName" "$folderName"`
	if [ ! -z "$nameWithSeasonAndDisc" ]; then
		newFolderName="${seriesName} - ${nameWithSeasonAndDisc}"
		folderPath=`dirname "$theFile"`
		mv "$theFile" "$folderPath/$newFolderName"
	else
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Rename TV Items" message "Error: Input Required" & Return & "Please enter the Season and Disc Number"'
		continue
	fi
done

if [ -e "$tmpFolder" ]; then
	rm -rf $tmpFolder
fi

exit 0