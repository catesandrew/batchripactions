#!/bin/sh

# batchRipDispatcher.sh
# Batch Rip Dispatcher
# Changes:
# 1-20091118 - made update current items list a function
# 2-20091118 - commands changed to run in background

# Created by Robert Yamada on 11/12/09.
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

function updateCurrentItemsList () {
	if [ -e /tmp/batchRip/currentItems.txt ]; then
		currentItemSearch=`cat /tmp/batchRip/currentItems.txt | awk -F: '{print $1}' | tr ' ' '\007' | tr '\000' ' '`

		for eachItem in $currentItemSearch
		do
			eachItem=`echo "$eachItem"  | tr '\007' ' '`
			if [ ! -d "$eachItem" ]; then
				#grep -v "$eachItem" /tmp/batchRip/currentItems.txt >> /tmp/batchRip/currentItems_tmp.txt
				sed -i "" "\#$eachItem#d" /tmp/batchRip/currentItems.txt
			fi
		done

		#if [ -e /tmp/batchRip/currentItems_tmp.txt ]; then
			#mv /tmp/batchRip/currentItems_tmp.txt /tmp/batchRip/currentItems.txt
		#fi
	fi
}

function batchRipDispatch () {
	# get disc list and send to automator
	discSearch=`df -T udf | grep "Volumes" | awk -F\ / {'print $2'} | sed 's|^|\/|g' | tr ' ' '\007' | tr '\000' ' '`

	for eachDisc in $discSearch
	do
		eachDisc=`echo "$eachDisc"  | tr '\007' ' '`
		# Check if this disc is currently being ignored or processing
		isCurrentListItem=`egrep "${eachDisc}:.*" < /tmp/batchRip/currentItems.txt`
		if [ -z "$isCurrentListItem" ]; then
			automator -i "$eachDisc" "$HOME/Library/Services/Batch Rip • Batch Rip (Service).workflow"
		fi
	done
}

# set delay for more than one drive
deviceCount=`ioreg -iSr -w 0 -c IODVDBlockStorageDevice | grep "Device Characteristics" | sed -e 's|.*"Product Name"="||' -e 's|".*||' | grep -c ""`
if [[ deviceCount -gt 1 ]]; then
	sleep 1
fi
# update current items list
updateCurrentItemsList

# send discs to Automator
batchRipDispatch
