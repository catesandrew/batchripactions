#!/usr/bin/env sh

# main.command
# Add TV Tags

#  Created by Robert Yamada on 10/2/09.
#  20091026-0 Added mp4tags, mp4info & mp4chaps. Added HD-Flag and Add Chaps from file
#  20091119-1 Changed rm command to -rf
#  20091119-2 Reorganized to bring it inline to changes made in add movie tags
#  20091119-3 Fixed overWrite to leave original untouched if set to 0
#  20091119-4 Moved add cover art to atomicParsley 
#  20091126-5 Added substituteISO88591 subroutine

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
#sortOrder="dvd" # set as default or dvd
xpathPath="/usr/bin/xpath"
xmllintPath="/usr/bin/xmllint"
atomicParsley64Path="/usr/local/bin/AtomicParsley64"
mp4infoPath="/usr/local/bin/mp4info"	# path to mp4info
mp4tagsPath="/usr/local/bin/mp4tags"	# path to mp4tags
mp4chapsPath="/usr/local/bin/mp4chaps"	# path to mp4chaps
mp4artPath="/usr/local/bin/mp4art"		# path to mp4art

#####################################################################################
# FUNCTIONS

addiTunesTagsTV()
{
	sourceTmpFolder="/tmp/$scriptPID"
	season_episode=$(basename "$theFile" | sed -e 's/\./ /g' -e 's/.*\([Ss][0-9][0-9][Ee][0-9][0-9]\).*/\1/')
	seasonNum=$(echo $season_episode | awk -F[Ee] '{print $1}'| awk -F[Ss] '{print $2}' | sed 's|^0||')
	episodeNum=$(echo $season_episode | awk -F[Ee] '{print $2}' | sed 's|^0||')
	episodeID=`echo $season_episode | sed -e 's|.*[Ee]||' -e "s|^|${seasonNum}|"`
	file_extension=$(basename "$theFile" | sed 's/\./ /g' | awk '{print $NF}')
	tv_show=$(basename "$theFile" | sed -e 's/\./ /g' -e 's/ [Ss]..[Ee].*//' -e 's|\ \-$||')
	searchTerm=$(echo "$tv_show" | sed -e 's|\ |+|g' -e 's|\ \-\ |:\ |g' -e "s|\'|%27|g")

	# create temp folder
	if [ ! -e "$sourceTmpFolder" ]; then
		mkdir "$sourceTmpFolder"
	fi

	# get series data
	seriesXml="$sourceTmpFolder/${searchTerm}-S${seasonNum}.xml"
	if [ ! -e "$sourceTmpFolder/${searchTerm}-S${seasonNum}.xml" ]; then
		# get mirror URL
		tvdbMirror=`curl -s "http://www.thetvdb.com/api/9F21AC232F30F34D/mirrors.xml" | "$xpathPath" //mirrorpath 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		# get series id
		series_id=$(curl -s "$tvdbMirror/api/GetSeries.php?seriesname=$searchTerm" | "$xpathPath" //seriesid 2>/dev/null | awk 'NR==1 {print $1}' | awk -F\> '{print $2}' | awk -F\< '{print $1}')
		curl -s "$tvdbMirror/api/9F21AC232F30F34D/series/$series_id/en.xml" > "$seriesXml"
		substituteISO88591 "$(cat "$seriesXml")" > "$seriesXml"
	fi

	# get banner info		
	bannerXml="$sourceTmpFolder/${searchTerm}-banners.xml"
	if [ ! -e "$sourceTmpFolder/${searchTerm}-banners.xml" ]; then
		curl -s "$tvdbMirror/api/9F21AC232F30F34D/series/$series_id/banners.xml" > "$bannerXml"
	fi


	# get episode info		
	episodeXml="$sourceTmpFolder/${searchTerm}-${season_episode}.xml"
	if [ ! -e "$sourceTmpFolder/${searchTerm}-${season_episode}.xml" ]; then
		if [ $sortOrder = "default" ] ; then
			curl -s "$tvdbMirror/api/9F21AC232F30F34D/series/$series_id/default/$seasonNum/$episodeNum/en.xml" > "$episodeXml"
		elif [ $sortOrder = "dvd" ] ; then
			curl -s "$tvdbMirror/api/9F21AC232F30F34D/series/$series_id/dvd/$seasonNum/$episodeNum/en.xml" > "$episodeXml"
		fi
		if grep '<title>404 Not Found</title>' < "$episodeXml" > /dev/null ; then
			curl -s "$tvdbMirror/api/9F21AC232F30F34D/series/$series_id/default/$seasonNum/$episodeNum/en.xml" > "$episodeXml"
		fi
	fi

	#generate tags and tag with AtomicParsley
	if sed '1q;d' "$episodeXml" | grep '>' > /dev/null ; then
		substituteISO88591 "$(cat "$episodeXml")" > "$episodeXml"
		episodeName=`"$xpathPath" "$episodeXml" //EpisodeName 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed 's|\&amp;|\&|g'`
		showName=`"$xpathPath" "$seriesXml" //SeriesName 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed 's|\&amp;|\&|g'`
		tvNetwork=`"$xpathPath" "$seriesXml" //Network 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		releaseDate=`"$xpathPath" "$episodeXml" //FirstAired 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		episodeDesc=`"$xpathPath" "$episodeXml" //Overview 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e 's|\&amp;|\&|g' -e 's|\&quot;||g'`
		genreList=`"$xpathPath" "$seriesXml" //Genre 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
		movieActors=`"$xpathPath" "$seriesXml" //Actors 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e 's_^\|__' -e 's_^_<dict><key>name</key><string>_' -e 's_\|$__' -e 's_$_</string></dict>_' -e 's_\|_</string></dict><dict><key>name</key><string>_g'`
		movieGuests=`"$xpathPath" "$episodeXml" //GuestStars 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e 's_^\|__' -e 's_^_<dict><key>name</key><string>_' -e 's_\|$__' -e 's_$_</string></dict>_' -e 's_\|_</string></dict><dict><key>name</key><string>_g'`
		movieDirector=`"$xpathPath" "$episodeXml" //Director 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e 's_^\|__' -e 's_^_<dict><key>name</key><string>_' -e 's_\|$__' -e 's_$_</string></dict>_' -e 's_\|_</string></dict><dict><key>name</key><string>_g'`
		movieWriters=`"$xpathPath" "$episodeXml" //Writer 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | sed -e 's_^\|__' -e 's_^_<dict><key>name</key><string>_' -e 's_\|$__' -e 's_$_</string></dict>_' -e 's_\|_</string></dict><dict><key>name</key><string>_g'`
		purchaseDate=`date "+%Y-%m-%d %H:%M:%S"`

		# parse category info and convert into iTunes genre
		if echo "$genreList" | grep 'Animation' > /dev/null ; then
			movieGenre="Kids & Family"
		elif echo "$genreList" | grep 'Science-Fiction' > /dev/null ; then
			movieGenre="Sci-Fi & Fantasy"
		elif echo "$genreList" | grep 'Fantasy' > /dev/null ; then
			movieGenre="Sci-Fi & Fantasy"
		elif echo "$genreList" | grep 'Horror' > /dev/null ; then
			movieGenre="Horror"
		elif echo "$genreList" | grep '\(Action\|Adventure\|Disaster\)' > /dev/null ; then
			movieGenre="Action & Adventure"
		elif echo "$genreList" | grep 'Musical' > /dev/null ; then
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
	tvPoster="$sourceTmpFolder/${searchTerm}-${seasonNum}.jpg"
	if [ ! -e $tvPoster ] ; then
		# get season banner
		getTvPoster=`"$xpathPath" "$bannerXml" / 2>/dev/null | tr -d '\n ' | sed 's|</Banner>|</Banner>\||g' | tr '|' '\n' | egrep "Season>${seasonNum}</Season" | awk -F\<BannerPath\> '{print $2}' | awk -F\</BannerPath\> '{print $1}' | sed "s|^|${tvdbMirror}/banners/|"`
		for eachURL in $getTvPoster
		do
			curl -s "$eachURL" > $tvPoster
			imgIntegrityTest=`sips -g pixelWidth "$tvPoster" | sed 's|.*[^0-9+]||'`
			if [ "$imgIntegrityTest" -gt 100 ]; then
				resizeImage "$tvPoster"
				break 1
			else
				rm $tvPoster
			fi
		done

		if [ ! -e "$tvPoster" ]; then
			# get series banner
			getTvPoster=`"$xpathPath" "$seriesXml" //poster 2>/dev/null | awk -F\> '{print $2}' | awk -F\< '{print $1}' | grep -m1 "" | sed "s|^|${tvdbMirror}/banners/|"`
			curl -s "$getTvPoster" > $tvPoster
			imgIntegrityTest=`sips -g pixelWidth "$tvPoster" | sed 's|.*[^0-9+]||'`
			if [ "$imgIntegrityTest" -gt 100 ]; then
				resizeImage "$tvPoster"
			fi
		fi
	fi

		# create movie tags reverseDNS xml file
		movieTagsXml="${sourceTmpFolder}/${searchTerm}-${season_episode}_tags_tmp.xml"
		if [ ! -e $movieTagsXml ] ; then
			xmlFile="<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>cast</key><array>${movieActors}${movieGuests}</array><key>directors</key><array>${movieDirector}</array><key>screenwriters</key><array>${movieWriters}</array></dict></plist>"
			echo "$xmlFile" | tr -cd '\11\12\40-\176' | "$xmllintPath" --format --output "${sourceTmpFolder}/${searchTerm}-${season_episode}_tags_tmp.xml" -	
		fi
		movieTagsData=`cat "$movieTagsXml"`

		# removeTags
		if [[ removeTags -eq 1 ]]; then
		#"$atomicParsley64Path" "$theFile" --overWrite --metaEnema
		"$mp4tagsPath" -r AacCdDgGHilmMnNoPsStTywR "$theFile"
		fi

		# write tags with atomic parsley
		if [[ overWrite -eq 1 ]]; then
			if [[ -e "$tvPoster" && "$imgIntegrityTest" -gt 100 ]]; then
				"$atomicParsley64Path" "$theFile" --artwork REMOVE_ALL --overWrite --title "$episodeName" --artist "$showName" --albumArtist "$showName" --album "${showName}, Season ${seasonNum}" --sortOrder "album" "${showName}, Season ${seasonNum}" --disk "1/1" --year "$releaseDate" --purchaseDate "$purchaseDate" --description "$episodeDesc" --longDesc "$episodeDesc" --TVNetwork "$tvNetwork" --TVShowName "$showName" --TVEpisode "$episodeID" --TVSeasonNum "$seasonNum" --tracknum "$episodeNum" --TVEpisodeNum "$episodeNum" --stik "TV Show" --artwork "$tvPoster" --genre "$movieGenre" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes
			else
				"$atomicParsley64Path" "$theFile" --artwork REMOVE_ALL --overWrite --title "$episodeName" --artist "$showName" --albumArtist "$showName" --album "${showName}, Season ${seasonNum}" --sortOrder "album" "${showName}, Season ${seasonNum}" --disk "1/1" --year "$releaseDate" --purchaseDate "$purchaseDate" --description "$episodeDesc" --longDesc "$episodeDesc" --TVNetwork "$tvNetwork" --TVShowName "$showName" --TVEpisode "$episodeID" --TVSeasonNum "$seasonNum" --tracknum "$episodeNum" --TVEpisodeNum "$episodeNum" --stik "TV Show" --genre "$movieGenre" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes
				osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add TV Tags" message "Error: Cover art failed integrity test" & Return & "No artwork was added"'
			fi
		elif [[ overWrite -eq 0 ]]; then
			newFile="${outputDir}/${fileName}-${scriptPID}.${fileExt}"
			if [[ -e "$tvPoster" && "$imgIntegrityTest" -gt 100 ]]; then
				"$atomicParsley64Path" "$theFile" --output "$newFile" --artwork REMOVE_ALL --title "$episodeName" --artist "$showName" --albumArtist "$showName" --album "${showName}, Season ${seasonNum}" --sortOrder "album" "${showName}, Season ${seasonNum}" --disk "1/1" --year "$releaseDate" --purchaseDate "$purchaseDate" --description "$episodeDesc" --longDesc "$episodeDesc" --TVNetwork "$tvNetwork" --TVShowName "$showName" --TVEpisode "$episodeID" --TVSeasonNum "$seasonNum" --tracknum "$episodeNum" --TVEpisodeNum "$episodeNum" --stik "TV Show" --artwork "$tvPoster" --genre "$movieGenre" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes
			else
				"$atomicParsley64Path" "$theFile" --output "$newFile" --title "$episodeName" --artist "$showName" --albumArtist "$showName" --album "${showName}, Season ${seasonNum}" --sortOrder "album" "${showName}, Season ${seasonNum}" --disk "1/1" --year "$releaseDate" --purchaseDate "$purchaseDate" --description "$episodeDesc" --longDesc "$episodeDesc" --TVNetwork "$tvNetwork" --TVShowName "$showName" --TVEpisode "$episodeID" --TVSeasonNum "$seasonNum" --tracknum "$episodeNum" --TVEpisodeNum "$episodeNum" --stik "TV Show" --genre "$movieGenre" --rDNSatom "$movieTagsData" name=iTunMOVI domain=com.apple.iTunes			
				osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add TV Tags" message "Error: Cover art failed integrity test" & Return & "No artwork was added"'
			fi
		fi

	else
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add TV Tags" message "Error: Could not find a match." & Return & "Check TV Show Name, Season Number and Episode Number."'
	fi
	
}

