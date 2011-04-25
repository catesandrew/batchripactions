#!/usr/bin/env sh

# main.command
# Add Movie Tags

#  Created by Robert Yamada on 10/2/09.
#  Changes:
#  20091026-0 Added AP title & stik tags.
#  20091026-1 Added mp4tags, mp4info & mp4chaps. Added HD-Flag and Add Chaps from file
#  20091113-2 Added support for search and tag
#  20091118-3 Added underscore removal to $fileName

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

scriptPID=$$
xpathPath="/usr/bin/xpath"
xmllintPath="/usr/bin/xmllint"
atomicParsley64Path="/usr/local/bin/AtomicParsley64"
mp4infoPath="/usr/local/bin/mp4info"	# path to mp4info
mp4tagsPath="/usr/local/bin/mp4tags"	# path to mp4tags
mp4artPath="/usr/local/bin/mp4art"		# path to mp4art
mp4chapsPath="/usr/local/bin/mp4chaps"	# path to mp4chaps

function searchForMovieTags () {
	getMovieName=`displayDialogGetMovieName "$fileName"`
	if [[ ! -z "$getMovieName" && ! "$getMovieName" = "Quit" ]]; then
		movieList=`tmdbGetMovieTitles "$getMovieName"`
		displayTitle=`echo "$movieList" | sed 's|ID\#\:[0-9]*||g'`
		chooseTitle=`displayDialogChooseTitle "$displayTitle"`
		if [[ ! "$chooseTitle" = "false" && ! "$chooseTitle" = "" ]]; then
			sourceTmpFolder="/tmp/$scriptPID"
			mkdir $sourceTmpFolder
			# sets movie title to selection (for testing using alt title)
			#theMovieNameAndYear=`echo "$movieList" | tr '+' '\n' | grep "$chooseTitle" | sed 's|ID\#\:[0-9]*||g'`
			theMovieID=`echo "$movieList" | tr '+' '\n' | grep "$chooseTitle" | sed 's|.*ID\#\:||'`
			
			# download each id to tmp.xml
			movieData="${sourceTmpFolder}/${theMovieID}_tbdb_tmp.xml"
			if [ ! -e "$movieData" ]; then
				curl -s "http://api.themoviedb.org/2.1/Movie.getInfo/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$theMovieID" > "$movieData"
				addMovieTags
			fi
		else
			osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: No movie selected" & Return & "Movie may not be in themoviedb.org database"'
#			exit 0
		fi
	elif [ "$getMovieName" = "Quit" ]; then
#		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: Search Term Required" & Return & "Please enter a movie title"'
		exit 0
	fi
}

