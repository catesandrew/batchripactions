#!/usr/bin/env sh

# main.command
# Add Movie Tags

#  Created by Robert Yamada on 10/2/09.
#  Changes:
#  20091026-0 Added AP title & stik tags.
#  20091026-1 Added mp4tags, mp4info & mp4chaps. Added HD-Flag and Add Chaps from file
#  20091113-2 Added support for search and tag
#  20091118-3 Added underscore removal to $fileName
#  20101129-4 Added content rating and long description
#  20101202-5 Added preserve/set cnid number

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

scriptPID=$$
xpathPath="/usr/bin/xpath"
xmllintPath="/usr/bin/xmllint"
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
				if [[ addTags -eq 1 ]]; then
					addMovieTags
				fi
				if [[ addChaps -eq 1 ]]; then
					addChapterNamesMovie
				fi
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
				
				movieDataIconv="${sourceTmpFolder}/${theMovieID}_tbdb_tmp-iconv.xml"
      	iconv -c -f UTF-8 -t US-ASCII < $movieData > $movieDataIconv
      	cp $movieDataIconv $movieData
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
		if [[ addTags -eq 1 ]]; then
			addMovieTags
		fi
		if [[ addChaps -eq 1 ]]; then
			addChapterNamesMovie
		fi
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
		movieDirector=`"$xpathPath" "$movieData" "//person[@job='Director']/@name" 2>/dev/null | sed -e 's| name="||g' -e 's|"|, |g' -e '/./!d' -e 's|, $||'`
		movieProducers=`"$xpathPath" "$movieData" "//person[@job='Executive Producer']/@name|//person[@job='Producer']/@name" 2>/dev/null | sed -e 's| name="||g' -e 's|"|, |g' -e '/./!d' -e 's|, $||'`
		movieWriters=`"$xpathPath" "$movieData" "//person[@job='Screenplay']/@name" 2>/dev/null | sed -e 's| name="||g' -e 's|"|, |g' -e '/./!d' -e 's|, $||'`
		movieActors=`"$xpathPath" "$movieData" "//person[@job='Actor']/@name" 2>/dev/null | sed -e 's| name="||g' -e 's|"|, |g' -e '/./!d' -e 's|, $||'`		
		albumArtists=`"$xpathPath" "$movieData" "//person[@job='Actor']/@name" 2>/dev/null | sed -e 's| name="||g' -e 's|"|, |g' -e '/./!d' -e 's|, $||'`
		releaseDate=`"$xpathPath" "$movieData" //released 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		movieDesc=`"$xpathPath" "$movieData" //overview 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		
		shortMovieDesc=`echo $movieDesc | cut -c1-250`
		len=${#movieDesc}
		if [ "$len" -gt "250" ] ; then
		  shortMovieDesc="${shortMovieDesc}..."
		fi
		
		imdb_id=`"$xpathPath" "$movieData" //imdb_id 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		tmdb_id=`"$xpathPath" "$movieData" //id 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		
		contentRating=`"$xpathPath" "$movieData" //certification 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
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

		# removeTags
		if [[ removeTags -eq 1 ]]; then
		"$mp4tagsPath" -r AacCdDgGHilmMnNoPsStTywR "$theFile"
		fi
		
		# write tags with mp4v2
		if [[ overWrite -eq 1 ]]; then
			if [[ -e "$moviePoster" && "$imgIntegrityTest" -gt 100 ]]; then
			  #--artwork REMOVE_ALL --overWrite
			  "$mp4tagsPath" -song "$movieTitle" -artist "$albumArtists" -year "$releaseDate" -description "$shortMovieDesc" -longdesc "$movieDesc" -type "Movie" -picture "$moviePoster" -genre "$movieGenre" -cast "$movieActors" -director "$movieDirector" -swriters "$movieWriters" -producers "$movieProducers" -comment "{'imdb_id':'${imdb_id}', 'tmdb_id':'${tmdb_id}'}" -crating "$contentRating" "$theFile"
			else
			  #--artwork REMOVE_ALL --overWrite
			  "$mp4tagsPath" -song "$movieTitle" -artist "$albumArtists" -year "$releaseDate" -description "$shortMovieDesc" -longdesc "$movieDesc" -type "Movie" -genre "$movieGenre" -cast "$movieActors" -director "$movieDirector" -swriters "$movieWriters" -producers "$movieProducers" -comment "{'imdb_id':'${imdb_id}', 'tmdb_id':'${tmdb_id}'}" -crating "$contentRating" "$theFile"
				osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: Cover art failed integrity test" & Return & "No artwork was added"'
			fi
		elif [[ overWrite -eq 0 ]]; then
			newFile="${outputDir}/${movieTitle} (${releaseYear})-${scriptPID}.${fileExt}"
			if [[ -e "$moviePoster" && "$imgIntegrityTest" -gt 100 ]]; then
			  "$mp4tagsPath" -song "$movieTitle" -artist "$albumArtists" -year "$releaseDate" -description "$shortMovieDesc" -longdesc "$movieDesc" -type "Movie" -picture "$moviePoster" -genre "$movieGenre" -cast "$movieActors" -director "$movieDirector" -swriters "$movieWriters" -producers "$movieProducers" -comment "{'imdb_id':'${imdb_id}', 'tmdb_id':'${tmdb_id}'}" -crating "$contentRating" "$theFile"
			else
			  "$mp4tagsPath" -song "$movieTitle" -artist "$albumArtists"   -year "$releaseDate" -description "$shortMovieDesc" -longdesc "$movieDesc" -type "Movie" -genre "$movieGenre" -cast "$movieActors" -director "$movieDirector" -swriters "$movieWriters" -producers "$movieProducers" -comment "{'imdb_id':'${imdb_id}', 'tmdb_id':'${tmdb_id}'}" -crating "$contentRating" "$theFile"
				osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: Cover art failed integrity test" & Return & "No artwork was added"'
			fi
		fi
	
		
		renameFilePath="${outputDir}/${movieTitleAndYear}.${fileExt}"
    if [[ renameFile -eq 1 && ! "$theFile" = "$renameFilePath" ]]; then
      if [ ! -e "$renameFilePath" ]; then
        if [[ overWrite -eq 0 && -e "$newFile" ]]; then
          mv "$newFile" "$renameFilePath"
          osascript -e "try" -e "set theFile to POSIX file \"$theFile\" as alias" -e "tell application \"Finder\" to move file theFile to trash" -e "end try" > /dev/null
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

function addChapterNamesMovie () {
	if sed '1q;d' "$movieData" | grep '>' > /dev/null ; then
		substituteISO88591 "$(cat "$movieData")" > "$movieData"
		movieTitle=`"$xpathPath" "$movieData" //name 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e 's|: | - |g' -e 's|\&amp;|\&|g' -e "s|&apos;|\'|g"`
		releaseDate=`"$xpathPath" "$movieData" //released 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		releaseYear=`echo "$releaseDate" | sed 's|-.*||g'`
		
		if [ ! -z "$theMovieNameAndYear" ]; then
			movieTitleAndYear="$theMovieNameAndYear"
		else
			movieTitleAndYear="${movieTitle} (${releaseYear})"
		fi
		
		tagChimpToken=1803782295499EE85E56181
		discNameNoYear=`echo "$movieTitleAndYear" | sed -e 's|\ (.*||g' -e 's|\ \-\ |:\ |g'`
		searchTerm=`echo "$discNameNoYear" | sed -e 's|\ |+|g' -e "s|\'|%27|g"`
		searchTermNoColin=`echo $searchTerm | sed 's|:||g'`
		movieYear=`echo "$movieTitleAndYear" | awk -F\( '{print $2}' | awk -F\) '{print $1}'`
		taggedFileExt=`basename "$theFile" | sed 's|.*\.||'`
		taggedFileName=`basename "$theFile" .$taggedFileExt`
		chapterFile="${outputDir}/${taggedFileName}.chapters.txt"
		if [ ! -e "$chapterFile" ]; then
			echo -e "  Searching TagChimp for chapter names... \c"
		#	Get chaps from m4v
			"$mp4chapsPath" -qxC "$theFile"

		#	Get count of chaps
			chapterCount=$(grep -cv "NAME" "$chapterFile")
		#	Search tagchimp
			tagChimpIdXml="${sourceTmpFolder}/${searchTermNoColin}-chimp.xml"
			tagChimpXml="${sourceTmpFolder}/${searchTermNoColin}-info-chimp.xml"
			curl -s "https://www.tagchimp.com/ape/search.php?token=$tagChimpToken&type=search&title=$searchTerm&videoKind=Movie&limit=5&totalChapters=$chapterCount" > "$tagChimpIdXml"
			searchTagChimp=`"$xpathPath" "$tagChimpIdXml" //tagChimpID 2>/dev/null | sed -e 's|\/tagChimpID>|\||g'| tr '|' '\n' | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
			# test chapters for each id
			for tagChimpID in $searchTagChimp
			do
				# download each id to tmp.xml
				tagChimpData="${sourceTmpFolder}/${tagChimpID}-chimp.xml"
				if [ ! -e "$tagChimpData" ]; then		
					curl -s "https://www.tagchimp.com/ape/search.php?token=$tagChimpToken&type=lookup&id=$tagChimpID" | iconv -f utf-8 -t ASCII//TRANSLIT > $tagChimpData
					substituteISO88591 "$(cat "$tagChimpData")" > "$tagChimpData"
				fi
				# 	Disc Name with wildcard for colins and ampersands
				discNameNoYearWildcard=`echo "$discNameNoYear" | sed -e 's|:|.*|g' -e 's|\&|.*|g'`
				# 	Test id for release year
				releaseDate=`"$xpathPath" "$tagChimpData" //releaseDate 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | grep "$movieYear"`
				# 	Test id for title
				movieTitle=`"$xpathPath" "$tagChimpData" //movieTitle 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e "s|&apos;|\'|g" -e 's| $||' | egrep -ix "$discNameNoYearWildcard"`
				#	Test id for chap count
				titleCount=`"$xpathPath" "$tagChimpData" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' | tr '|' '\n' | grep -c ""`
				#	Test chapter titles for uniqueness
				chapterTest=`"$xpathPath" "$tagChimpData" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' | tr '|' '\n' | sed '3q;d' | grep "3"`
				# 	verify data match, delete if not a match
				if [[ ! "$releaseDate" = "" && ! "$movieTitle" = "" && -z "$chapterTest" ]]; then
					if [ "$titleCount" = "$chapterCount" ]; then
						echo -e "Chapters found\n"
						mv "$tagChimpData" "$tagChimpXml"
						break 1
					else
						titleCountMin=$((titleCount - 1))
						titleCountMax=$((titleCount + 1))
						if [[ $titleCount -gt $titleCountMin && $titleCount -lt $titleCountMax ]]; then
							if [ ! -e "$tagChimpXml" ]; then
								notExactMatch="${sourceTmpFolder}/${searchTermNoColin}-notExact-chimp.xml"
								mv "$tagChimpData" "$notExactMatch"
							fi
						fi
					fi	
				fi	
			done
	
			# if could not find exact match, fallback to notExactMatch
			if [ ! -e "$tagChimpXml" ]; then
				if [ -e "$notExactMatch" ]; then
					echo -e "Chapters found (not exact match)\n"
					mv "$notExactMatch" "$tagChimpXml"
				else
					echo " " > "$tagChimpXml"
				fi
			fi

			#	Get chapter titles
			if grep "<movieTitle>" "$tagChimpXml" > /dev/null ; then
				titleFile="${sourceTmpFolder}/${searchTermNoColin}_titles.txt"
				# Save just titles to file
				"$xpathPath" "$tagChimpXml" //chapterTitle 2>/dev/null | sed -e 's|><|>\|<|g' -e 's|"||g' -e 's|<chapterTitle>||g' -e 's|</chapterTitle>||g' -e 's|&amp;amp;|\&|g' | tr '|' '\n' > "$titleFile"
				# Create a csv file for later use with hb
				if [[ saveCsv -eq 1 ]]; then
					cat "$titleFile" | grep -n "" | sed -e 's|,|\\,|g' -e 's|:|, |' > "${outputDir}/${taggedFileName}.chapters.csv"		
				fi
				chapterNameLine=$(grep "NAME" "$chapterFile" | tr ' ' '\007')
				chapterMarkers=$(grep -v "NAME" "$chapterFile")
				chaptersWithTitlesTmp="${sourceTmpFolder}/${discName}_tmp.chapters.txt"
				chapterNum=0
				for eachChapter in $chapterNameLine
				do
					chapterNum=$(($chapterNum + 1))
					eachChapter=$(echo "$eachChapter" | tr '\007' ' ')
					eachMarker=$(echo "$chapterMarkers" | sed "${chapterNum}q;d")
					eachTitle=$(sed "${chapterNum}q;d" "$titleFile")
					#	Replace chapterFile name with titleFile name
					echo "$eachMarker"  >> "$chaptersWithTitlesTmp"
					echo "$eachChapter" | sed -e "s|=.*|=$eachTitle|g"  >> "$chaptersWithTitlesTmp"
				done
				if [ -e "$chaptersWithTitlesTmp" ]; then
					cat "$chaptersWithTitlesTmp" > "$chapterFile"
				fi
			else
				osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: No match found from database." & Return & "The API may be down or there is a problem returning the data. Check tagchimp.com to verify chapter information."'	
			fi
		fi
		#	Add chaps to m4v
		if [[ -e "$theFile" && -e "$chapterFile" ]]; then
			"$mp4chapsPath" -i "$theFile"
			# Delete chapter file
			if [[ saveChaps -eq 0 ]]; then
				rm -f "$chapterFile"
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
	if [[ ! "${addChaps}" ]]; then addChaps=0; fi
	if [[ ! "${saveChaps}" ]]; then saveChaps=0; fi
	if [[ ! "${saveCsv}" ]]; then saveCsv=0; fi

	if [[ ! -x "$mp4infoPath" || ! -x "$mp4tagsPath" || ! -x "$mp4artPath" || ! -x "$mp4chapsPath" ]]; then
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: mp4v2 Library cannot be found" & Return & "Please install mp4v2 tools in /usr/local/bin" & Return & "Get mp4v2 at: http://code.google.com/p/mp4v2/"'
		exit 1
	fi

	fileExt=`basename "$theFile" | sed 's|.*\.||'`
	fileName=`basename "$theFile" .$fileExt | tr '_' ' ' | sed 's| ([0-9]*)||'`
	movieName=`basename "$theFile" ".${fileExt}"`
	outputDir=`dirname "$theFile"`
	if [[ "$fileExt" = "mp4" || "$fileExt" = "m4v" ]]; then
		
		# preserve Cnid
		cnidNum=$("$mp4infoPath" "$theFile" | grep cnID | sed 's|.* ||')
		if [[ -z "$cnidNum" ]]; then
			cnidNum=$(echo $(( 10000+($RANDOM)%(20000-10000+1) ))$(( 1000+($RANDOM)%(9999-1000+1) )))
		fi
	
		if [[ removeTags -eq 1 && addTags -eq 0 ]]; then
		"$mp4tagsPath" -r AacCdDgGHilmMnNoPsStTywR "$theFile"
		fi

		if [[ addTags -eq 1 || addChaps -eq 1 ]]; then			
			if [[ useFileNameForSearch -eq 1 ]]; then
				if echo "$theFile" | egrep '.* \([0-9]{4}\)' ; then
					getMovieTagsFromFileName
				else
					osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: File Naming Convention. Cannot parse the filename." & Return & "Rename your file: Movie Name (year)"'
				fi
			else
				searchForMovieTags
			fi
			
			if [[ addTags -eq 1 ]]; then
				# Set the HD Flag for HD-Video
				getResolution=$("$mp4infoPath" "$theFile" | egrep "1.*video" | awk -F,\  '{print $4}' | sed 's|\ @.*||')
				pixelWidth=$(echo "$getResolution" | sed 's|x.*||')
				pixelHeight=$(echo "$getResolution" | sed 's|.*x||')
				if [[ pixelWidth -gt 1279 || pixelHeight -gt 719 ]]; then
					"$mp4tagsPath" -hdvideo 1 "$theFile"
				fi

				# Set Cnid Number
        # if [[ ! -z "$cnidNum" ]]; then
        #   "$mp4tagsPath" -I "$cnidNum" "$theFile"
        # fi
			fi
			
			#chapterFile="${outputDir}/${movieName}.chapters.txt"
			#if [ -e "$chapterFile" ]; then
				#"$mp4chapsPath" -i "$theFile"
			#fi

		fi

		# Add Chapter Names
		#if [[ addChaps -eq 1 ]]; then
		#	addChapterNamesMovie
		#fi

		if [ -e "$sourceTmpFolder" ]; then
			rm -rfd $sourceTmpFolder
		fi
	else
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add Movie Tags" message "Error: File Type Extension. Cannot determine if file is mpeg-4 compatible." & Return & "File extension and type must be .mp4 or .m4v."'
	fi
	osascript -e "set theFile to POSIX file \"$theFile\"" -e 'tell application "Finder" to update theFile'

done