function resizeImage () {
	sips -Z 600W600H "$1" --out "$1"
}

function substituteISO88591 () {
	returnString=`echo "$1" | sed -e 's|&#162;| cents|g' -e 's|&#163;|#|g' -e 's|&#164;|$|g' -e 's|&#165;| yen|g' -e 's|&#169;|©|g' -e 's|&#171;|"|g' -e 's|&#172;|/|g' -e 's|&#173;|-|g' -e 's|&#174;|¨|g' -e 's|&#176;|¼|g' -e 's|&#177;|+/-|g' -e 's|&#178;| 2|g' -e 's|&#179;| 3|g' -e 's|&#180;|^|g' -e 's|&#181;||g' -e 's|&#182;|¦|g' -e 's|&#183;|,|g' -e 's|&#184;||g' -e 's|&#185;| 1|g' -e 's|&#186;||g' -e 's|&#187;|"|g' -e 's|&#188;|1/4|g' -e 's|&#189;|1/2|g' -e 's|&#190;|3/4|g' -e 's|&#191;|!|g' -e 's|&#192;|A|g' -e 's|&#193;|A|g' -e 's|&#194;|A|g' -e 's|&#195;|A|g' -e 's|&#196;|A|g' -e 's|&#197;|A|g' -e 's|&#198;|AE|g' -e 's|&#199;|C|g' -e 's|&#200;|E|g' -e 's|&#201;|E|g' -e 's|&#202;|E|g' -e 's|&#203;|E|g' -e 's|&#204;|I|g' -e 's|&#205;|I|g' -e 's|&#206;|I|g' -e 's|&#207;|I|g' -e 's|&#208;|TH|g' -e 's|&#209;|N|g' -e 's|&#210;|O|g' -e 's|&#211;|O|g' -e 's|&#212;|O|g' -e 's|&#213;|O|g' -e 's|&#214;|O|g' -e 's|&#215;|x|g' -e 's|&#216;|O|g' -e 's|&#217;|U|g' -e 's|&#218;|U|g' -e 's|&#219;|U|g' -e 's|&#220;|U|g' -e 's|&#221;|Y|g' -e 's|&#222;||g' -e 's|&#223;|s|g' -e 's|&#224;|a|g' -e 's|&#225;|a|g' -e 's|&#226;|a|g' -e 's|&#227;|a|g' -e 's|&#228;|a|g' -e 's|&#229;|a|g' -e 's|&#230;|ae|g' -e 's|&#231;|c|g' -e 's|&#232;|e|g' -e 's|&#233;|e|g' -e 's|&#234;|e|g' -e 's|&#235;|e|g' -e 's|&#236;|i|g' -e 's|&#237;|i|g' -e 's|&#238;|i|g' -e 's|&#239;|i|g' -e 's|&#240;|th|g' -e 's|&#241;|n|g' -e 's|&#242;|o|g' -e 's|&#243;|o|g' -e 's|&#244;|o|g' -e 's|&#245;|o|g' -e 's|&#246;|o|g' -e 's|&#247;||g' -e 's|&#248;|o|g' -e 's|&#249;|u|g' -e 's|&#250;|u|g' -e 's|&#251;|u|g' -e 's|&#252;|u|g' -e 's|&#253;|y|g' -e 's|&#254;||g' -e 's|&#255;|y|g' -e 's|&#34;|?|g' -e 's|&#38;|&|g' -e 's|&#60;|<|g' -e 's|&#62;|>|g' -e 's|&#338;|OE|g' -e 's|&#339;|oe|g' -e 's|&#352;|S|g' -e 's|&#353;|s|g' -e 's|&#376;|Y|g' -e 's|&#382;|z|g' -e 's|&#710;||g' -e 's|&#732;|~|g' -e 's|&#8194;| |g' -e 's|&#8195;| |g' -e 's|&#8201;| |g' -e 's|&#8204;||g' -e 's|&#8205;||g' -e 's|&#8206;||g' -e 's|&#8207;||g' -e 's|&#8211;|-|g' -e 's|&#8212;|-|g' -e "s|&#8216;|'|g" -e "s|&#8217;|'|g" -e "s|&#8218;|'|g" -e 's|&#8220;|"|g' -e 's|&#8221;|"|g' -e 's|&#8222;|"|g' -e 's|&#8224;||g' -e 's|&#8225;||g' -e 's|&#8240;||g' -e 's|&#8249;|<|g' -e 's|&#8250;|>|g' -e 's|&#8364;|e|g'`
	echo "$returnString"
}