function getMovieTagsFromFileName () {
	# variables	
	discName="$movieName"
	sourceTmpFolder="/tmp/$scriptPID"
	discNameNoYear=`echo "$discName" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g'`
	#discNameNoYear=`echo "$discName" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g' -e 's|\&|\&amp;|g'`
	# set TMDb searchTerm
	searchTerm=`echo "$discNameNoYear" | sed -e 's|\ |+|g' -e "s|\'|%27|g"`
	searchTermNoColin=`echo $searchTerm | sed 's|:||g'`
	movieYear=`echo "$discName" | awk -F\( '{print $2}' | awk -F\) '{print $1}'`

	echo -e "  Searching TMDb for ${searchTerm}... \c"
	if [ ! -e "${sourceTmpFolder}/${searchTermNoColin}_tmp.xml" ]; then
		mkdir $sourceTmpFolder
		# get TMDb ID for all matches
		movieSearchXml="${sourceTmpFolder}/${searchTermNoColin}_tmp.xml"
		curl -s "http://api.themoviedb.org/2.1/Movie.search/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$searchTerm" > "$movieSearchXml"
		tmdbSearch=`"$xpathPath" "$movieSearchXml" //id 2>/dev/null | sed -e 's|\/id>|\||g'| tr '|' '\n' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`

		# find the listing that matches the releses the release date, movie title and type
		for theMovieID in $tmdbSearch
		do		
			# download each id to tmp.xml
			movieData="${sourceTmpFolder}/${theMovieID}_tbdb_tmp.xml"
			if [ ! -e "$movieData" ]; then
				curl -s "http://api.themoviedb.org/2.1/Movie.getInfo/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$theMovieID" > "$movieData"
				substituteISO88591 "$(cat "$movieData")" > "$movieData"
			fi

			# get movie title and release date
			discNameNoYearWildcard=`echo "$discNameNoYear" | sed -e 's|:|.*|g' -e 's|\&|.*|g'`
			releaseDate=`"$xpathPath" "$movieData" //released 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | grep "$movieYear"`
			movieTitle=`"$xpathPath" "$movieData" //name 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e "s|&apos;|\'|g" -e 's| $||' | egrep -ix "$discNameNoYearWildcard"`
			if [ "$movieTitle" = "" ]; then
				movieTitle=`"$xpathPath" "$movieData" //alternative_name 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e "s|&apos;|\'|g" -e 's| $||' | egrep -ix "$discNameNoYearWildcard"`
			fi
			# verify data match, delete if not a match
			if [[ ! "$releaseDate" = "" && ! "$movieTitle" = "" ]] ; then
				echo "Title found"
				mv "$movieData" "$movieSearchXml"
				movieData="$movieSearchXml"
				break 1
			else
				if [ -e "$movieData" ]; then
					rm "$movieData"
				fi
			fi

		done
		if [ ! -e "$movieSearchXml" ]; then
			echo " " > "$movieSearchXml"
		fi
		addMovieTags
	fi
}

