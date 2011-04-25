#!/usr/bin/env sh

# main.command
# Add Movie Poster

#  Created by Robert Yamada on 10/21/09.
#  Changes:
#  1.20091118.0: Added underscore removal to $fileName
#  2.20091118.1: Added $fileExt to remove ext from $fileName
#  3.20091126.0: Added ISO88591 subroutine

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

########################################################################
# FUNCTIONS

function displayDialogGetMovieName () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$1"
		tell application "Automator Runner" 
		activate
		display dialog "What is the movie title?" default answer theFile buttons {"Cancel", "OK"} default button 2
		copy the result as list to {button_pressed, text_returned}
		if the button_pressed is "OK" then
		return text_returned
		else
		return "Cancelled"
		end if
		end tell
EOF
}

function tmdbGetMovieTitles () {
#	discNameNoYear=`echo "$1" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g' -e 's|\&|\&amp;|g'`
	discNameNoYear=`echo "$1" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g'`
	# set TMDb searchTerm
	searchTerm=`echo "$discNameNoYear" | sed -e 's|\ |+|g' -e "s|\'|%27|g"`
	movieYear=`echo "$1" | awk -F\( '{print $2}' | awk -F\) '{print $1}'`
	tmdbSearch=`curl -s "http://api.themoviedb.org/2.1/Movie.search/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$searchTerm" | grep '<id>' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`

	for tmdbID in $tmdbSearch
	do
		# download each id to tmp.xml
		movieData=$(curl -s "http://api.themoviedb.org/2.1/Movie.getInfo/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$tmdbID")

		releaseDate=`echo "$movieData" | grep '<released>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed 's|-.*||g'`
		# get movie title
		movieTitle=`substituteISO88591 "$(echo "$movieData" | grep '<name>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed -e "s|&apos;|\'|g" -e 's|:| -|g' -e "s|&amp;|\&|g")"`
		
		moviesFound="${moviesFound}${movieTitle} (${releaseDate}) ID#:${tmdbID}+"

	done
	echo $moviesFound | tr '+' '\n'
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

function displayChooseImageFromClipboard () {
	cat << EOF | osascript -l AppleScript
		tell application "Automator Runner" 
		activate
		display dialog "1. Find and Select an image in Safari" & Return & "2. Copy Link to the clipboard" & Return & "3. Click OK to add the image to your file" buttons {"Skip", "OK"} default button 2 with icon 0 with floating
		copy the result as list to {button_pressed}
		if button_pressed is "OK" then
		tell application "Finder" to set visible of process "Safari" to false
		return "OK"
		end if
		if button_pressed is "Skip" then
		return "Skip"
		tell application "Finder" to set visible of process "Safari" to false
		end if
		end tell
		
EOF
}

function displayDialogChooseFile () {
	cat << EOF | osascript -l AppleScript
	tell application "System Events"
		activate
		choose file with prompt "Choose image file for: " & "$1" of type {"public.image"} default location path to downloads folder
		return Posix path of the result
	end tell
EOF
}

function getArtFromClipboard () {
	# download cover art from clipboard link
	moviePoster="${tmpFolder}/${scriptPID}.jpg"
	curl $(pbpaste) > $moviePoster &
	wait
	# embed movie poster in file
	addCoverArt "$moviePoster"
}

function searchForArt () {
	getMovieName=`displayDialogGetMovieName "$fileName"`
	if [ ! -z "$getMovieName" ]; then
		movieList=`tmdbGetMovieTitles "$getMovieName"`
		displayTitle=`echo "$movieList" | sed 's|ID\#\:[0-9]*||g'`
		chooseTitle=`displayDialogChooseTitle "$displayTitle"`
		if [[ ! "$chooseTitle" = "false" && ! "$chooseTitle" = "" ]]; then
			theMovieID=`echo "$movieList" | tr '+' '\n' | grep "$chooseTitle" | sed 's|.*ID\#\:||'`
			moviePosterURL="http://www.themoviedb.org/movie/$theMovieID/posters"
			open "$moviePosterURL"
			moviePoster="${tmpFolder}/${theMovieID}.jpg"
			displayCopyImage=`displayChooseImageFromClipboard`
			if [[ ! "$displayCopyImage" = "Skip" && ! "$displayCopyImage" = "" ]]; then
				if echo $(pbpaste) | grep "http" ; then
					curl $(pbpaste) > $moviePoster &
					wait
					# embed movie poster in file
					addCoverArt "$moviePoster"
				else
					osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Poster" message "Error: Not a valid URL"'
				fi
			else
				osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Poster" message "Error: No link found in clipboard"'
			fi

		else
			osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Poster" message "Error: No movie selected" & Return & "Movie may not be in themoviedb.org database"'
#			exit 0
		fi
#	else
#		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Poster" message "Error: Search Term Required" & Return & "Please enter a movie title"'
#		exit 0
	fi
}

function getArtFromFile () {
	moviePoster=`displayDialogChooseFile "$fileName"`
	if [[ -e "$moviePoster" ]]; then
		imgFileName=`basename "$moviePoster"`
		cp "$moviePoster" "${tmpFolder}/$imgFileName"
		moviePosterTmp="${tmpFolder}/$imgFileName"
		addCoverArt "$moviePosterTmp"
	else
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Poster" message "Error: No file selected"'
	fi
}

function addCoverArt () {
	# add cover art
	if [ -e "$1" ]; then
		imgIntegrityTest=`sips -g pixelWidth "$1" | sed 's|.*[^0-9+]||'`
		if [ "$imgIntegrityTest" -gt 100 ]; then
			sips -Z 600W600H "$1" --out "$1"
			"$mp4artPath" --remove "$theFile" &
			wait
			"$mp4artPath" -oz --add "$1" "$theFile"
		else
			osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Poster" message "Error: Image file failed integrity test" & Return & "Try another image or link"'
		fi
	fi
}

function substituteISO88591 () {
	returnString=`echo "$1" | sed -e 's|&#162;| cents|g' -e 's|&#163;|#|g' -e 's|&#164;|$|g' -e 's|&#165;| yen|g' -e 's|&#169;|©|g' -e 's|&#171;|"|g' -e 's|&#172;|/|g' -e 's|&#173;|-|g' -e 's|&#174;|¨|g' -e 's|&#176;|¼|g' -e 's|&#177;|+/-|g' -e 's|&#178;| 2|g' -e 's|&#179;| 3|g' -e 's|&#180;|^|g' -e 's|&#181;||g' -e 's|&#182;|¦|g' -e 's|&#183;|,|g' -e 's|&#184;||g' -e 's|&#185;| 1|g' -e 's|&#186;||g' -e 's|&#187;|"|g' -e 's|&#188;|1/4|g' -e 's|&#189;|1/2|g' -e 's|&#190;|3/4|g' -e 's|&#191;|!|g' -e 's|&#192;|A|g' -e 's|&#193;|A|g' -e 's|&#194;|A|g' -e 's|&#195;|A|g' -e 's|&#196;|A|g' -e 's|&#197;|A|g' -e 's|&#198;|AE|g' -e 's|&#199;|C|g' -e 's|&#200;|E|g' -e 's|&#201;|E|g' -e 's|&#202;|E|g' -e 's|&#203;|E|g' -e 's|&#204;|I|g' -e 's|&#205;|I|g' -e 's|&#206;|I|g' -e 's|&#207;|I|g' -e 's|&#208;|TH|g' -e 's|&#209;|N|g' -e 's|&#210;|O|g' -e 's|&#211;|O|g' -e 's|&#212;|O|g' -e 's|&#213;|O|g' -e 's|&#214;|O|g' -e 's|&#215;|x|g' -e 's|&#216;|O|g' -e 's|&#217;|U|g' -e 's|&#218;|U|g' -e 's|&#219;|U|g' -e 's|&#220;|U|g' -e 's|&#221;|Y|g' -e 's|&#222;||g' -e 's|&#223;|s|g' -e 's|&#224;|a|g' -e 's|&#225;|a|g' -e 's|&#226;|a|g' -e 's|&#227;|a|g' -e 's|&#228;|a|g' -e 's|&#229;|a|g' -e 's|&#230;|ae|g' -e 's|&#231;|c|g' -e 's|&#232;|e|g' -e 's|&#233;|e|g' -e 's|&#234;|e|g' -e 's|&#235;|e|g' -e 's|&#236;|i|g' -e 's|&#237;|i|g' -e 's|&#238;|i|g' -e 's|&#239;|i|g' -e 's|&#240;|th|g' -e 's|&#241;|n|g' -e 's|&#242;|o|g' -e 's|&#243;|o|g' -e 's|&#244;|o|g' -e 's|&#245;|o|g' -e 's|&#246;|o|g' -e 's|&#247;||g' -e 's|&#248;|o|g' -e 's|&#249;|u|g' -e 's|&#250;|u|g' -e 's|&#251;|u|g' -e 's|&#252;|u|g' -e 's|&#253;|y|g' -e 's|&#254;||g' -e 's|&#255;|y|g' -e 's|&#34;|?|g' -e 's|&#38;|&|g' -e 's|&#60;|<|g' -e 's|&#62;|>|g' -e 's|&#338;|OE|g' -e 's|&#339;|oe|g' -e 's|&#352;|S|g' -e 's|&#353;|s|g' -e 's|&#376;|Y|g' -e 's|&#382;|z|g' -e 's|&#710;||g' -e 's|&#732;|~|g' -e 's|&#8194;| |g' -e 's|&#8195;| |g' -e 's|&#8201;| |g' -e 's|&#8204;||g' -e 's|&#8205;||g' -e 's|&#8206;||g' -e 's|&#8207;||g' -e 's|&#8211;|-|g' -e 's|&#8212;|-|g' -e "s|&#8216;|'|g" -e "s|&#8217;|'|g" -e "s|&#8218;|'|g" -e 's|&#8220;|"|g' -e 's|&#8221;|"|g' -e 's|&#8222;|"|g' -e 's|&#8224;||g' -e 's|&#8225;||g' -e 's|&#8240;||g' -e 's|&#8249;|<|g' -e 's|&#8250;|>|g' -e 's|&#8364;|e|g'`
	echo "$returnString"
}

########################################################################
# MAIN SCRIPT

scriptPID=$$
mp4artPath="/usr/local/bin/mp4art" 

while read theFile
do
	if [[ ! "${optionPopup}" ]]; then optionPopup=0; fi

	if [ ! -x "$mp4artPath" ]; then
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Poster" message "Error: mp4v2 Library cannot be found" & Return & "Please install mp4v2 tools in /usr/local/bin" & Return & "Get mp4v2 at: http://code.google.com/p/mp4v2/"'
		exit 1
	fi


	# create tmp folder
	tmpFolder="/tmp/addMovieTags_$scriptPID"
	if [ ! -e "$tmpFolder" ]; then
		mkdir "$tmpFolder"
	fi

if [ -e "$theFile" ]; then
	fileExt=`basename "$theFile" | sed 's|.*\.||'`
	fileName=`basename "$theFile" .$fileExt | tr '_' ' ' | sed 's| ([0-9]*)||'`
	# Search the moviedb.org
	if [[ optionPopup -eq 0 ]]; then	
		searchForArt
	# Choose cover art from file	
	elif [[ optionPopup -eq 1 ]]; then
		getArtFromFile
	# Get art from URL in clipboard
	elif [[ optionPopup -eq 2 ]]; then
		getArtFromClipboard
	fi	

	# Tell Finder to update view
	osascript -e "set theFile to POSIX file \"$theFile\"" -e 'tell application "Finder" to update theFile'
fi

done

# Remove tmp files/folder
if [ -e "$tmpFolder" ]; then
	rm -f $tmpFolder/*
	rm -d $tmpFolder
fi