##################################################################
# MAIN SCRIPT

PATH=/bin:/usr/bin:/sbin:/usr/sbin export PATH
while read theFile
do
	if [[ ! "${overWrite}" ]]; then overWrite=0; fi
	if [[ ! "${removeTags}" ]]; then removeTags=0; fi
	if [[ ! "${addTags}" ]]; then removeTags=0; fi
	if [[ ! "${sortOrder}" ]]; then sortOrder=0; fi
	if [[ sortOrder -eq 0 ]]; then sortOrder="default"; fi
	if [[ sortOrder -eq 1 ]]; then sortOrder="dvd"; fi
	
	if [[ ! -x "$mp4infoPath" || ! -x "$mp4tagsPath" || ! -x "$mp4artPath" || ! -x "$mp4chapsPath" ]]; then
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add TV Tags" message "Error: mp4v2 Library cannot be found" & Return & "Please install mp4v2 tools in /usr/local/bin" & Return & "Get mp4v2 at: http://code.google.com/p/mp4v2/"'
		exit 1
	fi
	
	fileExt=`basename "$theFile" | sed 's|.*\.||'`
	fileName=`basename "$theFile" .$fileExt`
	movieName=`basename "$theFile" ".${fileExt}"`
	outputDir=`dirname "$theFile"`

	if [[ "$fileExt" = "mp4" || "$fileExt" = "m4v" ]]; then
	
		if [[ removeTags -eq 1 && addTags -eq 0 ]]; then
		"$atomicParsley64Path" "$theFile" --overWrite --metaEnema
		#"$mp4tagsPath" -r AacCdDgGHilmMnNoPsStTywR "$theFile"
		fi

		if echo "$theFile" | egrep '.* - S[0-9]{2}E[0-9]{2}\....' ; then
			if [[ addTags -eq 1 ]]; then
				addiTunesTagsTV

				# Set the HD Flag for HD-Video
				getResolution=$("$mp4infoPath" "$theFile" | egrep "1.*video" | awk -F,\  '{print $4}' | sed 's|\ @.*||')
				pixelWidth=$(echo "$getResolution" | sed 's|x.*||')
				pixelHeight=$(echo "$getResolution" | sed 's|.*x||')
				if [[ pixelWidth -gt 1279 || pixelHeight -gt 719 ]]; then
					"$mp4tagsPath" -H 1 "$theFile"
				fi

				# Add Chapters if chapter file exists
				chapterFile="${outputDir}/${fileName}.chapters.txt"
				if [ -e "$chapterFile" ]; then
					"$mp4chapsPath" -i "$theFile"
				fi
				
				
				# delete script temp files
				if [ -e "$sourceTmpFolder" ]; then
					rm -rf $sourceTmpFolder
				fi
			fi

		else
			osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add TV Tags" message "Error: File Naming Convention." & Return & "Cannot parse the filename." & Return & "Rename your file: TV Show Name - S##E##.m4v "'
		fi
	else
		osascript -e 'tell application "Automator Runner" to activate & display alert "Error: Add TV Tags" message "Error: File Type Extension. Cannot determine if file is mpeg-4 compatible." & Return & "File extension and type must be .mp4 or .m4v."'
	fi
	
	osascript -e "set theFile to POSIX file \"$theFile\"" -e 'tell application "Finder" to update theFile'
done