function displayDialogGetMovieName () {
	cat << EOF | osascript -l AppleScript
		set theFile to "$1"
		tell application "Automator Runner" 
		activate
		display dialog "What is the movie title?" default answer theFile buttons {"Cancel All", "Cancel", "OK"} default button 3
		copy the result as list to {button_pressed, text_returned}
		if the button_pressed is "OK" then
			return text_returned
		else if the button_pressed is "Cancelled" then
			return "Cancelled"
		else if the button_pressed is "Cancel All" then
			return "Quit"
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

	if echo "$getMovieName" | egrep -i 'id=[0-9]+' > /dev/null ; then
		tmdbSearch=`echo "$getMovieName" | sed 's|id=||'`
	else
		tmdbSearch=`curl -s "http://api.themoviedb.org/2.1/Movie.search/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$searchTerm" | grep '<id>' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	fi

	for tmdbID in $tmdbSearch
	do
		# download each id to tmp.xml
		movieData=$(curl -s "http://api.themoviedb.org/2.1/Movie.getInfo/en/xml/8d7d0edf7ec73435ea5d99d9cba9b54d/$tmdbID")

		releaseDate=`echo "$movieData" | grep '<released>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed 's|-.*||g'`
		# get movie title
		movieTitle=`substituteISO88591 "$(echo "$movieData" | grep '<name>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed -e "s|&apos;|\'|g" -e 's|:| -|g' -e "s|&amp;|\&|g")"`
		
		moviesFound="${moviesFound}${movieTitle} (${releaseDate}) ID#:${tmdbID}+"
		
		# get alt title (for testing using alt title selection)
		#altMovieTitle=`substituteISO88591 "$(echo "$movieData" | grep '<alternative_name>' | awk -F\> '{print $2}' | awk -F\< {'print $1'} | sed -e "s|&apos;|\'|g" -e 's|:| -|g' -e "s|&amp;|\&|g")"`
		#if [ ! -z "$altMovieTitle" ]; then
		#	moviesFound="${moviesFound}${altMovieTitle} (${releaseDate}) ID#:${tmdbID}+"
		#fi

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

function addMovieTags () {
	# set metadata variables and write tags to file
	if sed '1q;d' "$movieData" | grep '>' > /dev/null ; then
		substituteISO88591 "$(cat "$movieData")" > "$movieData"
		movieTitle=`"$xpathPath" "$movieData" //name 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e 's|: | - |g' -e 's|\&amp;|\&|g' -e "s|&apos;|\'|g"`
		videoType=`"$xpathPath" "$movieData" "//type" 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		movieDirector=`"$xpathPath" "$movieData" "//person[@job='Director']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
		movieProducers=`"$xpathPath" "$movieData" "//person[@job='Executive Producer']/@name|//person[@job='Producer']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
		movieWriters=`"$xpathPath" "$movieData" "//person[@job='Screenplay']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
		movieActors=`"$xpathPath" "$movieData" "//person[@job='Actor']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
		albumArtists=`"$xpathPath" "$movieData" "//person[@job='Actor']/@name" 2>/dev/null | sed -e 's| name="||g' -e 's|"|, |g' -e '/./!d' -e 's|, $||'`
		releaseDate=`"$xpathPath" "$movieData" //released 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		movieDesc=`"$xpathPath" "$movieData" //overview 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		genreList=`"$xpathPath" "$movieData" "//category[@type='genre']/@name" 2>/dev/null | sed 's| name="||g' | tr '\"' '\n' | sed -e '/./!d' -e 's|^|<string>|g' -e 's|^|<dict><key>name</key>|g' -e 's|$|</string></dict>|g'`
		purchaseDate=`date "+%Y-%m-%d %H:%M:%S"`
		releaseYear=`echo "$releaseDate" | sed 's|-.*||g'`
		
		if [ ! -z "$theMovieNameAndYear" ]; then
			movieTitleAndYear="$theMovieNameAndYear"
		else
			movieTitleAndYear="${movieTitle} (${releaseYear})"
		fi

		
		# parse category info and convert into iTunes genre
		if echo "$genreList" | grep 'Animation' > /dev/null ; then
			movieGenre="Kids & Family"
		elif echo "$genreList" | grep '\(Fantasy\|Science\|Science Fiction\)' > /dev/null ; then
			movieGenre="Sci-Fi & Fantasy"
		elif echo "$genreList" | grep 'Horror' > /dev/null ; then
			movieGenre="Horror"
		elif echo "$genreList" | grep '\(Action\|Adventure\|Disaster\)' > /dev/null ; then
			movieGenre="Action & Adventure"
		elif echo "$genreList" | grep '\(Musical\|Music\)' > /dev/null ; then
			movieGenre="Music"
		elif echo "$genreList" | grep 'Documentary' > /dev/null ; then
			movieGenre="Documentary"			
		elif echo "$genreList" | grep 'Sport' > /dev/null ; then
			movieGenre="Sports"			
		elif echo "$genreList" | grep 'Western' > /dev/null ; then
			movieGenre="Western"
		elif echo "$genreList" | grep '\(Thriller\|Suspense\)' > /dev/null ; then
			movieGenre="Thriller"
		elif echo "$genreList" | grep '\(Drama\|Historical\|Political\|Crime\|Mystery\)' > /dev/null ; then
			movieGenre="Drama"
		elif echo "$genreList" | grep '\(Comedy\|Road\)' > /dev/null ; then
			movieGenre="Comedy"
		fi 
		
		# get cover art
		moviePoster="${sourceTmpFolder}/${theMovieID}.jpg"
		if [ ! -e $moviePoster ] ; then
			getMoviePoster=`"$xpathPath" "$movieData" "//image[@type='poster' and @size='original']/@url | //image[@type='poster' and @size='cover']/@url | //image[@type='poster' and @size='mid']/@url" 2>/dev/null | sed 's|url="||g' | tr '"' '\n' | sed -e 's|^ ||' -e '/./!d'`
			for eachURL in $getMoviePoster
			do
				curl -s "$eachURL" > $moviePoster
				imgIntegrityTest=`sips -g pixelWidth "$moviePoster" | sed 's|.*[^0-9+]||'`
				wait
				if [ "$imgIntegrityTest" -gt 100 ]; then
					resizeImage "$moviePoster"
					break 1
				fi
			done
		fi

		# create movie tags reverseDNS xml file
		movieTagsXml="${sourceTmpFolder}/${theMovieID}_tags_tmp.xml"
		if [ ! -e $movieTagsXml ] ; then
			xmlFile="<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>cast</key><array>${movieActors}</array><key>directors</key><array>${movieDirector}</array><key>screenwriters</key><array>${movieWriters}</array><key>producers</key><array>${movieProducers}</array></dict></plist>"
			echo "$xmlFile" | tr -cd '\11\12\40-\176' | "$xmllintPath" --format --output "$movieTagsXml" - 
		fi
		movieTagsData=`cat "$movieTagsXml"`

		# removeTags
		if [[ removeTags -eq 1 ]]; then
		#"$atomicParsley64Path" "$theFile" --overWrite --metaEnema
		"$mp4tagsPath" -r AacCdDgGHilmMnNoPsStTywR "$theFile"
		fi

		# write tags with atomic parsley
		echo -e "\n*Writing tags with AtomicParsley\c"
		if [[ overWrite -eq 1 ]]; then
			if [[ -e "$moviePoster" && "$imgIntegrityTest" -gt 100 ]]; then
				"$atomicParsley64Path" "$theFile" --artwork REMOVE_ALL --overWrite --title "$movieTitleAndYear" --artist "$albumArtists" --year "$releaseDate" --purchaseDate "$purchaseDate" --artwork "$moviePoster" --genre "$movieGenre" --description "$movieDesc" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes
			else
				"$atomicParsley64Path" "$theFile" --artwork REMOVE_ALL --overWrite --title "$movieTitleAndYear" --artist "$albumArtists" --year "$releaseDate" --purchaseDate "$purchaseDate" --genre "$movieGenre" --description "$movieDesc" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes
					osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: Cover art failed integrity test" & Return & "No artwork was added"'
			fi

		elif [[ overWrite -eq 0 ]]; then
			newFile="${outputDir}/${movieTitle} (${releaseYear})-${scriptPID}.${fileExt}"
			if [[ -e "$moviePoster" && "$imgIntegrityTest" -gt 100 ]]; then
				"$atomicParsley64Path" "$theFile" --output "$newFile" --artwork REMOVE_ALL --title "$movieTitleAndYear" --artist "$albumArtists" --year "$releaseDate" --purchaseDate "$purchaseDate" --artwork "$moviePoster" --genre "$movieGenre" --description "$movieDesc" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes
			else
				"$atomicParsley64Path" "$theFile" --output "$newFile" --title "$movieTitleAndYear" --artist "$albumArtists" --year "$releaseDate" --purchaseDate "$purchaseDate" --genre "$movieGenre" --description "$movieDesc" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes
				osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: Cover art failed integrity test" & Return & "No artwork was added"'
			fi
		fi
		
		renameFilePath="${outputDir}/${movieTitleAndYear}.${fileExt}"
		if [[ renameFile -eq 1 && ! "$theFile" = "$renameFilePath" ]]; then
			if [ ! -e "$renameFilePath" ]; then
				if [[ overWrite -eq 0 && -e "$newFile" ]]; then
					mv "$newFile" "$renameFilePath"
					theFile="$renameFilePath"
				elif [[ overWrite -eq 1 && -e "$theFile" ]]; then
					mv "$theFile" "$renameFilePath"
					theFile="$renameFilePath"
				fi
			else
				theFileName="${movieTitleAndYear}.${fileExt}"
				osascript -e "set the_File to \"$theFileName\"" -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: Rename File Failed. Cannot rename the file." & Return & the_File & " already exists."'	
			fi
		fi

	else
		if [[ useFileNameForSearch -eq 1 ]]; then
			osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: The API server did not return a correct match or the service may be down." & Return & Return & "Verify that your file name has the correct Movie Name and Year according to themoviedb.org database. If the problem resides with the API server, try again later."'
		else
			osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: No results returned from database." & Return & "The API may be down or there is a problem returning the data. Check you internet connection or try again later."'
		fi
	fi
}

function resizeImage () {
	sips -Z 600W600H "$1" --out "$1"
}

function substituteISO88591 () {
	returnString=`echo "$1" | sed -e 's|&#162;| cents|g' -e 's|&#163;|#|g' -e 's|&#164;|$|g' -e 's|&#165;| yen|g' -e 's|&#169;|©|g' -e 's|&#171;|"|g' -e 's|&#172;|/|g' -e 's|&#173;|-|g' -e 's|&#174;|¨|g' -e 's|&#176;|¼|g' -e 's|&#177;|+/-|g' -e 's|&#178;| 2|g' -e 's|&#179;| 3|g' -e 's|&#180;|^|g' -e 's|&#181;||g' -e 's|&#182;|¦|g' -e 's|&#183;|,|g' -e 's|&#184;||g' -e 's|&#185;| 1|g' -e 's|&#186;||g' -e 's|&#187;|"|g' -e 's|&#188;|1/4|g' -e 's|&#189;|1/2|g' -e 's|&#190;|3/4|g' -e 's|&#191;|!|g' -e 's|&#192;|A|g' -e 's|&#193;|A|g' -e 's|&#194;|A|g' -e 's|&#195;|A|g' -e 's|&#196;|A|g' -e 's|&#197;|A|g' -e 's|&#198;|AE|g' -e 's|&#199;|C|g' -e 's|&#200;|E|g' -e 's|&#201;|E|g' -e 's|&#202;|E|g' -e 's|&#203;|E|g' -e 's|&#204;|I|g' -e 's|&#205;|I|g' -e 's|&#206;|I|g' -e 's|&#207;|I|g' -e 's|&#208;|TH|g' -e 's|&#209;|N|g' -e 's|&#210;|O|g' -e 's|&#211;|O|g' -e 's|&#212;|O|g' -e 's|&#213;|O|g' -e 's|&#214;|O|g' -e 's|&#215;|x|g' -e 's|&#216;|O|g' -e 's|&#217;|U|g' -e 's|&#218;|U|g' -e 's|&#219;|U|g' -e 's|&#220;|U|g' -e 's|&#221;|Y|g' -e 's|&#222;||g' -e 's|&#223;|s|g' -e 's|&#224;|a|g' -e 's|&#225;|a|g' -e 's|&#226;|a|g' -e 's|&#227;|a|g' -e 's|&#228;|a|g' -e 's|&#229;|a|g' -e 's|&#230;|ae|g' -e 's|&#231;|c|g' -e 's|&#232;|e|g' -e 's|&#233;|e|g' -e 's|&#234;|e|g' -e 's|&#235;|e|g' -e 's|&#236;|i|g' -e 's|&#237;|i|g' -e 's|&#238;|i|g' -e 's|&#239;|i|g' -e 's|&#240;|th|g' -e 's|&#241;|n|g' -e 's|&#242;|o|g' -e 's|&#243;|o|g' -e 's|&#244;|o|g' -e 's|&#245;|o|g' -e 's|&#246;|o|g' -e 's|&#247;||g' -e 's|&#248;|o|g' -e 's|&#249;|u|g' -e 's|&#250;|u|g' -e 's|&#251;|u|g' -e 's|&#252;|u|g' -e 's|&#253;|y|g' -e 's|&#254;||g' -e 's|&#255;|y|g' -e 's|&#34;|?|g' -e 's|&#38;|&|g' -e 's|&#60;|<|g' -e 's|&#62;|>|g' -e 's|&#338;|OE|g' -e 's|&#339;|oe|g' -e 's|&#352;|S|g' -e 's|&#353;|s|g' -e 's|&#376;|Y|g' -e 's|&#382;|z|g' -e 's|&#710;||g' -e 's|&#732;|~|g' -e 's|&#8194;| |g' -e 's|&#8195;| |g' -e 's|&#8201;| |g' -e 's|&#8204;||g' -e 's|&#8205;||g' -e 's|&#8206;||g' -e 's|&#8207;||g' -e 's|&#8211;|-|g' -e 's|&#8212;|-|g' -e "s|&#8216;|'|g" -e "s|&#8217;|'|g" -e "s|&#8218;|'|g" -e 's|&#8220;|"|g' -e 's|&#8221;|"|g' -e 's|&#8222;|"|g' -e 's|&#8224;||g' -e 's|&#8225;||g' -e 's|&#8240;||g' -e 's|&#8249;|<|g' -e 's|&#8250;|>|g' -e 's|&#8364;|e|g'`
	echo "$returnString"
}

#####################################################################################
# MAIN SCRIPT

while read theFile
do
	if [[ ! "${overWrite}" ]]; then overWrite=0; fi
	if [[ ! "${removeTags}" ]]; then removeTags=0; fi
	if [[ ! "${addTags}" ]]; then addTags=0; fi
	if [[ ! "${useFileNameForSearch}" ]]; then useFileNameForSearch=0; fi
	if [[ ! "${renameFile}" ]]; then renameFile=0; fi

	if [[ ! -x "$mp4infoPath" || ! -x "$mp4tagsPath" || ! -x "$mp4artPath" || ! -x "$mp4chapsPath" ]]; then
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: mp4v2 Library cannot be found" & Return & "Please install mp4v2 tools in /usr/local/bin" & Return & "Get mp4v2 at: http://code.google.com/p/mp4v2/"'
		exit 1
	fi

	fileExt=`basename "$theFile" | sed 's|.*\.||'`
	fileName=`basename "$theFile" .$fileExt | tr '_' ' ' | sed 's| ([0-9]*)||'`
	movieName=`basename "$theFile" ".${fileExt}"`
	outputDir=`dirname "$theFile"`
	if [[ "$fileExt" = "mp4" || "$fileExt" = "m4v" ]]; then
	
		if [[ removeTags -eq 1 && addTags -eq 0 ]]; then
		"$atomicParsley64Path" "$theFile" --overWrite --metaEnema
		#"$mp4tagsPath" -r AacCdDgGHilmMnNoPsStTywR "$theFile"
		fi

		if [[ addTags -eq 1 ]]; then			
			if [[ useFileNameForSearch -eq 1 ]]; then
				if echo "$theFile" | egrep '.* \([0-9]{4}\)' ; then
					getMovieTagsFromFileName
				else
					osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: File Naming Convention. Cannot parse the filename." & Return & "Rename your file: Movie Name (year)"'
				fi
			else
				searchForMovieTags
			fi
			
			# Set the HD Flag for HD-Video
			getResolution=$(mp4info "$theFile" | egrep "1.*video" | awk -F,\  '{print $4}' | sed 's|\ @.*||')
			pixelWidth=$(echo "$getResolution" | sed 's|x.*||')
			pixelHeight=$(echo "$getResolution" | sed 's|.*x||')
			if [[ pixelWidth -gt 1279 || pixelHeight -gt 719 ]]; then
				"$mp4tagsPath" -H 1 "$theFile"
			fi

			# Add Chapters if chapter file exists
			chapterFile="${outputDir}/${movieName}.chapters.txt"
			if [ -e "$chapterFile" ]; then
				"$mp4chapsPath" -i "$theFile"
			fi

		fi

		if [ -e "$sourceTmpFolder" ]; then
			rm -f $sourceTmpFolder/*
			rm -d $sourceTmpFolder
		fi
	else
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: File Type Extension. Cannot determine if file is mpeg-4 compatible." & Return & "File extension and type must be .mp4 or .m4v."'
	fi
	osascript -e "set theFile to POSIX file \"$theFile\"" -e 'tell application "Finder" to update theFile'

done